#!/bin/bash

# ============================================================================
# NoctisPro PACS - Ubuntu Server 22.04 GUI Deployment Script
# ============================================================================
# This script deploys NoctisPro PACS on Ubuntu Server 22.04 with:
# - Desktop GUI environment (GNOME/XFCE)
# - Auto-start after reboot with localhost GUI
# - HTTPS public access via ngrok/cloudflare tunnel
# - Terminal access within GUI for admin tasks
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SYSTEM_USER="noctispro"
APP_DIR="/opt/noctispro"
VENV_DIR="/opt/noctispro/venv"
LOG_FILE="/var/log/noctispro_gui_deployment.log"
DESKTOP_ENV="gnome"  # Options: gnome, xfce, kde

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Detect system resources
detect_resources() {
    local total_ram=$(free -m | awk 'NR==2{print $2}')
    local cpu_cores=$(nproc)
    local disk_space=$(df -h / | awk 'NR==2{print $4}' | sed 's/G//')
    
    log "System Resources Detected:"
    log "  - RAM: ${total_ram}MB"
    log "  - CPU Cores: ${cpu_cores}"
    log "  - Available Disk: ${disk_space}GB"
    
    if [[ $total_ram -lt 4096 ]]; then
        DESKTOP_ENV="xfce"  # Use lightweight XFCE for low RAM
        warning "Low RAM detected. Using XFCE desktop environment for better performance."
    fi
}

# Update system
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
    apt install -y curl wget git unzip software-properties-common
}

# Install desktop environment
install_desktop_environment() {
    log "Installing ${DESKTOP_ENV} desktop environment..."
    
    case $DESKTOP_ENV in
        "gnome")
            apt install -y ubuntu-desktop-minimal
            apt install -y gnome-shell gnome-terminal firefox
            # Remove unnecessary packages to save space
            apt remove -y thunderbird libreoffice-* rhythmbox totem
            ;;
        "xfce")
            apt install -y xfce4 xfce4-goodies lightdm firefox
            apt install -y xfce4-terminal thunar
            ;;
        "kde")
            apt install -y kubuntu-desktop
            ;;
    esac
    
    # Install display manager if not present
    if ! systemctl is-enabled gdm3 >/dev/null 2>&1 && ! systemctl is-enabled lightdm >/dev/null 2>&1; then
        if [[ $DESKTOP_ENV == "gnome" ]]; then
            apt install -y gdm3
            systemctl enable gdm3
        else
            apt install -y lightdm
            systemctl enable lightdm
        fi
    fi
    
    # Enable graphical target
    systemctl set-default graphical.target
}

# Create system user
create_system_user() {
    log "Creating system user: $SYSTEM_USER"
    
    if ! id "$SYSTEM_USER" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo "$SYSTEM_USER"
        echo "$SYSTEM_USER:noctispro123" | chpasswd
        log "User $SYSTEM_USER created with password: noctispro123"
    else
        log "User $SYSTEM_USER already exists"
    fi
    
    # Create application directory
    mkdir -p "$APP_DIR"
    chown -R "$SYSTEM_USER:$SYSTEM_USER" "$APP_DIR"
}

# Install Python and dependencies
install_python_dependencies() {
    log "Installing Python and system dependencies..."
    
    # Install Python 3.12 if not available
    if ! command -v python3.12 &> /dev/null; then
        add-apt-repository ppa:deadsnakes/ppa -y
        apt update
        apt install -y python3.12 python3.12-venv python3.12-dev
    fi
    
    # Install system dependencies
    apt install -y \
        python3-pip python3-venv python3-dev \
        postgresql postgresql-contrib \
        nginx \
        redis-server \
        build-essential \
        libpq-dev \
        libjpeg-dev \
        libpng-dev \
        libffi-dev \
        libssl-dev \
        pkg-config \
        cmake \
        supervisor
}

