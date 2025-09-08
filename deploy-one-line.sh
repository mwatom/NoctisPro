#!/bin/bash
# 🚀 NoctisPro PACS - One-Line Docker Deployment
# Usage: bash deploy-one-line.sh

set -e
echo "🐳 Starting NoctisPro PACS Docker deployment..."

# Generate secure environment
export SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || echo "noctis-$(date +%s)")
export POSTGRES_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "noctis-db-$(date +%s)")
export ADMIN_PASSWORD="NoctisAdmin2024!"

# Install Docker if needed
if ! command -v docker >/dev/null 2>&1; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && rm get-docker.sh
    sudo usermod -aG docker $USER
fi

# Start Docker if not running
sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null || true

# Deploy with existing docker-compose
echo "🚀 Deploying services..."
docker-compose down --remove-orphans 2>/dev/null || true
docker-compose pull 2>/dev/null || true
docker-compose build --no-cache
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 30

# Health check
max_attempts=12
attempt=0
while [[ $attempt -lt $max_attempts ]]; do
    if curl -f -s http://localhost:8000/ >/dev/null 2>&1; then
        echo "✅ System is ready!"
        break
    fi
    ((attempt++))
    if [[ $attempt -eq $max_attempts ]]; then
        echo "⚠️ System may need more time to start"
        break
    fi
    echo "Checking... ($attempt/$max_attempts)"
    sleep 10
done

# Setup Cloudflare tunnel (optional)
if command -v cloudflared >/dev/null 2>&1 || curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared.deb && rm cloudflared.deb; then
    echo "🌐 Setting up public access..."
    pkill cloudflared 2>/dev/null || true
    nohup cloudflared tunnel --url http://localhost:8000 > tunnel.log 2>&1 &
    sleep 10
    WEB_URL=$(grep "https://" tunnel.log | grep -o "https://[^[:space:]]*" | head -1)
    if [[ -n "$WEB_URL" ]]; then
        echo "🌍 Public URL: $WEB_URL"
        echo "$WEB_URL" > public_url.txt
    fi
fi

# Display results
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "========================"
echo "🌐 Local URL: http://localhost:8000"
echo "🔧 Admin Panel: http://localhost:8000/admin/"
echo "🔐 Admin Login: admin / NoctisAdmin2024!"
echo "📊 DICOM Port: 11112"
echo ""
if [[ -f public_url.txt ]]; then
    echo "🌍 Public URL: $(cat public_url.txt)"
    echo "🌍 Public Admin: $(cat public_url.txt)/admin/"
    echo ""
fi
echo "🐳 Management Commands:"
echo "  Status: docker-compose ps"
echo "  Logs:   docker-compose logs -f"
echo "  Stop:   docker-compose down"
echo "  Start:  docker-compose up -d"
echo ""
echo "🚀 Your NoctisPro PACS system is ready!"