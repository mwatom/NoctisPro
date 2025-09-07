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

# Create Docker Compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  web:
    build: .
    environment:
      - DEBUG=False
      - SECRET_KEY=${SECRET_KEY}
      - DB_ENGINE=django.db.backends.postgresql
      - DB_NAME=noctis_pro
      - DB_USER=noctis_user
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - DB_HOST=db
      - DB_PORT=5432
      - REDIS_URL=redis://redis:6379/0
      - ALLOWED_HOSTS=*
    ports:
      - "8000:8000"
      - "11112:11112"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             python manage.py shell -c \"
from django.contrib.auth import get_user_model;
User = get_user_model();
User.objects.filter(username='admin').delete();
User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!');
print('✅ Admin created: admin/NoctisAdmin2024!')
\" &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 4 &
             python dicom_receiver.py --port 11112 --aet NOCTIS_SCP --bind 0.0.0.0"
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF

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
WEB_URL=$(grep -o "https://[^[:space:]]*" web_tunnel.log 2>/dev/null | head -1)
DICOM_URL=$(grep -o "https://[^[:space:]]*" dicom_tunnel.log 2>/dev/null | head -1)

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