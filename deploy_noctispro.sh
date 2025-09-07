#!/bin/bash

# =============================================================================
# NoctisPro PACS - Automated Deployment Script for Ubuntu Server 24.04
# =============================================================================
# This script automatically deploys the Django PACS system with ngrok
# Author: AI Assistant
# Date: $(date)
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NGROK_AUTH_TOKEN="32E2HmoUqzrZxaYRNT77wAI0HQs_5N5QNSrxU4Z7d4MFSRF4x"
NGROK_STATIC_URL="mallard-shining-curiously.ngrok-free.app"
DJANGO_PORT=8080
# Determine project directory dynamically with fallback to /workspace
if [[ -d "/workspace" ]]; then
    PROJECT_DIR="/workspace"
else
    PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
VENV_DIR="$PROJECT_DIR/venv"

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons."
        error "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    if ! grep -q "Ubuntu 24.04" /etc/os-release; then
        warn "This script is optimized for Ubuntu 24.04. Your version might work but is not tested."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    log "Installing system dependencies for Ubuntu 24.04..."
    
    sudo apt update
    sudo apt install -y \
        python3.12 \
        python3.12-venv \
        python3.12-dev \
        python3-pip \
        build-essential \
        pkg-config \
        libcups2-dev \
        libcupsimage2-dev \
        libffi-dev \
        libssl-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libwebp-dev \
        zlib1g-dev \
        sqlite3 \
        libsqlite3-dev \
        curl \
        wget \
        git \
        nginx \
        supervisor \
        htop \
        tree \
        unzip
    
    log "System dependencies installed successfully!"
}

# Function to setup Python virtual environment
setup_virtual_environment() {
    log "Setting up Python virtual environment..."
    
    cd "$PROJECT_DIR"
    
    # Remove existing venv if it exists
    if [ -d "$VENV_DIR" ]; then
        warn "Removing existing virtual environment..."
        rm -rf "$VENV_DIR"
    fi
    
    # Create new virtual environment
    python3.12 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    log "Virtual environment created successfully!"
}

