#!/bin/bash

# =============================================================================
# NoctisPro PACS - One Command Deployment
# =============================================================================
# Single command to deploy everything with Docker + PostgreSQL + Public URLs
# =============================================================================

echo "🚀 Starting NoctisPro PACS One-Command Deployment..."
echo "===================================================="

# Generate secure credentials
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || echo "noctis-secret-$(date +%s)")
POSTGRES_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "noctis-postgres-$(date +%s)")

# Create environment file
cat > .env << EOF
SECRET_KEY=${SECRET_KEY}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ADMIN_PASSWORD=NoctisAdmin2024!
EOF

# Use existing docker-compose.yml (don't overwrite)
echo "📋 Using existing docker-compose.yml configuration..."

# Install Docker if needed
if ! command -v docker >/dev/null 2>&1; then
    echo "📦 Installing Docker..."
    sudo apt update && sudo apt install -y docker.io docker-compose
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

# Deploy with Docker
echo "🚀 Deploying with Docker..."
docker-compose down --remove-orphans 2>/dev/null || true
docker-compose build
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 30

# Install and setup Cloudflare tunnel
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "🌐 Installing Cloudflare Tunnel..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

# Start tunnels
echo "🌐 Creating public URLs..."
pkill cloudflared 2>/dev/null || true
nohup cloudflared tunnel --url http://localhost:8000 > web_tunnel.log 2>&1 &
nohup cloudflared tunnel --url http://localhost:11112 > dicom_tunnel.log 2>&1 &

# Wait for tunnels
sleep 15

# Extract URLs
WEB_URL=$(grep "https://" web_tunnel.log 2>/dev/null | grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" | head -1)
DICOM_URL=$(grep "https://" dicom_tunnel.log 2>/dev/null | grep -o "https://[a-zA-Z0-9.-]*\.trycloudflare\.com" | head -1)

# Display results
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================"
echo ""
echo "🌐 PUBLIC URLS:"
echo "   Web App: ${WEB_URL:-http://localhost:8000}"
echo "   Admin:   ${WEB_URL:-http://localhost:8000}/admin/"
echo "   DICOM:   ${DICOM_URL:-http://localhost:11112}"
echo ""
echo "🔐 ADMIN LOGIN:"
echo "   Username: admin"
echo "   Password: NoctisAdmin2024!"
echo ""
echo "🐳 DOCKER STATUS:"
docker-compose ps
echo ""
echo "✅ Your NoctisPro PACS system is ready!"
echo "   Access it now: ${WEB_URL:-http://localhost:8000}"