# Deploy NoctisPro application
deploy_noctispro() {
    log "Deploying NoctisPro PACS application..."
    
    # Copy application files
    if [[ -d "/workspace" ]]; then
        cp -r /workspace/* "$APP_DIR/"
        chown -R "$SYSTEM_USER:$SYSTEM_USER" "$APP_DIR"
    else
        error "Source directory /workspace not found"
    fi
    
    # Create Python virtual environment
    sudo -u "$SYSTEM_USER" python3.12 -m venv "$VENV_DIR"
    
    # Install Python requirements
    sudo -u "$SYSTEM_USER" "$VENV_DIR/bin/pip" install --upgrade pip
    sudo -u "$SYSTEM_USER" "$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt"
    
    # Set up database
    sudo -u postgres createdb noctispro_db || true
    sudo -u postgres createuser noctispro_user || true
    sudo -u postgres psql -c "ALTER USER noctispro_user WITH PASSWORD 'noctispro_pass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctispro_db TO noctispro_user;"
    
    # Django setup
    cd "$APP_DIR"
    sudo -u "$SYSTEM_USER" "$VENV_DIR/bin/python" manage.py migrate
    sudo -u "$SYSTEM_USER" "$VENV_DIR/bin/python" manage.py collectstatic --noinput
    
    # Create superuser
    sudo -u "$SYSTEM_USER" "$VENV_DIR/bin/python" manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')
    print('Superuser created: admin/admin123')
EOF
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    cat > /etc/nginx/sites-available/noctispro << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    client_max_body_size 100M;
    
    location /static/ {
        alias /opt/noctispro/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctispro/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    systemctl enable nginx
}

# Install and configure ngrok for HTTPS public access
setup_ngrok() {
    log "Setting up ngrok for HTTPS public access..."
    
    # Download and install ngrok
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list
    apt update && apt install -y ngrok
    
    # Create ngrok config
    sudo -u "$SYSTEM_USER" mkdir -p /home/$SYSTEM_USER/.config/ngrok
    cat > /home/$SYSTEM_USER/.config/ngrok/ngrok.yml << 'EOF'
version: "2"
authtoken: YOUR_NGROK_AUTH_TOKEN_HERE
tunnels:
  noctispro:
    proto: http
    addr: 80
    schemes: [https, http]
    hostname: noctispro.ngrok.io
EOF
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/.config/ngrok/ngrok.yml
    
    warning "Please update ngrok auth token in /home/$SYSTEM_USER/.config/ngrok/ngrok.yml"
}

# Create systemd services
create_systemd_services() {
    log "Creating systemd services..."
    
    # NoctisPro Django service
    cat > /etc/systemd/system/noctispro.service << EOF
[Unit]
Description=NoctisPro PACS Django Application
After=network.target postgresql.service

[Service]
Type=simple
User=$SYSTEM_USER
Group=$SYSTEM_USER
WorkingDirectory=$APP_DIR
Environment=PATH=$VENV_DIR/bin
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 noctis_pro.wsgi:application
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Ngrok service
    cat > /etc/systemd/system/noctispro-ngrok.service << EOF
[Unit]
Description=Ngrok tunnel for NoctisPro PACS
After=network.target noctispro.service

[Service]
Type=simple
User=$SYSTEM_USER
Group=$SYSTEM_USER
ExecStart=/usr/local/bin/ngrok start noctispro
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable services
    systemctl daemon-reload
    systemctl enable noctispro noctispro-ngrok
}

# Create desktop integration
create_desktop_integration() {
    log "Creating desktop integration..."
    
    # Create desktop entry
    cat > /usr/share/applications/noctispro.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro PACS
Comment=Medical Imaging System
Exec=firefox http://localhost
Icon=applications-internet
Terminal=false
Categories=Office;Medical;
StartupNotify=true
EOF
    
    # Create autostart entry for user
    sudo -u "$SYSTEM_USER" mkdir -p /home/$SYSTEM_USER/.config/autostart
    cat > /home/$SYSTEM_USER/.config/autostart/noctispro-browser.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NoctisPro PACS Browser
Exec=firefox http://localhost
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/.config/autostart/noctispro-browser.desktop
    
    # Create desktop shortcut
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro.desktop /home/$SYSTEM_USER/Desktop/
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/Desktop/noctispro.desktop
    chmod +x /home/$SYSTEM_USER/Desktop/noctispro.desktop
}

# Configure auto-login
configure_auto_login() {
    log "Configuring auto-login for $SYSTEM_USER..."
    
    if [[ $DESKTOP_ENV == "gnome" ]]; then
        # GDM3 auto-login
        cat > /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$SYSTEM_USER

[security]

[xdmcp]

[chooser]

[debug]
EOF
    else
        # LightDM auto-login
        cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
autologin-user=$SYSTEM_USER
autologin-user-timeout=0
EOF
    fi
}

# Create management scripts
create_management_scripts() {
    log "Creating management scripts..."
    
    # System management script
    cat > /usr/local/bin/noctispro-admin << 'EOF'
#!/bin/bash

case "$1" in
    start)
        systemctl start noctispro noctispro-ngrok nginx
        echo "NoctisPro services started"
        ;;
    stop)
        systemctl stop noctispro noctispro-ngrok
        echo "NoctisPro services stopped"
        ;;
    restart)
        systemctl restart noctispro noctispro-ngrok nginx
        echo "NoctisPro services restarted"
        ;;
    status)
        systemctl status noctispro noctispro-ngrok nginx
        ;;
    logs)
        journalctl -f -u noctispro -u noctispro-ngrok
        ;;
    url)
        echo "Local URL: http://localhost"
        if systemctl is-active --quiet noctispro-ngrok; then
            echo "Public URL: Check ngrok dashboard at http://localhost:4040"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|url}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/noctispro-admin
    
    # Create desktop terminal launcher
    cat > /usr/share/applications/noctispro-admin.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro Admin Terminal
Comment=Administrative terminal for NoctisPro PACS
Exec=gnome-terminal -- bash -c "echo 'NoctisPro Admin Terminal'; echo 'Commands: noctispro-admin {start|stop|restart|status|logs|url}'; bash"
Icon=utilities-terminal
Terminal=false
Categories=System;
EOF
    
    # Copy to user desktop
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro-admin.desktop /home/$SYSTEM_USER/Desktop/
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/Desktop/noctispro-admin.desktop
    chmod +x /home/$SYSTEM_USER/Desktop/noctispro-admin.desktop
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    ufw --force enable
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow from 127.0.0.1 to any port 8000
}

# Final system configuration
final_configuration() {
    log "Performing final configuration..."
    
    # Start services
    systemctl start postgresql redis-server nginx
    systemctl start noctispro noctispro-ngrok
    
    # Create info file
    cat > /home/$SYSTEM_USER/Desktop/NoctisPro-Info.txt << EOF
NoctisPro PACS - System Information
==================================

Access URLs:
- Local: http://localhost
- Admin Panel: http://localhost/admin/
- Public URL: Check ngrok dashboard at http://localhost:4040

Login Credentials:
- System User: $SYSTEM_USER / noctispro123
- Django Admin: admin / admin123

Management Commands:
- noctispro-admin start     # Start services
- noctispro-admin stop      # Stop services  
- noctispro-admin restart   # Restart services
- noctispro-admin status    # Check status
- noctispro-admin logs      # View logs
- noctispro-admin url       # Show URLs

Desktop Applications:
- NoctisPro PACS (opens browser)
- NoctisPro Admin Terminal

System will auto-login and open browser on startup.
EOF
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/Desktop/NoctisPro-Info.txt
}

# Main deployment function
main() {
    log "Starting NoctisPro PACS GUI deployment for Ubuntu Server 22.04..."
    
    check_root
    detect_resources
    update_system
    install_desktop_environment
    create_system_user
    install_python_dependencies
    deploy_noctispro
    configure_nginx
    setup_ngrok
    create_systemd_services
    create_desktop_integration
    configure_auto_login
    create_management_scripts
    configure_firewall
    final_configuration
    
    log "Deployment completed successfully!"
    log "System will reboot and auto-login to desktop with NoctisPro running"
    log "Access the system at http://localhost after reboot"
    
    echo ""
    echo "=========================================="
    echo "  NoctisPro PACS GUI Deployment Complete"
    echo "=========================================="
    echo ""
    echo "System User: $SYSTEM_USER / noctispro123"
    echo "Django Admin: admin / admin123"
    echo "Local URL: http://localhost"
    echo ""
    echo "The system will reboot and automatically:"
    echo "1. Login to desktop as $SYSTEM_USER"
    echo "2. Start NoctisPro services"
    echo "3. Open browser to localhost"
    echo ""
    echo "Reboot now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# Run main function
main "$@"