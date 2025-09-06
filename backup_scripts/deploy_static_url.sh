#!/bin/bash

echo "🌐 STATIC URL DEPLOYMENT"
echo "======================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}⚠️  Creating Python virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    PYTHON_CMD="python"
    PIP_CMD="pip"
else
    echo -e "${YELLOW}⚠️  Using system Python (venv creation failed)${NC}"
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
fi

# Install/upgrade dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
$PIP_CMD install -q --upgrade pip --break-system-packages 2>/dev/null || echo "Pip upgrade skipped"
$PIP_CMD install -q -r requirements.txt --break-system-packages 2>/dev/null || echo "Some packages may need manual installation"

# Run Django migrations
echo -e "${BLUE}🔄 Running database migrations...${NC}"
$PYTHON_CMD manage.py migrate --noinput

# Collect static files
echo -e "${BLUE}📁 Collecting static files...${NC}"
$PYTHON_CMD manage.py collectstatic --noinput

# Create superuser if it doesn't exist
echo -e "${BLUE}👤 Ensuring admin user exists...${NC}"
$PYTHON_CMD manage.py shell << EOF
from django.contrib.auth.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created: admin/admin123')
else:
    print('✅ Admin user already exists')
EOF

# Kill any existing Django processes
echo -e "${BLUE}🔄 Stopping existing Django processes...${NC}"
pkill -f "python manage.py runserver" 2>/dev/null || echo "No existing Django processes found"

# Start Django server
echo -e "${BLUE}🚀 Starting Django server...${NC}"
nohup $PYTHON_CMD manage.py runserver 0.0.0.0:8000 > django_server.log 2>&1 &
DJANGO_PID=$!

# Wait for server to start
sleep 3

# Check if server is running
if ps -p $DJANGO_PID > /dev/null; then
    echo -e "${GREEN}✅ Django server started successfully (PID: $DJANGO_PID)${NC}"
    echo $DJANGO_PID > .django_pid
else
    echo -e "${RED}❌ Failed to start Django server${NC}"
    echo "Check django_server.log for errors"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo ""

# Show access information
if [ -f "/workspace/.duckdns_config" ]; then
    source /workspace/.duckdns_config
    echo -e "${BLUE}🌐 Your application is accessible at:${NC}"
    echo -e "${GREEN}   https://${DUCKDNS_DOMAIN}.duckdns.org${NC}"
    echo ""
fi

if [ -f "/workspace/.tunnel_config" ]; then
    source /workspace/.tunnel_config
    echo -e "${BLUE}🚇 Cloudflare Tunnel available at:${NC}"
    echo -e "${GREEN}   https://noctispro.your-domain.com${NC}"
    echo ""
fi

echo -e "${BLUE}🏥 Local access:${NC}"
echo -e "${GREEN}   http://localhost:8000${NC}"
echo -e "${GREEN}   http://$(hostname -I | awk '{print $1}'):8000${NC}"
echo ""
echo -e "${BLUE}👤 Admin credentials:${NC}"
echo -e "${GREEN}   Username: admin${NC}"
echo -e "${GREEN}   Password: admin123${NC}"
echo ""
echo -e "${BLUE}📊 DICOM Viewer:${NC}"
echo -e "${GREEN}   /dicom-viewer/${NC}"
echo ""
echo -e "${YELLOW}📋 Useful commands:${NC}"
echo "   View logs: tail -f django_server.log"
echo "   Stop server: kill \$(cat .django_pid)"
echo "   Restart: bash deploy_static_url.sh"
echo ""
echo -e "${YELLOW}🔧 Setup commands (if not done):${NC}"
echo "   Duck DNS: bash setup_duckdns.sh"
echo "   Cloudflare: bash setup_cloudflare.sh"
echo "   CF Tunnel: bash setup_cloudflare_tunnel.sh"