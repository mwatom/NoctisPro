#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# NoctisPro PACS - One Command Deployment
# =============================================================================
# Single command to deploy everything with Docker + PostgreSQL + Public URLs
# =============================================================================

echo "🚀 Starting NoctisPro PACS One-Command Deployment..."
echo "===================================================="

# Safe extractor for trycloudflare URL from a log file (does not fail the script)
extract_trycloudflare_url() {
  local file_path="$1"
  awk 'match($0, /https:\/\/[A-Za-z0-9.-]*\.trycloudflare\.com/) {print substr($0, RSTART, RLENGTH); exit}' "$file_path" 2>/dev/null || true
}

# Environment handling: reuse existing .env if present to avoid breaking persisted DB
if [ -f .env ]; then
  echo "🔒 Using existing .env (not overwritten)..."
  set -a
  . ./.env
  set +a
  # Ensure required vars are set in the current shell; do not rewrite the file
  : "${SECRET_KEY:=$(python3 -c \"import secrets; print(secrets.token_urlsafe(50))\" 2>/dev/null || echo \"noctis-secret-$(date +%s)\")}"
  : "${POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:-}}"
  : "${ADMIN_PASSWORD:=NoctisAdmin2024!}"
else
  # Generate secure credentials and write a fresh .env
  SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || echo "noctis-secret-$(date +%s)")
  POSTGRES_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "noctis-postgres-$(date +%s)")
  ADMIN_PASSWORD=NoctisAdmin2024!
  cat > .env << EOF
SECRET_KEY=${SECRET_KEY}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
# Optional: FRP (frpc) tunneling. Set FRP_ENABLED=True and configure below to use FRP instead of Cloudflare.
FRP_ENABLED=False
# Address of your FRP server (frps) - public IP or domain of your VPS
FRP_SERVER_ADDR=
# Port of frps (default 7000)
FRP_SERVER_PORT=7000
# Shared token that matches frps auth.token
FRP_TOKEN=
# If using HTTP via FRP with a domain handled by frps (nginx or subdomain_host), set this to your domain (e.g., app.example.com)
FRP_WEB_CUSTOM_DOMAIN=
# If not using a domain, set a TCP remote port to expose the web app over http://<FRP_SERVER_ADDR>:<FRP_WEB_REMOTE_PORT>
FRP_WEB_REMOTE_PORT=18000
# Remote TCP port for DICOM (11112 local)
FRP_DICOM_REMOTE_PORT=61112
EOF
fi

# Use existing docker-compose.yml (don't overwrite)
echo "📋 Using existing docker-compose.yml configuration..."

# Install Docker if needed
if ! command -v docker >/dev/null 2>&1; then
    echo "📦 Installing Docker..."
    sudo apt update && sudo apt install -y docker.io docker-compose docker-compose-plugin
    sudo usermod -aG docker $USER
fi

# Start Docker if needed
if ! docker info >/dev/null 2>&1; then
    echo "🐳 Starting Docker..."
    sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null || {
        echo "⚠️ Docker daemon issue, using native deployment..."
        ./docker-deploy.sh
        exit 0
    }
fi

# Choose docker compose command (array-safe despite IFS)
DC=()
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "⚙️ Docker Compose not found. Attempting to install..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin docker-compose || true
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y docker-compose-plugin docker-compose || true
  fi
  if docker compose version >/dev/null 2>&1; then
    DC=(docker compose)
  elif docker-compose version >/dev/null 2>&1; then
    DC=(docker-compose)
  else
    echo "❌ Neither 'docker compose' nor 'docker-compose' is available after install."
    echo "   Please install Docker Compose v2 plugin or legacy binary."
    exit 1
  fi
fi

# Remove conflicting custom network if present (avoids Compose label mismatch)
if docker network ls --format '{{.Name}}' | grep -q '^noctis_network$'; then
  echo "🧹 Removing existing network noctis_network to avoid label conflicts..."
  docker network rm noctis_network || true
fi

