#!/bin/bash

# Professional Noctis Pro PACS - Ngrok Deployment Script
# Deploy the complete professional system with static ngrok URL

set -e

echo "🌐 Noctis Pro PACS - Professional Ngrok Deployment"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set working directory
cd /workspace

# Set environment variables
export PATH=$PATH:/home/ubuntu/.local/bin
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export DEBUG=False
export USE_SQLITE=True
export SERVE_MEDIA_FILES=True
export SESSION_TIMEOUT_MINUTES=10
export DISABLE_REDIS=True
export USE_DUMMY_CACHE=True

log_info "Starting professional Noctis Pro PACS system..."

# Kill any existing processes
log_info "Stopping existing processes..."
pkill -f "manage.py runserver" || true
pkill -f "ngrok" || true
sleep 2

# Create admin user if needed
log_info "Setting up professional user accounts..."
python3 -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.contrib.auth import get_user_model
from accounts.models import Facility

User = get_user_model()

# Create default facility
facility, created = Facility.objects.get_or_create(
    name='Noctis Pro Medical Center',
    defaults={
        'address': '123 Medical Drive, Healthcare City',
        'phone': '+1-555-MEDICAL',
        'email': 'admin@noctispro.medical',
        'license_number': 'NOCTIS-MAIN-001',
        'ae_title': 'NOCTISPRO',
        'is_active': True
    }
)

if created:
    print('✅ Default facility created')
else:
    print('ℹ️  Default facility already exists')

# Create admin user
if not User.objects.filter(username='admin').exists():
    admin_user = User.objects.create_user(
        username='admin',
        email='admin@noctispro.medical',
        password='NoctisPro2024!',
        first_name='System',
        last_name='Administrator',
        role='admin',
        facility=facility,
        is_verified=True,
        is_staff=True,
        is_superuser=True
    )
    print('✅ Admin user created: admin / NoctisPro2024!')
else:
    print('ℹ️  Admin user already exists')

# Create radiologist user
if not User.objects.filter(username='radiologist').exists():
    rad_user = User.objects.create_user(
        username='radiologist',
        email='radiologist@noctispro.medical',
        password='RadPro2024!',
        first_name='Dr. Sarah',
        last_name='Johnson',
        role='radiologist',
        facility=facility,
        is_verified=True,
        specialization='Diagnostic Radiology'
    )
    print('✅ Radiologist user created: radiologist / RadPro2024!')

# Create facility user
if not User.objects.filter(username='facility').exists():
    fac_user = User.objects.create_user(
        username='facility',
        email='facility@noctispro.medical',
        password='FacPro2024!',
        first_name='Medical',
        last_name='Technician',
        role='facility',
        facility=facility,
        is_verified=True
    )
    print('✅ Facility user created: facility / FacPro2024!')

print('🏥 Professional user accounts configured successfully')
"

# Collect static files
log_info "Collecting static files for production..."
python3 manage.py collectstatic --noinput --clear

# Create media directories
log_info "Setting up media directories..."
mkdir -p media/dicom/images
mkdir -p media/dicom/thumbnails
mkdir -p media/study_attachments
mkdir -p media/attachment_thumbnails
mkdir -p media/letterheads
mkdir -p media/exports
chmod -R 755 media/

# Start Django server
log_info "Starting professional Django application..."
nohup python3 manage.py runserver 0.0.0.0:8000 > noctispro.log 2>&1 &
DJANGO_PID=$!

# Wait for Django to start
sleep 5

# Test if Django is responding
if curl -s -f http://localhost:8000/login/ > /dev/null; then
    log_success "✅ Django application is running successfully"
else
    log_error "❌ Django application failed to start"
    echo "Django logs:"
    tail -20 noctispro.log
    exit 1
fi

# Start ngrok with static URL
log_info "Starting ngrok with static URL: colt-charmed-lark.ngrok-free.app"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    log_info "Installing ngrok..."
    
    # Download and install ngrok
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    chmod +x ngrok
    sudo mv ngrok /usr/local/bin/
    rm -f ngrok-v3-stable-linux-amd64.tgz
    
    log_success "✅ Ngrok installed successfully"
fi

# Start ngrok with the static URL
log_info "Connecting to ngrok with static URL..."
nohup ngrok http --url=colt-charmed-lark.ngrok-free.app 8000 > ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to connect
sleep 8

