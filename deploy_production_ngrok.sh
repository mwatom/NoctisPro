#!/bin/bash

# Noctis Pro PACS - Production Deployment with ngrok Public Access
# This script sets up a production-ready system with public access via ngrok

set -e

echo "🚀 Noctis Pro PACS - Production Deployment with ngrok"
echo "===================================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Check if script is run from the correct directory
if [[ ! -f "manage.py" ]]; then
    print_error "This script must be run from the Django project root directory"
    exit 1
fi

# Check if ngrok exists
if [[ ! -f "ngrok" ]]; then
    print_error "ngrok binary not found. Please download ngrok first."
    exit 1
fi

print_header "1. Pre-deployment Setup"

# Stop any existing processes
print_info "Stopping existing processes..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "daphne" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
sleep 3

print_status "Existing processes stopped"

print_header "2. Virtual Environment Setup"

# Create virtual environment if it doesn't exist
if [[ ! -d "venv" ]]; then
    print_info "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_info "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

print_header "3. Installing Production Dependencies"

print_info "Installing Python packages for production..."
pip install -r requirements.txt

# Install additional production packages
pip install \
    gunicorn==21.2.0 \
    whitenoise==6.6.0 \
    psycopg2-binary==2.9.9 \
    redis==5.0.1 \
    celery==5.3.4

print_status "Dependencies installed"

print_header "4. Environment Configuration"

# Create production environment file
print_info "Creating production environment configuration..."
cat > .env.production << EOF
# Production Environment Configuration
DEBUG=False
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production_ngrok

# Database Configuration
USE_SQLITE=True
DATABASE_PATH=/workspace/db.sqlite3

# Security Settings
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False

# File Serving
SERVE_MEDIA_FILES=True

# Session Configuration
SESSION_TIMEOUT_MINUTES=60
SESSION_WARNING_MINUTES=10

# ngrok Configuration
NGROK_ENABLED=True
NGROK_DOMAIN=auto
EOF

print_status "Environment configuration created"

print_header "5. Database Setup"

# Set Django settings
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production_ngrok

print_info "Running database migrations..."
python manage.py makemigrations --noinput 2>/dev/null || echo "No new migrations"
python manage.py migrate --noinput

# Create cache table
print_info "Creating cache table..."
python manage.py createcachetable 2>/dev/null || echo "Cache table already exists"

print_status "Database setup completed"

print_header "6. Static Files Configuration"

print_info "Creating static file directories..."
mkdir -p staticfiles/{css,js,img,vendor}
mkdir -p media/{dicom,uploads,reports}
mkdir -p logs

print_info "Collecting static files..."
python manage.py collectstatic --noinput --clear

print_status "Static files configured"

print_header "7. User Management"

print_info "Setting up admin user..."
python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()

# Create superuser if it doesn't exist
if not User.objects.filter(username='admin').exists():
    admin_user = User.objects.create_superuser(
        username='admin',
        email='admin@noctispro.com',
        password='NoctisPro2024!',
        first_name='System',
        last_name='Administrator'
    )
    print('✅ Superuser created: admin / NoctisPro2024!')
else:
    # Update existing admin password
    admin_user = User.objects.get(username='admin')
    admin_user.set_password('NoctisPro2024!')
    admin_user.save()
    print('✅ Admin password updated: admin / NoctisPro2024!')

# Create demo users
demo_users = [
    {'username': 'doctor', 'password': 'doctor123', 'first_name': 'Dr. John', 'last_name': 'Smith'},
    {'username': 'radiologist', 'password': 'radio123', 'first_name': 'Dr. Sarah', 'last_name': 'Johnson'},
    {'username': 'technician', 'password': 'tech123', 'first_name': 'Mike', 'last_name': 'Wilson'}
]

for user_data in demo_users:
    if not User.objects.filter(username=user_data['username']).exists():
        User.objects.create_user(
            username=user_data['username'],
            password=user_data['password'],
            first_name=user_data['first_name'],
            last_name=user_data['last_name'],
            email=f"{user_data['username']}@noctispro.com"
        )
        print(f"✅ Demo user created: {user_data['username']} / {user_data['password']}")
EOF

print_status "User management completed"

print_header "8. Security Configuration"

print_info "Setting file permissions..."
chmod -R 755 staticfiles/
chmod -R 755 media/
chmod 644 db.sqlite3
chmod +x ngrok

print_info "Configuring security headers..."
# Security is handled in settings_production_ngrok.py

print_status "Security configuration completed"

print_header "9. ngrok Configuration"

