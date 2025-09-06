#!/bin/bash

# 🚀 Noctis Pro PACS - Ubuntu Server Deployment Script
# Professional Medical Imaging System with Ngrok Static URL Support
# Supports both free ngrok tunnels and paid static URLs

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
NOCTIS_USER="noctis"
NOCTIS_DIR="/opt/noctis"
VENV_DIR="$NOCTIS_DIR/venv"
SERVICE_NAME="noctispro"
DOMAIN_NAME=""
NGROK_AUTHTOKEN=""
NGROK_STATIC_URL=""
DB_PASSWORD=""
SECRET_KEY=""

# Function to print colored output
print_header() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}\n"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate secure random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate Django secret key
generate_secret_key() {
    python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
}

# Function to get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        read -p "$prompt: " input
    fi
    
    eval "$var_name='$input'"
}

# Function to get sensitive input (hidden)
get_sensitive_input() {
    local prompt="$1"
    local var_name="$2"
    
    read -s -p "$prompt: " input
    echo
    eval "$var_name='$input'"
}

# Main deployment function
main() {
    print_header "🏥 NOCTIS PRO PACS - UBUNTU SERVER DEPLOYMENT"
    
    echo "This script will install Noctis Pro PACS on Ubuntu Server with:"
    echo "• Professional medical imaging system"
    echo "• Ngrok static URL support (upgradeable to paid plans)"
    echo "• Complete reporting system for radiologists"
    echo "• Secure multi-user access control"
    echo "• Automated service management"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root (sudo ./deploy_ubuntu_server.sh)"
        exit 1
    fi
    
    # Get configuration from user
    collect_configuration
    
    # System checks and preparation
    check_system_requirements
    
    # Install dependencies
    install_system_dependencies
    
    # Create user and directories
    setup_user_and_directories
    
    # Install and configure ngrok
    install_configure_ngrok
    
    # Install Python and dependencies
    install_python_dependencies
    
    # Configure application
    configure_application
    
    # Setup database
    setup_database
    
    # Create systemd services
    create_systemd_services
    
    # Configure nginx (optional)
    configure_nginx
    
    # Start services
    start_services
    
    # Final configuration and testing
    final_configuration
    
    # Display completion information
    display_completion_info
}

collect_configuration() {
    print_header "📋 CONFIGURATION SETUP"
    
    echo "Please provide the following information:"
    echo ""
    
    # Domain/Server name
    get_input "Server domain name or IP address" "$(hostname -I | awk '{print $1}')" "DOMAIN_NAME"
    
    # Ngrok configuration
    echo ""
    print_info "Ngrok Configuration:"
    echo "• Free account: Provides random URLs that change on restart"
    echo "• Paid account: Provides static URLs and custom domains"
    echo ""
    
    get_sensitive_input "Enter your ngrok authtoken (from https://dashboard.ngrok.com/get-started/your-authtoken)" "NGROK_AUTHTOKEN"
    
    echo ""
    echo "Ngrok URL options:"
    echo "1. Use free random URL (changes on restart)"
    echo "2. Use static URL (requires paid plan)"
    echo "3. Use custom domain (requires business plan)"
    echo ""
    
    read -p "Select option [1-3]: " ngrok_option
    
    case $ngrok_option in
        2)
            get_input "Enter your static ngrok URL (e.g., https://noctispro.ngrok-free.app)" "" "NGROK_STATIC_URL"
            ;;
        3)
            get_input "Enter your custom domain (e.g., noctispro.yourdomain.com)" "" "NGROK_STATIC_URL"
            ;;
        *)
            print_info "Using free random URL (will be displayed after deployment)"
            ;;
    esac
    
    # Database password
    echo ""
    DB_PASSWORD=$(generate_password)
    print_info "Generated secure database password: $DB_PASSWORD"
    
    # Secret key will be generated later when Python is available
    
    print_success "Configuration collected successfully"
}

