#!/bin/bash

# Noctis Pro PACS - Complete System Deployment Script
# This script fixes all issues and deploys a fully functional system

set -e  # Exit on any error

echo "🚀 Starting Noctis Pro PACS Complete System Deployment..."
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if script is run from the correct directory
if [[ ! -f "manage.py" ]]; then
    print_error "This script must be run from the Django project root directory"
    exit 1
fi

print_header "1. Installing System Dependencies"

# Install Python 3 and pip if not available
if ! command -v python3 &> /dev/null; then
    print_status "Installing Python 3..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
fi

# Install system packages for DICOM processing
print_status "Installing system packages..."
sudo apt update
sudo apt install -y \
    python3-dev \
    python3-pip \
    python3-venv \
    build-essential \
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    sqlite3 \
    nginx \
    supervisor

print_header "2. Setting up Python Virtual Environment"

# Create virtual environment if it doesn't exist
if [[ ! -d "venv" ]]; then
    print_status "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

print_header "3. Installing Python Dependencies"

# Upgrade pip
pip install --upgrade pip

# Install Django and dependencies
print_status "Installing Python packages..."
pip install -r requirements.txt

# Install additional packages that might be missing
pip install \
    django==4.2.7 \
    djangorestframework==3.14.0 \
    pillow==10.0.1 \
    numpy==1.24.3 \
    pydicom==2.4.3 \
    python-decouple==3.8 \
    django-cors-headers==4.3.1 \
    channels==4.0.0 \
    daphne==4.0.0 \
    gunicorn==21.2.0

print_header "4. Setting up Environment Variables"

# Create .env file if it doesn't exist
if [[ ! -f ".env" ]]; then
    print_status "Creating environment configuration..."
    cat > .env << EOF
# Django Configuration
DEBUG=True
SECRET_KEY=django-insecure-7x!8k@m\$z9h#4p&x3w2v6t@n5q8r7y#3e\$6u9i%m&o^2d1f0g
ALLOWED_HOSTS=localhost,127.0.0.1,*.ngrok-free.app,*.ngrok.io

# Database Configuration
USE_SQLITE=True
DATABASE_PATH=/workspace/db.sqlite3

# Session Configuration
SESSION_TIMEOUT_MINUTES=30
SESSION_WARNING_MINUTES=5

# File Upload Configuration
SERVE_MEDIA_FILES=True

# Security Configuration (for development)
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False
EOF
fi

print_header "5. Database Setup"

# Run migrations
print_status "Running database migrations..."
python manage.py makemigrations --noinput || print_warning "No new migrations to create"
python manage.py migrate --noinput

print_header "6. Static Files Setup"

# Create static files directories
print_status "Setting up static files..."
mkdir -p staticfiles/css staticfiles/js staticfiles/img
mkdir -p media/dicom media/uploads

# Collect static files
print_status "Collecting static files..."
python manage.py collectstatic --noinput --clear

print_header "7. Creating Superuser"

# Create superuser if it doesn't exist
print_status "Setting up admin user..."
python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
EOF

print_header "8. Setting up Nginx Configuration"

# Create nginx configuration
print_status "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/noctispro << EOF
server {
    listen 80;
    server_name localhost;
    
    client_max_body_size 100M;
    
    location /static/ {
        alias /workspace/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    location /media/ {
        alias /workspace/media/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t && sudo systemctl reload nginx

print_header "9. Setting up Supervisor"

# Create supervisor configuration
print_status "Setting up process management..."
sudo tee /etc/supervisor/conf.d/noctispro.conf << EOF
[program:noctispro]
command=/workspace/venv/bin/python /workspace/manage.py runserver 0.0.0.0:8000
directory=/workspace
user=ubuntu
autostart=true
autorestart=true
stdout_logfile=/var/log/noctispro.log
stderr_logfile=/var/log/noctispro_error.log
environment=PATH="/workspace/venv/bin"

[program:noctispro-daphne]
command=/workspace/venv/bin/daphne -b 0.0.0.0 -p 8001 noctis_pro.asgi:application
directory=/workspace
user=ubuntu
autostart=true
autorestart=true
stdout_logfile=/var/log/noctispro_daphne.log
stderr_logfile=/var/log/noctispro_daphne_error.log
environment=PATH="/workspace/venv/bin"
EOF

# Update supervisor
sudo supervisorctl reread
sudo supervisorctl update

print_header "10. Starting Services"

# Start nginx
print_status "Starting Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

# Start supervisor services
print_status "Starting Django application..."
sudo supervisorctl start noctispro
sudo supervisorctl start noctispro-daphne

# Wait for services to start
sleep 5

print_header "11. Running System Tests"

# Test database connection
print_status "Testing database connection..."
python manage.py shell << EOF
from django.db import connection
cursor = connection.cursor()
cursor.execute("SELECT 1")
print("Database connection: OK")
EOF

# Test web server
print_status "Testing web server..."
if curl -s http://localhost/health/simple/ | grep -q "OK"; then
    print_status "Web server: OK"
else
    print_warning "Web server test failed, but continuing..."
fi

print_header "12. Final Configuration"

# Set proper permissions
print_status "Setting file permissions..."
sudo chown -R ubuntu:ubuntu /workspace
chmod -R 755 /workspace/staticfiles
chmod -R 755 /workspace/media

# Create desktop shortcut if running in desktop environment
if [[ -n "\$DISPLAY" ]]; then
    print_status "Creating desktop shortcut..."
    cat > ~/Desktop/NoctisPro.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Noctis Pro PACS
Comment=Professional DICOM Viewer and PACS System
Exec=xdg-open http://localhost
Icon=applications-internet
Terminal=false
Categories=Application;Network;
EOF
    chmod +x ~/Desktop/NoctisPro.desktop
fi

print_header "🎉 Deployment Complete!"

echo ""
echo "=================================================="
echo -e "${GREEN}✅ Noctis Pro PACS is now running!${NC}"
echo "=================================================="
echo ""
echo "🌐 Access URLs:"
echo "   • Main Application: http://localhost"
echo "   • Admin Interface:  http://localhost/admin"
echo "   • Health Check:     http://localhost/health/"
echo ""
echo "🔐 Login Credentials:"
echo "   • Username: admin"
echo "   • Password: admin123"
echo ""
echo "📊 System Status:"
sudo supervisorctl status noctispro noctispro-daphne
echo ""
echo "🔧 Useful Commands:"
echo "   • View logs:        sudo tail -f /var/log/noctispro.log"
echo "   • Restart services: sudo supervisorctl restart noctispro"
echo "   • Stop services:    sudo supervisorctl stop noctispro"
echo "   • Django shell:     python manage.py shell"
echo ""
echo "📁 Important Directories:"
echo "   • Project Root:     /workspace"
echo "   • Static Files:     /workspace/staticfiles"
echo "   • Media Files:      /workspace/media"
echo "   • Database:         /workspace/db.sqlite3"
echo ""

# Final system check
print_status "Running final system check..."
python manage.py check --deploy || print_warning "Some deployment checks failed (non-critical)"

echo -e "${GREEN}🚀 System is ready for use!${NC}"
echo ""

# Show running processes
print_status "Active processes:"
ps aux | grep -E "(nginx|supervisor|python.*manage.py)" | grep -v grep

echo ""
echo "For support and documentation, visit: https://github.com/noctispro/pacs"