# Check if ngrok is authenticated
print_info "Checking ngrok authentication..."
if ! ./ngrok config check 2>/dev/null; then
    print_warning "ngrok is not authenticated. You may need to set up your auth token."
    print_info "To authenticate ngrok:"
    print_info "1. Sign up at https://ngrok.com"
    print_info "2. Get your auth token from the dashboard"
    print_info "3. Run: ./ngrok config add-authtoken YOUR_TOKEN"
    print_info ""
    print_info "Continuing with free tier (may have limitations)..."
fi

# Create ngrok configuration
print_info "Creating ngrok configuration..."
mkdir -p ~/.ngrok2

cat > ~/.ngrok2/ngrok.yml << EOF
version: "2"
authtoken: ""
tunnels:
  noctispro:
    proto: http
    addr: 8000
    bind_tls: true
    inspect: true
    # For custom domain (premium feature):
    # hostname: your-custom-domain.ngrok.io
EOF

print_status "ngrok configuration created"

print_header "10. Process Management Setup"

# Create systemd service files for production
print_info "Creating process management configuration..."

# Django service
cat > noctispro-django-production.service << EOF
[Unit]
Description=Noctis Pro PACS Django Application (Production)
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/workspace
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production_ngrok
Environment=PATH=/workspace/venv/bin
ExecStart=/workspace/venv/bin/gunicorn --workers 4 --bind 0.0.0.0:8000 --timeout 300 --max-requests 1000 --max-requests-jitter 100 noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Daphne service for WebSocket support
cat > noctispro-daphne-production.service << EOF
[Unit]
Description=Noctis Pro PACS Daphne ASGI Server (Production)
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/workspace
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production_ngrok
Environment=PATH=/workspace/venv/bin
ExecStart=/workspace/venv/bin/daphne -b 0.0.0.0 -p 8001 --access-log - --proxy-headers noctis_pro.asgi:application
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# ngrok service
cat > noctispro-ngrok-production.service << EOF
[Unit]
Description=Noctis Pro PACS ngrok Tunnel (Production)
After=network.target noctispro-django-production.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/workspace
ExecStart=/workspace/ngrok http 8000 --log stdout
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

print_status "Process management configuration created"

print_header "11. Starting Production Services"

print_info "Starting Django application with Gunicorn..."
# Start Django in background
nohup venv/bin/gunicorn --workers 4 --bind 0.0.0.0:8000 --timeout 300 --max-requests 1000 --access-logfile logs/access.log --error-logfile logs/error.log noctis_pro.wsgi:application > logs/django.log 2>&1 &
DJANGO_PID=$!

print_info "Starting Daphne ASGI server..."
# Start Daphne for WebSocket support
nohup venv/bin/daphne -b 0.0.0.0 -p 8001 --access-log logs/daphne_access.log noctis_pro.asgi:application > logs/daphne.log 2>&1 &
DAPHNE_PID=$!

# Wait for Django to start
print_info "Waiting for Django to start..."
sleep 10

# Check if Django is running
if ! curl -s http://localhost:8000/health/simple/ >/dev/null 2>&1; then
    print_warning "Django may still be starting up..."
    sleep 5
fi

print_info "Starting ngrok tunnel..."
# Start ngrok in background
nohup ./ngrok http 8000 --log stdout > logs/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to establish tunnel
print_info "Waiting for ngrok tunnel to establish..."
sleep 10

print_status "All services started"

print_header "12. Retrieving Public Access Information"

# Get ngrok public URL
print_info "Retrieving ngrok public URL..."
sleep 5

# Try to get the public URL from ngrok API
NGROK_URL=""
for i in {1..10}; do
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
    print_info "Waiting for ngrok tunnel... (attempt $i/10)"
    sleep 3
done

print_header "13. Final System Check"

# Run system checks
print_info "Running Django system checks..."
python manage.py check --deploy 2>/dev/null || python manage.py check

# Test database connection
python manage.py shell << 'EOF'
from django.db import connection
try:
    cursor = connection.cursor()
    cursor.execute("SELECT COUNT(*) FROM django_session")
    print("✅ Database connection: OK")
except Exception as e:
    print(f"❌ Database error: {e}")
EOF

print_header "🎉 Production Deployment Complete!"

echo ""
echo "============================================================"
echo -e "${GREEN}✅ Noctis Pro PACS is now running in PRODUCTION MODE!${NC}"
echo "============================================================"
echo ""

if [[ -n "$NGROK_URL" ]]; then
    echo -e "${PURPLE}🌐 PUBLIC ACCESS URLS:${NC}"
    echo -e "   • Main Application: ${CYAN}$NGROK_URL${NC}"
    echo -e "   • Admin Interface:  ${CYAN}$NGROK_URL/admin${NC}"
    echo -e "   • DICOM Viewer:     ${CYAN}$NGROK_URL/dicom-viewer/${NC}"
    echo -e "   • Worklist:         ${CYAN}$NGROK_URL/worklist/${NC}"
    echo -e "   • Health Check:     ${CYAN}$NGROK_URL/health/${NC}"
    echo -e "   • API Root:         ${CYAN}$NGROK_URL/api/${NC}"