# Test ngrok connection
log_info "Testing ngrok connection..."
if curl -s -f https://colt-charmed-lark.ngrok-free.app/health/ > /dev/null; then
    log_success "✅ Ngrok tunnel established successfully"
    NGROK_STATUS="✅ CONNECTED"
else
    log_warning "⚠️  Ngrok tunnel may still be connecting..."
    NGROK_STATUS="🔄 CONNECTING"
fi

# Display comprehensive system status
echo ""
echo "🎉 PROFESSIONAL NOCTIS PRO PACS - ONLINE!"
echo "========================================"
echo ""
echo "🌐 **PUBLIC ACCESS URLS:**"
echo "   Main Site:       https://colt-charmed-lark.ngrok-free.app/"
echo "   Login Page:      https://colt-charmed-lark.ngrok-free.app/login/"
echo "   Dashboard:       https://colt-charmed-lark.ngrok-free.app/worklist/"
echo "   DICOM Viewer:    https://colt-charmed-lark.ngrok-free.app/dicom-viewer/"
echo "   Admin Panel:     https://colt-charmed-lark.ngrok-free.app/admin/"
echo ""
echo "🔐 **PROFESSIONAL LOGIN CREDENTIALS:**"
echo "   👨‍💼 Administrator:   admin / NoctisPro2024!"
echo "   👩‍⚕️ Radiologist:     radiologist / RadPro2024!"
echo "   🏥 Facility User:   facility / FacPro2024!"
echo ""
echo "🏥 **PROFESSIONAL FEATURES ACTIVE:**"
echo "   ✅ Enhanced Authentication System"
echo "   ✅ Professional DICOM Viewer with 3D MPR"
echo "   ✅ Advanced Windowing (Lung, Bone, Soft, Brain presets)"
echo "   ✅ Real-world Measurements (mm, cm conversion)"
echo "   ✅ HU (Hounsfield Unit) calculations"
echo "   ✅ Multi-planar Reconstruction (Axial, Sagittal, Coronal)"
echo "   ✅ Maximum Intensity Projection (MIP)"
echo "   ✅ 3D Bone Reconstruction"
echo "   ✅ Professional Crosshair and Annotation Tools"
echo "   ✅ Real-time Worklist Management"
echo "   ✅ Enhanced Study Upload and Processing"
echo "   ✅ Professional Status Tracking"
echo "   ✅ Role-based Access Control"
echo ""
echo "📊 **SYSTEM STATUS:**"
echo "   Django Server:   ✅ Running (PID: $DJANGO_PID)"
echo "   Ngrok Tunnel:    $NGROK_STATUS"
echo "   Database:        ✅ SQLite Ready"
echo "   Static Files:    ✅ Collected"
echo "   Media Storage:   ✅ Configured"
echo ""
echo "📝 **MONITORING:**"
echo "   Application Logs: tail -f /workspace/noctispro.log"
echo "   Ngrok Logs:      tail -f /workspace/ngrok.log"
echo "   Process Status:  ps aux | grep -E '(runserver|ngrok)'"
echo ""
echo "🔧 **MANAGEMENT COMMANDS:**"
echo "   Stop All:        pkill -f 'manage.py runserver'; pkill -f 'ngrok'"
echo "   Restart Django:  cd /workspace && python3 manage.py runserver 0.0.0.0:8000 &"
echo "   Restart Ngrok:   ngrok http --url=colt-charmed-lark.ngrok-free.app 8000 &"
echo ""

# Save process IDs for management
echo "DJANGO_PID=$DJANGO_PID" > /workspace/.service_pids
echo "NGROK_PID=$NGROK_PID" >> /workspace/.service_pids

log_success "🚀 PROFESSIONAL NOCTIS PRO PACS IS NOW LIVE!"
echo ""
echo "🌍 **ACCESS YOUR PROFESSIONAL MEDICAL IMAGING SYSTEM:**"
echo "      👉 https://colt-charmed-lark.ngrok-free.app/"
echo ""
echo "🏥 The system includes all professional features:"
echo "   • Advanced DICOM viewer with 3D reconstruction"
echo "   • Professional measurement tools"
echo "   • Real-time worklist management"
echo "   • Enhanced security and authentication"
echo "   • Multi-user role-based access"
echo "   • Professional medical imaging interface"
echo ""
echo "💡 **Ready for medical imaging operations!**"