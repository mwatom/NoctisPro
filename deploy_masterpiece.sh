#!/bin/bash

# 🚀 DEPLOY NOCTISPRO MASTERPIECE - REFINED SYSTEM ONLY
# This script FORCES deployment of the refined system in noctis_pro_deployment/

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NOCTISPRO MASTERPIECE DEPLOYMENT${NC}"
    echo -e "${CYAN}   REFINED SYSTEM ONLY - NOT OLD SYSTEM${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_header

# FORCE STOP ALL OLD PROCESSES
print_info "Stopping all old system processes..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "python.*manage.py" 2>/dev/null || true
pkill -f ngrok 2>/dev/null || true
sleep 2

# VERIFY WE'RE USING THE REFINED SYSTEM
REFINED_DIR="/workspace/noctis_pro_deployment"
if [ ! -d "$REFINED_DIR" ]; then
    print_error "Refined system directory not found at $REFINED_DIR"
    exit 1
fi

print_success "Found refined system at $REFINED_DIR"

# GO TO REFINED SYSTEM DIRECTORY
cd "$REFINED_DIR"

# CHECK IF VENV EXISTS, CREATE IF NOT
if [ ! -d "venv" ]; then
    print_info "Creating virtual environment..."
    python3 -m venv venv
fi

# ACTIVATE VENV AND INSTALL REQUIREMENTS
print_info "Setting up Python environment..."
source venv/bin/activate

# Install minimal requirements quickly
pip install -q Django Pillow django-widget-tweaks python-dotenv gunicorn whitenoise \
    psycopg2-binary dj-database-url redis django-redis djangorestframework \
    django-cors-headers channels channels-redis daphne pydicom pynetdicom \
    numpy requests django-extensions scipy matplotlib opencv-python scikit-image

# RUN MIGRATIONS
print_info "Setting up database..."
python manage.py migrate --run-syncdb

# START DJANGO SERVER
print_info "Starting Django server on port 8000..."
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

# Wait for Django to start
sleep 3

# TEST LOCAL ACCESS
if curl -s http://localhost:8000 > /dev/null; then
    print_success "Django server is running correctly"
else
    print_error "Django server failed to start"
    exit 1
fi

# START NGROK
print_info "Starting ngrok tunnel..."
cd /workspace
./ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app > /workspace/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to establish
sleep 5

# CHECK NGROK STATUS
if curl -s http://localhost:4040/api/tunnels > /dev/null 2>&1; then
    print_success "Ngrok tunnel established"
    echo ""
    echo -e "${GREEN}🌐 DEPLOYMENT COMPLETE!${NC}"
    echo -e "${GREEN}🔗 Access your MASTERPIECE system at:${NC}"
    echo -e "${YELLOW}   https://colt-charmed-lark.ngrok-free.app${NC}"
    echo -e "${BLUE}📱 Local access: http://localhost:8000${NC}"
    echo ""
    echo -e "${CYAN}🩺 Features Available:${NC}"
    echo -e "   • DICOM Image Viewer"
    echo -e "   • AI Analysis"
    echo -e "   • Medical Reporting"
    echo -e "   • User Management"
    echo -e "   • Worklist Management"
    echo ""
else
    print_error "Ngrok tunnel failed - check auth token"
    echo -e "${YELLOW}🔗 System running locally at: http://localhost:8000${NC}"
fi

# Save process IDs
echo $DJANGO_PID > /tmp/noctispro_django.pid
echo $NGROK_PID > /tmp/noctispro_ngrok.pid

print_success "MASTERPIECE SYSTEM IS LIVE!"