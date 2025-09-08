#!/bin/bash

# =============================================================================
# NoctisPro PACS - CloudFlare Integrated Startup Script
# =============================================================================
# This script starts NoctisPro PACS with CloudFlare tunnel for consistent URLs
# =============================================================================

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
cd "$PROJECT_DIR"

echo ""
echo -e "${BOLD}${BLUE}🚀 NoctisPro PACS with CloudFlare Tunnel${NC}"
echo -e "${BOLD}${BLUE}========================================${NC}"
echo ""

# Check if CloudFlare is configured
if [ ! -f "config/cloudflare/config.yml" ]; then
    echo -e "${YELLOW}⚠️  CloudFlare tunnel not configured yet.${NC}"
    echo ""
    echo "To set up CloudFlare tunnel for consistent public URLs:"
    echo "1. Run: ./cloudflare-tunnel-setup.sh"
    echo "2. Then run this script again"
    echo ""
    echo "Or proceed with local deployment only..."
    read -p "Continue with local deployment only? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please configure CloudFlare tunnel first."
        exit 1
    fi
fi

# Load environment configuration
if [ -f ".env.cloudflare" ]; then
    echo "✅ Loading CloudFlare configuration..."
    set -a
    . .env.cloudflare
    set +a
elif [ -f ".env" ]; then
    echo "✅ Loading standard configuration..."
    set -a
    . .env
    set +a
else
    echo "⚠️  No environment configuration found, using defaults..."
fi

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not found. Please install Docker first."
    echo "Run: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

# Start Docker daemon if not running
if ! docker info >/dev/null 2>&1; then
    echo "🔄 Starting Docker daemon..."
    sudo dockerd > /dev/null 2>&1 &
    sleep 5
fi

# Determine compose file
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.cloudflare.yml" ]; then
    COMPOSE_FILE="docker-compose.cloudflare.yml"
    echo "✅ Using CloudFlare-integrated Docker configuration"
else
    echo "ℹ️  Using standard Docker configuration"
fi

# Start services
echo ""
echo "🚀 Starting NoctisPro PACS services..."
echo "====================================="

# Start core services first
echo "Starting database and Redis..."
docker-compose -f "$COMPOSE_FILE" up -d db redis

# Wait for database
echo "Waiting for database to be ready..."
sleep 10

# Start application services
echo "Starting web and DICOM services..."
docker-compose -f "$COMPOSE_FILE" up -d web dicom_receiver celery

# Start CloudFlare tunnel if configured
if [ -f "config/cloudflare/config.yml" ] && docker-compose -f "$COMPOSE_FILE" config | grep -q "cloudflare_tunnel" 2>/dev/null; then
    echo "Starting CloudFlare tunnel..."
    docker-compose -f "$COMPOSE_FILE" up -d cloudflare_tunnel
fi

# Wait for services to initialize
echo "Waiting for services to initialize..."
sleep 15

# Health checks
echo ""
echo "🔍 Performing health checks..."
echo "=============================="

# Check web service
if curl -f -s --max-time 10 "http://localhost:8000/" >/dev/null 2>&1; then
    echo "✅ Web service is responding"
    WEB_STATUS="✅ Healthy"
else
    echo "❌ Web service is not responding"
    WEB_STATUS="❌ Not responding"
fi

# Check DICOM port
if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
    echo "✅ DICOM port is accessible"
    DICOM_STATUS="✅ Accessible"
else
    echo "❌ DICOM port is not accessible"
    DICOM_STATUS="❌ Not accessible"
fi

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

# Display summary
echo ""
echo -e "${BOLD}${GREEN}🎉 NoctisPro PACS Deployment Summary${NC}"
echo "======================================"
echo "Web Service:      $WEB_STATUS"
echo "DICOM Service:    $DICOM_STATUS"
echo ""
echo "🌐 Access Information:"
echo "   Local Web:      http://localhost:8000"
echo "   Network Web:    http://${LOCAL_IP}:8000"
echo "   Admin Panel:    http://localhost:8000/admin/"
echo "   DICOM Port:     ${LOCAL_IP}:11112"
echo "   Default Login:  admin / NoctisAdmin2024!"

# Show CloudFlare URLs if configured
if [ -f "config/cloudflare/domain.txt" ]; then
    DOMAIN=$(cat config/cloudflare/domain.txt)
    echo ""
    echo "🌍 CloudFlare Public URLs:"
    echo "   Web Interface:  https://noctis.${DOMAIN}"
    echo "   Admin Panel:    https://admin.${DOMAIN}"
    echo "   DICOM Endpoint: dicom.${DOMAIN}:11112"
fi

echo ""
echo "📡 DICOM Configuration:"
echo "   AE Title:       NOCTIS_SCP"
echo "   Port:           11112"
echo "   Local IP:       ${LOCAL_IP}"

echo ""
echo "🔧 Management Commands:"
echo "   View Status:    docker-compose -f $COMPOSE_FILE ps"
echo "   View Logs:      docker-compose -f $COMPOSE_FILE logs -f"
echo "   Stop Services:  docker-compose -f $COMPOSE_FILE down"
echo "   Restart:        docker-compose -f $COMPOSE_FILE restart"

echo ""
echo "📋 Next Steps:"
echo "1. Access the web interface at http://localhost:8000"
echo "2. Log in with admin / NoctisAdmin2024!"
echo "3. Configure your imaging devices to send to:"
echo "   - AE Title: NOCTIS_SCP"
echo "   - IP: ${LOCAL_IP}"
echo "   - Port: 11112"

if [ ! -f "config/cloudflare/config.yml" ]; then
    echo ""
    echo "💡 To set up consistent public URLs:"
    echo "   Run: ./cloudflare-tunnel-setup.sh"
fi

echo ""
echo -e "${GREEN}✅ NoctisPro PACS is ready to receive DICOM images!${NC}"