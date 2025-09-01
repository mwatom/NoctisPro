#!/bin/bash

# Noctis Pro PACS - One-Command Production Start with Public Access
# This is a simplified version that gets you up and running quickly

set -e

echo "🚀 Starting Noctis Pro PACS in Production Mode with Public Access"
echo "================================================================"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "manage.py" ]]; then
    echo "❌ This script must be run from the Django project root directory"
    exit 1
fi

# Check if ngrok exists
if [[ ! -f "ngrok" ]]; then
    echo "❌ ngrok binary not found!"
    echo "Please download ngrok first or run the full deployment script"
    exit 1
fi

print_info "Stopping any existing processes..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
sleep 3

print_info "Setting up virtual environment..."
if [[ ! -d "venv" ]]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn whitenoise

print_info "Configuring production environment..."
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production_ngrok
export DEBUG=False

print_info "Setting up database..."
python manage.py makemigrations --noinput 2>/dev/null || true
python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear

print_info "Creating admin user..."
python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisPro2024!')
    print('✅ Admin user created: admin / NoctisPro2024!')
else:
    admin = User.objects.get(username='admin')
    admin.set_password('NoctisPro2024!')
    admin.save()
    print('✅ Admin password updated: admin / NoctisPro2024!')
EOF

print_info "Starting Django application..."
# Start Django with Gunicorn in background
nohup gunicorn --workers 2 --bind 0.0.0.0:8000 --timeout 120 --access-logfile - noctis_pro.wsgi:application > django.log 2>&1 &
DJANGO_PID=$!

# Wait for Django to start
sleep 8

# Test if Django is running
if curl -s http://localhost:8000/health/simple/ >/dev/null 2>&1; then
    print_status "Django application started (PID: $DJANGO_PID)"
else
    print_warning "Django may still be starting up..."
fi

print_info "Starting ngrok tunnel..."
# Start ngrok in background
nohup ./ngrok http 8000 --log stdout > ngrok.log 2>&1 &
NGROK_PID=$!

print_info "Waiting for ngrok tunnel to establish..."
sleep 10

# Get the public URL
NGROK_URL=""
for i in {1..15}; do
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for tunnel in data.get('tunnels', []):
        if tunnel.get('proto') == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null || echo "")
    
    if [[ -n "$NGROK_URL" ]]; then
        break
    fi
    print_info "Waiting for ngrok tunnel... (attempt $i/15)"
    sleep 2
done

echo ""
echo "🎉 Noctis Pro PACS is now running in PRODUCTION MODE!"
echo "====================================================="
echo ""

if [[ -n "$NGROK_URL" ]]; then
    echo -e "${PURPLE}🌐 PUBLIC ACCESS (Share these URLs):${NC}"
    echo -e "   • Main Application: ${CYAN}$NGROK_URL${NC}"
    echo -e "   • Admin Panel:      ${CYAN}$NGROK_URL/admin${NC}"
    echo -e "   • DICOM Viewer:     ${CYAN}$NGROK_URL/dicom-viewer/${NC}"
    echo -e "   • Worklist:         ${CYAN}$NGROK_URL/worklist/${NC}"
    echo -e "   • Health Check:     ${CYAN}$NGROK_URL/health/${NC}"
else
    print_warning "Could not retrieve ngrok URL automatically"
    echo -e "   Check manually: ${CYAN}curl http://localhost:4040/api/tunnels${NC}"
    echo -e "   Or visit: ${CYAN}http://localhost:4040${NC}"
fi

echo ""
echo -e "${PURPLE}🏠 LOCAL ACCESS:${NC}"
echo -e "   • Main Application: ${CYAN}http://localhost:8000${NC}"
echo -e "   • ngrok Dashboard:  ${CYAN}http://localhost:4040${NC}"

echo ""
echo -e "${PURPLE}🔐 LOGIN CREDENTIALS:${NC}"
echo -e "   • Username: ${CYAN}admin${NC}"
echo -e "   • Password: ${CYAN}NoctisPro2024!${NC}"

echo ""
echo -e "${PURPLE}📊 RUNNING PROCESSES:${NC}"
echo -e "   • Django: PID $DJANGO_PID"
echo -e "   • ngrok:  PID $NGROK_PID"

echo ""
echo -e "${PURPLE}🔧 MANAGEMENT:${NC}"
echo -e "   • View Django logs: ${CYAN}tail -f django.log${NC}"
echo -e "   • View ngrok logs:  ${CYAN}tail -f ngrok.log${NC}"
echo -e "   • Stop services:    ${CYAN}pkill -f gunicorn && pkill -f ngrok${NC}"

echo ""
echo -e "${PURPLE}💡 TIPS:${NC}"
echo "   • The ngrok URL changes each time you restart (free tier)"
echo "   • For a permanent URL, upgrade to ngrok Pro"
echo "   • The system is now accessible from anywhere on the internet"
echo "   • Share the public URL with your team for remote access"

echo ""
echo -e "${GREEN}✅ Your Noctis Pro PACS system is now publicly accessible!${NC}"
echo -e "   Press ${CYAN}Ctrl+C${NC} to stop or run in background with: ${CYAN}nohup ./start_production_public.sh &${NC}"
echo ""

# Save the URLs for later reference
echo "Public URL: $NGROK_URL" > current_deployment.txt
echo "Local URL: http://localhost:8000" >> current_deployment.txt
echo "Django PID: $DJANGO_PID" >> current_deployment.txt
echo "ngrok PID: $NGROK_PID" >> current_deployment.txt
echo "Started: $(date)" >> current_deployment.txt

# Keep the script running to show logs
print_info "Monitoring logs (Press Ctrl+C to stop)..."
trap 'echo ""; echo "Stopping services..."; kill $DJANGO_PID $NGROK_PID 2>/dev/null; exit' INT

# Show live logs
tail -f django.log &
wait