check_system_requirements() {
    print_header "🔍 SYSTEM REQUIREMENTS CHECK"
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        print_warning "This script is designed for Ubuntu. Other distributions may work but are not tested."
    fi
    
    # Check available disk space (minimum 5GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5242880 ]; then  # 5GB in KB
        print_error "Insufficient disk space. At least 5GB required."
        exit 1
    fi
    
    # Check available memory (minimum 2GB)
    available_memory=$(free -m | awk 'NR==2{print $2}')
    if [ "$available_memory" -lt 2048 ]; then
        print_warning "Less than 2GB RAM available. Performance may be affected."
    fi
    
    print_success "System requirements check completed"
}

install_system_dependencies() {
    print_header "📦 INSTALLING SYSTEM DEPENDENCIES"
    
    print_step "Updating package repositories..."
    apt-get update -y
    
    print_step "Installing essential packages..."
    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        postgresql \
        postgresql-contrib \
        nginx \
        supervisor \
        ufw \
        htop \
        tree \
        vim \
        tmux
    
    print_step "Installing Python development packages..."
    apt-get install -y \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libfreetype6-dev \
        liblcms2-dev \
        libwebp-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libxcb1-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        libffi-dev \
        libssl-dev
    
    print_success "System dependencies installed successfully"
}

setup_user_and_directories() {
    print_header "👤 USER AND DIRECTORY SETUP"
    
    print_step "Creating noctis user..."
    if ! id "$NOCTIS_USER" &>/dev/null; then
        useradd -r -m -s /bin/bash "$NOCTIS_USER"
        print_success "Created user: $NOCTIS_USER"
    else
        print_info "User $NOCTIS_USER already exists"
    fi
    
    print_step "Creating application directories..."
    mkdir -p "$NOCTIS_DIR"
    mkdir -p "$NOCTIS_DIR/logs"
    mkdir -p "$NOCTIS_DIR/media"
    mkdir -p "$NOCTIS_DIR/static"
    mkdir -p "$NOCTIS_DIR/backups"
    
    # Copy application files
    print_step "Copying application files..."
    if [ -f "manage.py" ]; then
        cp -r . "$NOCTIS_DIR/app/"
        mkdir -p "$NOCTIS_DIR/app"
        rsync -av --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' . "$NOCTIS_DIR/app/"
    else
        print_error "Application files not found. Please run this script from the Noctis Pro directory."
        exit 1
    fi
    
    # Set permissions
    chown -R "$NOCTIS_USER:$NOCTIS_USER" "$NOCTIS_DIR"
    chmod -R 755 "$NOCTIS_DIR"
    
    print_success "User and directories setup completed"
}

install_configure_ngrok() {
    print_header "🌐 NGROK INSTALLATION AND CONFIGURATION"
    
    print_step "Installing ngrok..."
    
    # Download and install ngrok
    if ! command_exists ngrok; then
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list
        apt-get update
        apt-get install -y ngrok
    fi
    
    print_step "Configuring ngrok..."
    
    # Configure ngrok for noctis user
    sudo -u "$NOCTIS_USER" ngrok config add-authtoken "$NGROK_AUTHTOKEN"
    
    # Create ngrok configuration file
    sudo -u "$NOCTIS_USER" tee "/home/$NOCTIS_USER/.ngrok2/ngrok.yml" > /dev/null <<EOF
version: "2"
authtoken: $NGROK_AUTHTOKEN
tunnels:
  noctispro:
    proto: http
    addr: 8000
    bind_tls: true
$(if [ -n "$NGROK_STATIC_URL" ]; then
    if [[ "$NGROK_STATIC_URL" == *"ngrok-free.app"* ]] || [[ "$NGROK_STATIC_URL" == *"ngrok.app"* ]]; then
        echo "    subdomain: $(echo $NGROK_STATIC_URL | sed 's/https\?:\/\///' | cut -d'.' -f1)"
    else
        echo "    hostname: $(echo $NGROK_STATIC_URL | sed 's/https\?:\/\///')"
    fi
fi)
EOF
    
    print_success "Ngrok installation and configuration completed"
}