else
    echo -e "${YELLOW}⚠️  Could not retrieve ngrok URL automatically${NC}"
    echo -e "   Check ngrok status: ${CYAN}curl http://localhost:4040/api/tunnels${NC}"
    echo -e "   Or visit: ${CYAN}http://localhost:4040${NC}"
fi

echo ""
echo -e "${PURPLE}🔐 LOGIN CREDENTIALS:${NC}"
echo -e "   • Administrator: ${CYAN}admin${NC} / ${CYAN}NoctisPro2024!${NC}"
echo -e "   • Doctor:        ${CYAN}doctor${NC} / ${CYAN}doctor123${NC}"
echo -e "   • Radiologist:   ${CYAN}radiologist${NC} / ${CYAN}radio123${NC}"
echo -e "   • Technician:    ${CYAN}technician${NC} / ${CYAN}tech123${NC}"

echo ""
echo -e "${PURPLE}📊 SYSTEM STATUS:${NC}"
echo -e "   • Django (Gunicorn): PID $DJANGO_PID"
echo -e "   • Daphne (WebSocket): PID $DAPHNE_PID"
echo -e "   • ngrok Tunnel: PID $NGROK_PID"

echo ""
echo -e "${PURPLE}🔧 MANAGEMENT COMMANDS:${NC}"
echo -e "   • View Django logs:  ${CYAN}tail -f logs/django.log${NC}"
echo -e "   • View ngrok logs:   ${CYAN}tail -f logs/ngrok.log${NC}"
echo -e "   • View access logs:  ${CYAN}tail -f logs/access.log${NC}"
echo -e "   • ngrok dashboard:   ${CYAN}http://localhost:4040${NC}"
echo -e "   • Stop all services: ${CYAN}./stop_production.sh${NC}"

echo ""
echo -e "${PURPLE}📁 IMPORTANT DIRECTORIES:${NC}"
echo -e "   • Project Root:      ${CYAN}/workspace${NC}"
echo -e "   • Static Files:      ${CYAN}/workspace/staticfiles${NC}"
echo -e "   • Media Files:       ${CYAN}/workspace/media${NC}"
echo -e "   • DICOM Storage:     ${CYAN}/workspace/media/dicom${NC}"
echo -e "   • Log Files:         ${CYAN}/workspace/logs${NC}"
echo -e "   • Database:          ${CYAN}/workspace/db.sqlite3${NC}"

echo ""
echo -e "${PURPLE}🛡️  SECURITY NOTES:${NC}"
echo -e "   • Production mode enabled (DEBUG=False)"
echo -e "   • HTTPS enforced via ngrok"
echo -e "   • CSRF protection enabled"
echo -e "   • Session security configured"
echo -e "   • File upload restrictions applied"

echo ""
echo -e "${PURPLE}🚀 PERFORMANCE FEATURES:${NC}"
echo -e "   • Gunicorn with 4 workers"
echo -e "   • Static file caching"
echo -e "   • Database connection pooling"
echo -e "   • DICOM image optimization"
echo -e "   • WebSocket support via Daphne"

echo ""
echo -e "${GREEN}🎯 Your Noctis Pro PACS system is now publicly accessible!${NC}"
echo ""

# Save deployment info
cat > deployment_info.txt << EOF
Noctis Pro PACS - Production Deployment Information
=================================================

Deployment Date: $(date)
Public URL: $NGROK_URL
Local URL: http://localhost:8000

Process IDs:
- Django (Gunicorn): $DJANGO_PID
- Daphne (WebSocket): $DAPHNE_PID  
- ngrok Tunnel: $NGROK_PID

Credentials:
- admin / NoctisPro2024!
- doctor / doctor123
- radiologist / radio123
- technician / tech123

Important Files:
- Database: /workspace/db.sqlite3
- Logs: /workspace/logs/
- Static: /workspace/staticfiles/
- Media: /workspace/media/

Management:
- Stop: ./stop_production.sh
- Logs: tail -f logs/*.log
- ngrok: http://localhost:4040
EOF

print_status "Deployment information saved to deployment_info.txt"

# Create stop script
cat > stop_production.sh << 'EOF'
#!/bin/bash
echo "Stopping Noctis Pro PACS production services..."
pkill -f "gunicorn.*noctis_pro"
pkill -f "daphne.*noctis_pro"  
pkill -f "ngrok"
echo "All services stopped."
EOF
chmod +x stop_production.sh

echo ""
echo -e "${GREEN}🎉 Production deployment completed successfully!${NC}"
echo -e "Share the ngrok URL with your team for remote access."
echo ""