# Deploy with Docker
echo "🚀 Deploying with Docker..."
"${DC[@]}" down --remove-orphans 2>/dev/null || true
"${DC[@]}" build
"${DC[@]}" up -d

# Ensure static/media permissions and restart web once to apply
echo "🔧 Ensuring static/media permissions..."
docker exec --user root noctis_web sh -lc "mkdir -p /app/staticfiles /app/media && (chown -R app:app /app/staticfiles /app/media || chown -R 1000:1000 /app/staticfiles /app/media) && chmod -R u+rwX,g+rwX /app/staticfiles /app/media" 2>/dev/null || true
docker restart noctis_web 1>/dev/null 2>&1 || true

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 5

# Check container health/status
echo "🔎 Checking container status..."
"${DC[@]}" ps | sed -n '1,2p;3,$p' | cat

# Fail if required services are not running
for svc in noctis_db noctis_redis noctis_web; do
  if ! docker ps --format '{{.Names}}\t{{.Status}}' | grep -q "^${svc}\\b"; then
    echo "❌ Service ${svc} is not running. Aborting."
    "${DC[@]}" logs --no-color ${svc} | tail -n 200 | cat || true
    exit 1
  fi
done

# Extra: surface unhealthy state
if docker ps --format '{{.Names}}\t{{.Status}}' | grep -E '\\(unhealthy\\)' >/dev/null; then
  echo "❌ One or more services are unhealthy. Showing logs and exiting."
  "${DC[@]}" ps | cat
  "${DC[@]}" logs --no-color | tail -n 300 | cat
  exit 1
fi

# Prefer FRP if enabled; otherwise fallback to Cloudflare tunnels

# Normalize boolean check for FRP
_frp_enabled="${FRP_ENABLED:-${FRP_enabled:-${frp_enabled:-False}}}"
_frp_enabled_lower=$(printf "%s" "$_frp_enabled" | tr '[:upper:]' '[:lower:]')

if [ "$_frp_enabled_lower" = "true" ]; then
  echo "🌐 FRP enabled via .env — setting up frpc..."

  # Validate minimal FRP variables
  : "${FRP_SERVER_ADDR:?❌ FRP_SERVER_ADDR not set in .env when FRP_ENABLED=True}"
  : "${FRP_SERVER_PORT:=7000}"
  : "${FRP_TOKEN:?❌ FRP_TOKEN not set in .env when FRP_ENABLED=True}"
  : "${FRP_WEB_REMOTE_PORT:=18000}"
  : "${FRP_DICOM_REMOTE_PORT:=61112}"

  # Install frpc if missing
  if ! command -v frpc >/dev/null 2>&1; then
    echo "📦 Installing frpc..."
    tmpdir=$(mktemp -d)
    ( set -e; cd "$tmpdir"; \
      curl -sL https://api.github.com/repos/fatedier/frp/releases/latest \
        | grep browser_download_url \
        | grep linux_amd64.tar.gz \
        | cut -d '"' -f 4 \
        | xargs curl -LO; \
      tar xzf frp_*.tar.gz; \
      dir=$(find . -maxdepth 1 -type d -name 'frp_*' | head -n1); \
      sudo mv "$dir/frpc" /usr/local/bin/frpc || cp "$dir/frpc" "$PWD/../frpc"; \
      command -v frpc >/dev/null 2>&1 || export PATH="$PWD/..:$PATH" \
    );
    rm -rf "$tmpdir"
  fi

  # Generate frpc.ini next to the script
  FRPC_INI="$(pwd)/frpc.ini"
  echo "📝 Generating frpc.ini at $FRPC_INI"
  cat > "$FRPC_INI" <<EOF
[common]
server_addr = ${FRP_SERVER_ADDR}
server_port = ${FRP_SERVER_PORT}
auth.method = token
auth.token = ${FRP_TOKEN}

[web]
type = http
local_ip = 127.0.0.1
local_port = 8000
EOF

  if [ -n "${FRP_WEB_CUSTOM_DOMAIN:-}" ]; then
    printf "custom_domains = %s\n" "${FRP_WEB_CUSTOM_DOMAIN}" >> "$FRPC_INI"
  else
    cat >> "$FRPC_INI" <<EOF