install_python_dependencies() {
    print_header "🐍 PYTHON ENVIRONMENT SETUP"
    
    print_step "Creating Python virtual environment..."
    sudo -u "$NOCTIS_USER" python3 -m venv "$VENV_DIR"
    
    print_step "Installing Python packages..."
    sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel
    
    # Install from requirements.txt if it exists
    if [ -f "$NOCTIS_DIR/app/requirements.txt" ]; then
        sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/pip" install -r "$NOCTIS_DIR/app/requirements.txt"
    else
        # Install essential packages
        sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/pip" install \
            django \
            djangorestframework \
            django-cors-headers \
            psycopg2-binary \
            pillow \
            pydicom \
            numpy \
            gunicorn \
            python-decouple
    fi
    
    print_success "Python environment setup completed"
}

configure_application() {
    print_header "⚙️ APPLICATION CONFIGURATION"
    
    print_step "Generating Django secret key..."
    SECRET_KEY=$(sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/python" -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    print_step "Creating environment configuration..."
    sudo -u "$NOCTIS_USER" tee "$NOCTIS_DIR/.env" > /dev/null <<EOF
# Noctis Pro PACS Production Configuration
DEBUG=False
SECRET_KEY=$SECRET_KEY

# Database Configuration
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctispro
DB_USER=noctis_user
DB_PASSWORD=$DB_PASSWORD
DB_HOST=localhost
DB_PORT=5432

# Ngrok Configuration
$(if [ -n "$NGROK_STATIC_URL" ]; then
    echo "NGROK_URL=$NGROK_STATIC_URL"
    echo "ALLOWED_HOSTS=*,$NGROK_STATIC_URL,$(echo $NGROK_STATIC_URL | sed 's/https\?:\/\///'),$DOMAIN_NAME,localhost,127.0.0.1"
else
    echo "NGROK_URL="
    echo "ALLOWED_HOSTS=*,$DOMAIN_NAME,localhost,127.0.0.1"
fi)

# Security Settings
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False

# File Upload Settings
FILE_UPLOAD_MAX_MEMORY_SIZE=5368709120
DATA_UPLOAD_MAX_MEMORY_SIZE=5368709120
DATA_UPLOAD_MAX_NUMBER_FIELDS=15000

# Media and Static Files
MEDIA_ROOT=$NOCTIS_DIR/media
STATIC_ROOT=$NOCTIS_DIR/static
SERVE_MEDIA_FILES=True

# Logging
LOG_LEVEL=INFO
EOF
    
    print_success "Application configuration completed"
}

setup_database() {
    print_header "🗄️ DATABASE SETUP"
    
    print_step "Configuring PostgreSQL..."
    
    # Start PostgreSQL service
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql <<EOF
CREATE DATABASE noctispro;
CREATE USER noctis_user WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE noctispro TO noctis_user;
ALTER USER noctis_user CREATEDB;
\q
EOF
    
    print_step "Running Django migrations..."
    cd "$NOCTIS_DIR/app"
    sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/python" manage.py makemigrations
    sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/python" manage.py migrate
    
    print_step "Collecting static files..."
    sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/python" manage.py collectstatic --noinput
    
    print_step "Setting up report templates for radiologists..."
    sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/python" manage.py setup_report_templates
    
    print_step "Creating superuser account..."
    echo "Please create an administrator account for the system:"
    sudo -u "$NOCTIS_USER" "$VENV_DIR/bin/python" manage.py createsuperuser
    
    print_success "Database setup completed"
}

create_systemd_services() {
    print_header "🔧 SYSTEMD SERVICES SETUP"
    
    print_step "Creating Noctis Pro service..."
    tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null <<EOF
[Unit]
Description=Noctis Pro PACS Django Application
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$NOCTIS_USER
Group=$NOCTIS_USER
WorkingDirectory=$NOCTIS_DIR/app
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
EnvironmentFile=$NOCTIS_DIR/.env
ExecStart=$VENV_DIR/bin/gunicorn noctis_pro.wsgi:application \\
    --bind 127.0.0.1:8000 \\
    --workers 3 \\
    --timeout 120 \\
    --keep-alive 5 \\
    --max-requests 1000 \\
    --access-logfile $NOCTIS_DIR/logs/access.log \\
    --error-logfile $NOCTIS_DIR/logs/error.log \\
    --log-level info
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=10
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    print_step "Creating Ngrok service..."
    tee "/etc/systemd/system/${SERVICE_NAME}-ngrok.service" > /dev/null <<EOF
[Unit]
Description=Ngrok Tunnel for Noctis Pro PACS
After=network.target ${SERVICE_NAME}.service
Wants=${SERVICE_NAME}.service

[Service]
Type=simple
User=$NOCTIS_USER
Group=$NOCTIS_USER
WorkingDirectory=/home/$NOCTIS_USER
ExecStart=/usr/local/bin/ngrok start noctispro --config /home/$NOCTIS_USER/.ngrok2/ngrok.yml --log stdout
StandardOutput=append:$NOCTIS_DIR/logs/ngrok.log
StandardError=append:$NOCTIS_DIR/logs/ngrok.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Create backup service
    print_step "Creating backup service..."
    tee "/etc/systemd/system/${SERVICE_NAME}-backup.service" > /dev/null <<EOF
[Unit]
Description=Noctis Pro PACS Database Backup
Wants=${SERVICE_NAME}-backup.timer

[Service]
Type=oneshot
User=$NOCTIS_USER
Group=$NOCTIS_USER
WorkingDirectory=$NOCTIS_DIR
ExecStart=/bin/bash -c 'pg_dump -h localhost -U noctis_user noctispro | gzip > $NOCTIS_DIR/backups/backup_\$(date +%%Y%%m%%d_%%H%%M%%S).sql.gz'
Environment=PGPASSWORD=$DB_PASSWORD
EOF
    
    tee "/etc/systemd/system/${SERVICE_NAME}-backup.timer" > /dev/null <<EOF
[Unit]
Description=Run Noctis Pro PACS backup daily
Requires=${SERVICE_NAME}-backup.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Systemd services created"
}

configure_nginx() {
    print_header "🌐 NGINX CONFIGURATION"
    
    print_step "Configuring Nginx as reverse proxy..."
    
    tee "/etc/nginx/sites-available/noctispro" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME localhost;
    
    client_max_body_size 5G;
    
    # Static files
    location /static/ {
        alias $NOCTIS_DIR/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files
    location /media/ {
        alias $NOCTIS_DIR/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
    
    # Main application
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
    
    # Health check
    location /health/ {
        access_log off;
        return 200 "healthy";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    nginx -t
    
    print_success "Nginx configuration completed"
}

start_services() {
    print_header "🚀 STARTING SERVICES"
    
    print_step "Starting and enabling services..."
    
    # Start PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Start Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Start Noctis Pro
    systemctl start "$SERVICE_NAME"
    systemctl enable "$SERVICE_NAME"
    
    # Start Ngrok
    systemctl start "${SERVICE_NAME}-ngrok"
    systemctl enable "${SERVICE_NAME}-ngrok"
    
    # Enable backup timer
    systemctl enable "${SERVICE_NAME}-backup.timer"
    systemctl start "${SERVICE_NAME}-backup.timer"
    
    print_success "All services started successfully"
}

final_configuration() {
    print_header "🔧 FINAL CONFIGURATION"
    
    print_step "Configuring firewall..."
    ufw --force enable
    ufw allow ssh
    ufw allow 80
    ufw allow 443
    
    print_step "Setting up log rotation..."
    tee "/etc/logrotate.d/noctispro" > /dev/null <<EOF
$NOCTIS_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $NOCTIS_USER $NOCTIS_USER
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
EOF
    
    print_step "Creating management scripts..."
    
    # Create status script
    tee "$NOCTIS_DIR/status.sh" > /dev/null <<'EOF'
#!/bin/bash
echo "=== Noctis Pro PACS Status ==="
echo ""
echo "Services:"
systemctl status noctispro --no-pager -l
echo ""
systemctl status noctispro-ngrok --no-pager -l
echo ""
echo "Ngrok URL:"
curl -s http://127.0.0.1:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(f'Public URL: {tunnel[\"public_url\"]}')
            break
except:
    print('Ngrok not running or no tunnels active')
"
echo ""
echo "Recent logs:"
tail -n 5 $NOCTIS_DIR/logs/error.log
EOF
    
    chmod +x "$NOCTIS_DIR/status.sh"
    chown "$NOCTIS_USER:$NOCTIS_USER" "$NOCTIS_DIR/status.sh"
    
    print_success "Final configuration completed"
}

display_completion_info() {
    print_header "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    
    # Wait a moment for ngrok to start
    print_step "Getting ngrok URL..."
    sleep 10
    
    # Get the ngrok URL
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
    
    echo ""
    echo "🏥 NOCTIS PRO PACS is now running!"
    echo ""
    echo "📊 System Information:"
    echo "   • Installation Directory: $NOCTIS_DIR"
    echo "   • System User: $NOCTIS_USER"
    echo "   • Database: PostgreSQL (noctispro)"
    echo "   • Python Environment: $VENV_DIR"
    echo ""
    echo "🌐 Access URLs:"
    if [ -n "$NGROK_URL" ]; then
        echo "   • Public URL: $NGROK_URL"
    elif [ -n "$NGROK_STATIC_URL" ]; then
        echo "   • Static URL: $NGROK_STATIC_URL"
    else
        echo "   • Ngrok URL: Check logs or run status script"
    fi
    echo "   • Local URL: http://localhost"
    echo "   • Admin Panel: /admin/"
    echo ""
    echo "👥 User Roles:"
    echo "   • Administrator: Full system access"
    echo "   • Radiologist: Report writing, study management"
    echo "   • Facility User: Facility-specific access"
    echo ""
    echo "🔧 Management Commands:"
    echo "   • Check status: $NOCTIS_DIR/status.sh"
    echo "   • View logs: journalctl -u $SERVICE_NAME -f"
    echo "   • Restart service: sudo systemctl restart $SERVICE_NAME"
    echo "   • Restart ngrok: sudo systemctl restart ${SERVICE_NAME}-ngrok"
    echo ""
    echo "📁 Important Directories:"
    echo "   • Application: $NOCTIS_DIR/app/"
    echo "   • Logs: $NOCTIS_DIR/logs/"
    echo "   • Media files: $NOCTIS_DIR/media/"
    echo "   • Backups: $NOCTIS_DIR/backups/"
    echo ""
    echo "🔒 Security Notes:"
    echo "   • Change default passwords immediately"
    echo "   • Configure SSL certificates for production"
    echo "   • Review firewall settings"
    echo "   • Monitor system logs regularly"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Access the system using the URL above"
    echo "   2. Login with the administrator account you created"
    echo "   3. Create radiologist and facility user accounts"
    echo "   4. Configure facilities and modalities"
    echo "   5. Test DICOM upload and reporting workflow"
    echo ""
    
    if [ -n "$NGROK_STATIC_URL" ]; then
        echo "✅ Static URL configured: $NGROK_STATIC_URL"
    else
        echo "💡 To upgrade to a static URL:"
        echo "   1. Subscribe to ngrok paid plan"
        echo "   2. Update ngrok configuration"
        echo "   3. Restart ngrok service"
    fi
    
    echo ""
    print_success "Noctis Pro PACS deployment completed successfully!"
    echo ""
    echo "For support and documentation, visit: https://github.com/your-repo/noctis-pro"
}

# Run main function
main "$@"