# Function to install Python requirements
install_python_requirements() {
    log "Installing Python requirements..."
    
    source "$VENV_DIR/bin/activate"
    cd "$PROJECT_DIR"
    
    # Install requirements with error handling for problematic packages
    if ! pip install -r requirements.txt; then
        warn "Some packages failed to install. Trying alternative approach..."
        
        # Install packages one by one, skipping problematic ones
        while IFS= read -r package; do
            if [[ $package =~ ^#.*$ ]] || [[ -z "$package" ]]; then
                continue
            fi
            
            if [[ $package == "pycups" ]]; then
                warn "Skipping pycups (printing functionality will be limited)"
                continue
            fi
            
            echo "Installing $package..."
            if ! pip install "$package"; then
                warn "Failed to install $package, continuing..."
            fi
        done < requirements.txt
    fi
    
    log "Python requirements installed successfully!"
}

# Function to setup ngrok
setup_ngrok() {
    log "Setting up ngrok..."
    
    # Make ngrok executable
    chmod +x "$PROJECT_DIR/ngrok"
    
    # Add ngrok to PATH if not already there
    if ! command -v "$PROJECT_DIR/ngrok" &> /dev/null; then
        sudo ln -sf "$PROJECT_DIR/ngrok" /usr/local/bin/ngrok
    fi
    
    # Configure ngrok auth token
    "$PROJECT_DIR/ngrok" config add-authtoken "$NGROK_AUTH_TOKEN"
    
    log "Ngrok configured successfully!"
}

# Function to setup Django
setup_django() {
    log "Setting up Django application..."
    
    source "$VENV_DIR/bin/activate"
    cd "$PROJECT_DIR"
    
    # Create logs directory
    mkdir -p logs
    
    # Set environment variables
    export DJANGO_SETTINGS_MODULE=noctis_pro.settings
    export DEBUG=False
    export NGROK_URL="https://$NGROK_STATIC_URL"
    export STATIC_URL="https://$NGROK_STATIC_URL/static/"
    
    # Create .env file for production
    cat > .env << EOF
DEBUG=False
SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
NGROK_URL=https://$NGROK_STATIC_URL
STATIC_URL=https://$NGROK_STATIC_URL/static/
ALLOWED_HOSTS=$NGROK_STATIC_URL,localhost,127.0.0.1,0.0.0.0
DJANGO_SETTINGS_MODULE=noctis_pro.settings
EOF
    
    # Run Django management commands
    python manage.py collectstatic --noinput
    python manage.py makemigrations
    python manage.py migrate
    
    # Create superuser non-interactively
    if ! python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists()" | grep -q True; then
        log "Creating Django superuser..."
        python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('Superuser created: admin/admin123')
else:
    print('Superuser already exists')
"
    fi
    
    log "Django setup completed successfully!"
}

# Function to create systemd service
create_systemd_service() {
    log "Creating systemd service for NoctisPro..."
    
    sudo tee /etc/systemd/system/noctispro.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Django Application
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$VENV_DIR/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=DEBUG=False
Environment=NGROK_URL=https://$NGROK_STATIC_URL
Environment=STATIC_URL=https://$NGROK_STATIC_URL/static/
ExecStart=$VENV_DIR/bin/gunicorn --bind 0.0.0.0:$DJANGO_PORT --workers 3 --timeout 120 noctis_pro.wsgi:application
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable noctispro
    
    log "Systemd service created successfully!"
}

# Function to create ngrok service
create_ngrok_service() {
    log "Creating systemd service for ngrok..."
    
    sudo tee /etc/systemd/system/noctispro-ngrok.service > /dev/null << EOF
[Unit]
Description=Ngrok tunnel for NoctisPro PACS
After=network.target noctispro.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/ngrok http --url=$NGROK_STATIC_URL $DJANGO_PORT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable noctispro-ngrok
    
    log "Ngrok systemd service created successfully!"
}

# Function to start services
start_services() {
    log "Starting NoctisPro services..."
    
    # Start Django application
    sudo systemctl start noctispro
    sleep 5
    
    # Start ngrok tunnel
    sudo systemctl start noctispro-ngrok
    sleep 3
    
    log "Services started successfully!"
}

# Function to show status
show_status() {
    log "Deployment Status:"
    echo
    info "=== System Status ==="
    sudo systemctl status noctispro --no-pager -l
    echo
    sudo systemctl status noctispro-ngrok --no-pager -l
    echo
    
    info "=== Access Information ==="
    echo -e "${GREEN}🌐 Application URL: https://$NGROK_STATIC_URL${NC}"
    echo -e "${GREEN}👤 Admin Login: admin / admin123${NC}"
    echo -e "${GREEN}📊 Admin Panel: https://$NGROK_STATIC_URL/admin/${NC}"
    echo -e "${GREEN}🏥 Worklist: https://$NGROK_STATIC_URL/worklist/${NC}"
    echo
    
    info "=== Service Management ==="
    echo "Start services:   sudo systemctl start noctispro noctispro-ngrok"
    echo "Stop services:    sudo systemctl stop noctispro noctispro-ngrok"
    echo "Restart services: sudo systemctl restart noctispro noctispro-ngrok"
    echo "View logs:        sudo journalctl -f -u noctispro -u noctispro-ngrok"
    echo
}

# Function to create management script
create_management_script() {
    log "Creating management script..."
    
    cat > "$PROJECT_DIR/manage_noctispro.sh" << 'EOF'
#!/bin/bash

# Load .env if present
if [ -f ./.env ]; then
    set -a
    . ./.env
    set +a
fi

case "$1" in
    start)
        echo "Starting NoctisPro services..."
        sudo systemctl start noctispro noctispro-ngrok
        ;;
    stop)
        echo "Stopping NoctisPro services..."
        sudo systemctl stop noctispro noctispro-ngrok
        ;;
    restart)
        echo "Restarting NoctisPro services..."
        sudo systemctl restart noctispro noctispro-ngrok
        ;;
    status)
        sudo systemctl status noctispro noctispro-ngrok
        ;;
    logs)
        sudo journalctl -f -u noctispro -u noctispro-ngrok
        ;;
    url)
        if [ -n "$NGROK_URL" ]; then
            echo "$NGROK_URL"
        else
            echo "https://mallard-shining-curiously.ngrok-free.app"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|url}"
        exit 1
        ;;
esac
EOF

    chmod +x "$PROJECT_DIR/manage_noctispro.sh"
    
    log "Management script created at $PROJECT_DIR/manage_noctispro.sh"
}

# Main deployment function
main() {
    log "Starting NoctisPro PACS deployment for Ubuntu Server 24.04..."
    echo
    
    check_root
    check_ubuntu_version
    
    log "=== Phase 1: System Dependencies ==="
    install_system_dependencies
    
    log "=== Phase 2: Python Environment ==="
    setup_virtual_environment
    install_python_requirements
    
    log "=== Phase 3: Ngrok Setup ==="
    setup_ngrok
    
    log "=== Phase 4: Django Configuration ==="
    setup_django
    
    log "=== Phase 5: Service Creation ==="
    create_systemd_service
    create_ngrok_service
    create_management_script
    
    log "=== Phase 6: Service Startup ==="
    start_services
    
    log "=== Deployment Complete! ==="
    show_status
    
    log "🎉 NoctisPro PACS has been successfully deployed!"
    log "🔗 Access your application at: https://$NGROK_STATIC_URL"
}

# Run main function
main "$@"