[web-tcp]
type = tcp
local_ip = 127.0.0.1
local_port = 8000
remote_port = ${FRP_WEB_REMOTE_PORT}
EOF
  fi

  cat >> "$FRPC_INI" <<EOF
[dicom]
type = tcp
local_ip = 127.0.0.1
local_port = 11112
remote_port = ${FRP_DICOM_REMOTE_PORT}
EOF

  # Restart frpc
  pkill -f "^frpc" 2>/dev/null || true
  nohup frpc -c "$FRPC_INI" > frp_client.log 2>&1 &

  # Prepare output URLs
  if [ -n "${FRP_WEB_CUSTOM_DOMAIN:-}" ]; then
    WEB_URL="http://${FRP_WEB_CUSTOM_DOMAIN}"
    DETECTED_HOST="${FRP_WEB_CUSTOM_DOMAIN}"
  else
    WEB_URL="http://${FRP_SERVER_ADDR}:${FRP_WEB_REMOTE_PORT}"
    DETECTED_HOST="${FRP_SERVER_ADDR}"
  fi
  DICOM_URL="${FRP_SERVER_ADDR}:${FRP_DICOM_REMOTE_PORT}"
  echo "✅ FRP tunnels started (frpc)."
else
  # Install and setup Cloudflare tunnel
  if ! command -v cloudflared >/dev/null 2>&1; then
      echo "🌐 Installing Cloudflare Tunnel..."
      curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
      sudo dpkg -i cloudflared.deb
      rm cloudflared.deb
  fi

  # Start tunnels
  echo "🌐 Creating public URLs (Cloudflare)..."
  pkill cloudflared 2>/dev/null || true
  nohup cloudflared tunnel --url http://127.0.0.1:8000 --http-host-header 127.0.0.1 > web_tunnel.log 2>&1 &
  nohup cloudflared tunnel --url http://127.0.0.1:11112 --http-host-header 127.0.0.1 > dicom_tunnel.log 2>&1 &

  # Wait for tunnels and try to extract URLs with retries (robust to transient errors)
  WEB_URL=""
  DICOM_URL=""
  for attempt in 1 2 3 4 5 6; do
    sleep 5
    WEB_URL="${WEB_URL:-$(extract_trycloudflare_url web_tunnel.log)}"
    DICOM_URL="${DICOM_URL:-$(extract_trycloudflare_url dicom_tunnel.log)}"
    if [ -n "$WEB_URL" ] && [ -n "$DICOM_URL" ]; then
      break
    fi
  done
  # Derive detected host from Cloudflare URL
  if [ -n "$WEB_URL" ]; then
    DETECTED_HOST=$(printf "%s" "$WEB_URL" | sed -E 's#https?://([^/]+).*#\1#')
  fi
fi

# Display results
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================"
echo ""
echo "🌐 PUBLIC URLS:"
echo "   Web App: ${WEB_URL:-http://localhost:8000}"
echo "   Admin:   ${WEB_URL:-http://localhost:8000}/admin/"
if [ "$_frp_enabled_lower" = "true" ]; then
  echo "   DICOM:   ${DICOM_URL}"
else
  echo "   DICOM:   ${DICOM_URL:-http://localhost:11112}"
fi
if [ -n "${DOMAIN_NAME:-}" ]; then
  echo "   Host:   ${DOMAIN_NAME}"
elif [ -n "${DETECTED_HOST:-}" ]; then
  echo "   Host:   ${DETECTED_HOST}"
fi
echo ""
echo "🔐 ADMIN LOGIN:"
echo "   Username: admin"
echo "   Password: NoctisAdmin2024!"
echo ""
echo "🐳 DOCKER STATUS:"
"${DC[@]}" ps
echo ""
echo "✅ Your NoctisPro PACS system is ready!"
echo "   Access it now: ${WEB_URL:-http://localhost:8000}"