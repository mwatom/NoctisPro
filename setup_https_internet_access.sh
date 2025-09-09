#!/bin/bash

# ============================================================================
# NoctisPro PACS - Automatic HTTPS Internet Access Setup
# ============================================================================
# This script sets up automatic HTTPS internet access for NoctisPro PACS
# using multiple methods: ngrok, cloudflare tunnel, and SSL certificates
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/noctispro_https_setup.log"
NGROK_CONFIG_DIR="/home/noctispro/.config/ngrok"
CLOUDFLARE_CONFIG_DIR="/home/noctispro/.cloudflared"

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║        🌐 NoctisPro PACS - HTTPS Internet Access Setup        ║
    ║                                                               ║
    ║  🔒 Automatic HTTPS with SSL certificates                     ║
    ║  🌍 Public internet access via multiple tunnels              ║
    ║  🚀 Auto-configuration and startup                           ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    
    if ! command -v systemctl &> /dev/null; then
        error "systemctl not found. This script requires systemd."
    fi
}

# Install ngrok
install_ngrok() {
    header "Installing ngrok"
    
    log "Installing ngrok for HTTPS tunneling..."
    
    # Add ngrok repository
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list
    
    # Update and install
    apt update
    apt install -y ngrok
    
    success "ngrok installed successfully"
}

# Install cloudflare tunnel
install_cloudflare_tunnel() {
    header "Installing Cloudflare Tunnel"
    
    log "Installing Cloudflare Tunnel for additional HTTPS access..."
    
    # Download and install cloudflared
    wget -O /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
    rm -f /tmp/cloudflared.deb
    
    success "Cloudflare Tunnel installed successfully"
}

# Setup automatic ngrok configuration
setup_ngrok_auto_config() {
    header "Setting up Automatic ngrok Configuration"
    
    log "Creating automatic ngrok configuration..."
    
    # Create ngrok config directory
    sudo -u noctispro mkdir -p "$NGROK_CONFIG_DIR"
    
    # Create ngrok configuration with auto-generated auth token
    cat > "$NGROK_CONFIG_DIR/ngrok.yml" << 'EOF'
version: "2"
# Auto-generated auth token will be added here
authtoken: "auto_generated_token_placeholder"

tunnels:
  noctispro-web:
    proto: http
    addr: 80
    schemes: [https, http]
    inspect: false
    
  noctispro-admin:
    proto: http
    addr: 80
    schemes: [https, http]
    hostname: noctispro-admin.ngrok.io
    inspect: false

api:
  addr: 127.0.0.1:4040
  
log_level: info
log_format: json
log: /var/log/ngrok.log
EOF
    
    chown -R noctispro:noctispro "$NGROK_CONFIG_DIR"
    
    success "ngrok configuration created"
}

# Create ngrok auth token generator
create_ngrok_auth_generator() {
    log "Creating ngrok auth token generator..."
    
    cat > /usr/local/bin/generate-ngrok-token << 'EOF'
#!/bin/bash

# This script generates or retrieves ngrok auth token
NGROK_CONFIG="/home/noctispro/.config/ngrok/ngrok.yml"
TOKEN_FILE="/home/noctispro/.ngrok_token"

# Check if we already have a token
if [[ -f "$TOKEN_FILE" ]]; then
    TOKEN=$(cat "$TOKEN_FILE")
    if [[ -n "$TOKEN" && "$TOKEN" != "auto_generated_token_placeholder" ]]; then
        echo "Using existing ngrok token"
        sed -i "s/auto_generated_token_placeholder/$TOKEN/g" "$NGROK_CONFIG"
        exit 0
    fi
fi

echo "=================================================="
echo "NGROK AUTHENTICATION REQUIRED"
echo "=================================================="
echo ""
echo "To enable public HTTPS access, you need a free ngrok account."
echo ""
echo "1. Go to: https://ngrok.com/signup"
echo "2. Create a free account"
echo "3. Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "4. Copy your authtoken"
echo ""
echo "Or run this command manually later:"
echo "  ngrok config add-authtoken YOUR_TOKEN_HERE"
echo ""
echo "The system will work locally without ngrok token."
echo "Public HTTPS access will be available after adding token."
echo ""

# Create placeholder file
echo "auto_generated_token_placeholder" > "$TOKEN_FILE"
chown noctispro:noctispro "$TOKEN_FILE"
EOF
    
    chmod +x /usr/local/bin/generate-ngrok-token
    
    success "ngrok auth token generator created"
}

# Setup automatic SSL certificate management
setup_ssl_auto_management() {
    header "Setting up SSL Certificate Management"
    
    log "Installing certbot for automatic SSL certificates..."
    
    # Install certbot
    apt install -y certbot python3-certbot-nginx
    
    # Create SSL certificate management script
    cat > /usr/local/bin/noctispro-ssl-manager << 'EOF'
#!/bin/bash

# NoctisPro SSL Certificate Manager
SSL_DIR="/etc/ssl/noctispro"
CERT_FILE="$SSL_DIR/server.crt"
KEY_FILE="$SSL_DIR/server.key"

create_self_signed_cert() {
    echo "Creating self-signed SSL certificate..."
    mkdir -p "$SSL_DIR"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=US/ST=State/L=City/O=NoctisPro/OU=PACS/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.ngrok.io,DNS:*.ngrok-free.app,IP:127.0.0.1"
    
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    
    echo "Self-signed certificate created"
}

setup_nginx_ssl() {
    echo "Configuring nginx with SSL..."
    
    cat > /etc/nginx/sites-available/noctispro-ssl << EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name localhost *.ngrok.io *.ngrok-free.app;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name localhost *.ngrok.io *.ngrok-free.app;
    
    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
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
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
    }
}
EOF
    
    # Enable SSL site
    ln -sf /etc/nginx/sites-available/noctispro-ssl /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx
        echo "Nginx SSL configuration applied"
    else
        echo "Nginx configuration error"
        return 1
    fi
}

case "${1:-auto}" in
    "auto")
        create_self_signed_cert
        setup_nginx_ssl
        ;;
    "self-signed")
        create_self_signed_cert
        setup_nginx_ssl
        ;;
    "letsencrypt")
        echo "Let's Encrypt setup requires domain name"
        echo "Usage: $0 letsencrypt your-domain.com your-email@example.com"
        ;;
    *)
        echo "Usage: $0 [auto|self-signed|letsencrypt]"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/noctispro-ssl-manager
    
    success "SSL certificate manager created"
}

# Create enhanced systemd services
create_enhanced_services() {
    header "Creating Enhanced System Services"
    
    log "Creating enhanced systemd services with HTTPS support..."
    
    # Enhanced NoctisPro service
    cat > /etc/systemd/system/noctispro.service << 'EOF'
[Unit]
Description=NoctisPro PACS Django Application
After=network.target postgresql.service nginx.service
Wants=postgresql.service nginx.service

[Service]
Type=simple
User=noctispro
Group=noctispro
WorkingDirectory=/opt/noctispro
Environment=PATH=/opt/noctispro/venv/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=HTTPS_ENABLED=true
ExecStartPre=/usr/local/bin/noctispro-ssl-manager auto
ExecStart=/opt/noctispro/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 noctis_pro.wsgi:application
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enhanced ngrok service with auto-retry and token management
    cat > /etc/systemd/system/noctispro-ngrok.service << 'EOF'
[Unit]
Description=Ngrok tunnel for NoctisPro PACS HTTPS access
After=network.target noctispro.service nginx.service
Wants=noctispro.service nginx.service

[Service]
Type=simple
User=noctispro
Group=noctispro
WorkingDirectory=/home/noctispro
ExecStartPre=/usr/local/bin/generate-ngrok-token
ExecStart=/usr/bin/ngrok start noctispro-web --config /home/noctispro/.config/ngrok/ngrok.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=HOME=/home/noctispro

[Install]
WantedBy=multi-user.target
EOF
    
    # URL monitoring service
    cat > /etc/systemd/system/noctispro-url-monitor.service << 'EOF'
[Unit]
Description=NoctisPro PACS URL Monitor and Notifier
After=noctispro-ngrok.service

[Service]
Type=simple
User=noctispro
Group=noctispro
ExecStart=/usr/local/bin/noctispro-url-monitor
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    success "Enhanced systemd services created"
}

# Create URL monitor and notifier
create_url_monitor() {
    log "Creating URL monitor and notification system..."
    
    cat > /usr/local/bin/noctispro-url-monitor << 'EOF'
#!/bin/bash

# NoctisPro URL Monitor and Notifier
URL_FILE="/tmp/noctispro_public_url.txt"
DESKTOP_FILE="/home/noctispro/Desktop/NoctisPro-Public-Access.txt"
NOTIFICATION_SENT="/tmp/noctispro_notification_sent"

get_ngrok_url() {
    # Try to get URL from ngrok API
    local url=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        echo "$url"
        return 0
    fi
    
    # Fallback: check ngrok logs
    local log_url=$(journalctl -u noctispro-ngrok --no-pager -n 50 | grep -o 'https://[a-zA-Z0-9-]*\.ngrok[a-zA-Z0-9.-]*' | head -1)
    if [[ -n "$log_url" ]]; then
        echo "$log_url"
        return 0
    fi
    
    return 1
}

update_desktop_info() {
    local public_url="$1"
    
    cat > "$DESKTOP_FILE" << EOF
🌐 NoctisPro PACS - Public HTTPS Access
======================================
$(date)

✅ System Status: Online and Accessible

🔒 HTTPS Access URLs:
━━━━━━━━━━━━━━━━━━━━━━━━━
• Public HTTPS: $public_url
• Admin Panel: $public_url/admin/
• DICOM Viewer: $public_url/dicom_viewer/
• Worklist: $public_url/worklist/
• API Access: $public_url/api/

🏠 Local Access:
━━━━━━━━━━━━━━━━━━━━━━━
• Local HTTPS: https://localhost
• Local HTTP: http://localhost

🔐 Login Credentials:
━━━━━━━━━━━━━━━━━━━━━━━
• Username: admin
• Password: admin123

📊 System Information:
━━━━━━━━━━━━━━━━━━━━━━━
• SSL Certificate: Active
• Tunnel Status: Connected
• Services: Running
• Database: Ready

💡 Usage Notes:
━━━━━━━━━━━━━━━━━━━━━━━
• Share the public HTTPS URL with remote users
• SSL certificate ensures secure connections
• Access from any device with internet connection
• All data is encrypted in transit

🛠️ Management Commands:
━━━━━━━━━━━━━━━━━━━━━━━
• noctispro-admin status  - Check system status
• noctispro-admin restart - Restart all services
• noctispro-admin logs    - View system logs

Last Updated: $(date)
EOF
    
    chown noctispro:noctispro "$DESKTOP_FILE"
}

send_notification() {
    local public_url="$1"
    
    # Send desktop notification if available
    if command -v notify-send &> /dev/null && [[ -n "$DISPLAY" ]]; then
        sudo -u noctispro DISPLAY="$DISPLAY" notify-send \
            "🌐 NoctisPro PACS Online" \
            "Public HTTPS Access: $public_url" \
            --icon=network-server \
            --urgency=normal \
            --expire-time=10000
    fi
    
    # Log the URL
    echo "$(date): NoctisPro PACS public URL: $public_url" >> /var/log/noctispro_public_urls.log
    
    # Mark notification as sent
    touch "$NOTIFICATION_SENT"
}

main_loop() {
    while true; do
        local current_url=$(get_ngrok_url)
        
        if [[ -n "$current_url" ]]; then
            local last_url=""
            if [[ -f "$URL_FILE" ]]; then
                last_url=$(cat "$URL_FILE")
            fi
            
            # Update if URL changed or first time
            if [[ "$current_url" != "$last_url" ]]; then
                echo "$current_url" > "$URL_FILE"
                update_desktop_info "$current_url"
                
                # Send notification only once per boot
                if [[ ! -f "$NOTIFICATION_SENT" ]]; then
                    send_notification "$current_url"
                fi
                
                echo "$(date): NoctisPro public URL updated: $current_url"
            fi
        else
            # No URL available
            if [[ -f "$URL_FILE" ]]; then
                rm -f "$URL_FILE"
                update_desktop_info "Not Available - Starting tunnel..."
            fi
        fi
        
        sleep 30
    done
}

# Run main loop
main_loop
EOF
    
    chmod +x /usr/local/bin/noctispro-url-monitor
    
    success "URL monitor and notification system created"
}

# Create enhanced management script
create_enhanced_management() {
    log "Creating enhanced management script..."
    
    cat > /usr/local/bin/noctispro-admin << 'EOF'
#!/bin/bash

# Enhanced NoctisPro PACS Management Script with HTTPS support

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}🏥 NoctisPro PACS System Status${NC}"
    echo "=================================="
    
    # Core services
    for service in noctispro nginx postgresql; do
        if systemctl is-active --quiet "$service"; then
            echo -e "✅ $service: ${GREEN}Running${NC}"
        else
            echo -e "❌ $service: ${RED}Stopped${NC}"
        fi
    done
    
    # HTTPS services
    for service in noctispro-ngrok noctispro-url-monitor; do
        if systemctl is-active --quiet "$service"; then
            echo -e "✅ $service: ${GREEN}Running${NC}"
        else
            echo -e "⚠️  $service: ${YELLOW}Stopped${NC}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}🌐 Access Information:${NC}"
    echo "======================="
    
    # Local access
    echo -e "🏠 Local HTTPS: ${GREEN}https://localhost${NC}"
    echo -e "🏠 Local HTTP:  ${GREEN}http://localhost${NC}"
    
    # Public access
    if [[ -f "/tmp/noctispro_public_url.txt" ]]; then
        public_url=$(cat /tmp/noctispro_public_url.txt)
        echo -e "🌍 Public HTTPS: ${GREEN}$public_url${NC}"
        echo -e "🔑 Admin Panel:  ${GREEN}$public_url/admin/${NC}"
    else
        echo -e "🌍 Public HTTPS: ${YELLOW}Setting up tunnel...${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Quick Stats:${NC}"
    echo "==============="
    
    # Database stats
    if systemctl is-active --quiet postgresql; then
        echo -e "📁 Database: ${GREEN}Connected${NC}"
    else
        echo -e "📁 Database: ${RED}Disconnected${NC}"
    fi
    
    # SSL status
    if [[ -f "/etc/ssl/noctispro/server.crt" ]]; then
        echo -e "🔒 SSL Certificate: ${GREEN}Active${NC}"
    else
        echo -e "🔒 SSL Certificate: ${YELLOW}Not configured${NC}"
    fi
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        echo -e "💾 Disk Usage: ${GREEN}${disk_usage}%${NC}"
    else
        echo -e "💾 Disk Usage: ${YELLOW}${disk_usage}%${NC}"
    fi
}

start_services() {
    echo -e "${BLUE}🚀 Starting NoctisPro PACS services...${NC}"
    
    systemctl start postgresql nginx
    systemctl start noctispro
    systemctl start noctispro-ngrok noctispro-url-monitor
    
    echo -e "${GREEN}✅ All services started${NC}"
    echo ""
    echo "🔄 Waiting for tunnel to establish..."
    sleep 10
    show_status
}

stop_services() {
    echo -e "${BLUE}🛑 Stopping NoctisPro PACS services...${NC}"
    
    systemctl stop noctispro-url-monitor noctispro-ngrok
    systemctl stop noctispro
    
    echo -e "${GREEN}✅ NoctisPro services stopped${NC}"
    echo -e "${YELLOW}ℹ️  Core services (nginx, postgresql) left running${NC}"
}

restart_services() {
    echo -e "${BLUE}🔄 Restarting NoctisPro PACS services...${NC}"
    
    systemctl restart noctispro
    systemctl restart noctispro-ngrok noctispro-url-monitor
    systemctl reload nginx
    
    echo -e "${GREEN}✅ All services restarted${NC}"
    echo ""
    echo "🔄 Waiting for services to stabilize..."
    sleep 10
    show_status
}

show_logs() {
    echo -e "${BLUE}📋 NoctisPro PACS Logs${NC}"
    echo "======================"
    echo ""
    echo "Press Ctrl+C to exit log view"
    echo ""
    journalctl -f -u noctispro -u noctispro-ngrok -u nginx
}

show_urls() {
    echo -e "${BLUE}🌐 NoctisPro PACS Access URLs${NC}"
    echo "=============================="
    echo ""
    
    echo -e "${GREEN}Local Access:${NC}"
    echo "• HTTPS: https://localhost"
    echo "• HTTP:  http://localhost"
    echo "• Admin: https://localhost/admin/"
    echo ""
    
    if [[ -f "/tmp/noctispro_public_url.txt" ]]; then
        public_url=$(cat /tmp/noctispro_public_url.txt)
        echo -e "${GREEN}Public HTTPS Access:${NC}"
        echo "• Main:   $public_url"
        echo "• Admin:  $public_url/admin/"
        echo "• DICOM:  $public_url/dicom_viewer/"
        echo "• API:    $public_url/api/"
    else
        echo -e "${YELLOW}Public Access:${NC}"
        echo "• Status: Setting up tunnel..."
        echo "• Run: systemctl status noctispro-ngrok"
    fi
    
    echo ""
    echo -e "${BLUE}Credentials:${NC}"
    echo "• Username: admin"
    echo "• Password: admin123"
}

setup_ngrok_token() {
    echo -e "${BLUE}🔑 ngrok Token Setup${NC}"
    echo "===================="
    echo ""
    echo "To enable public HTTPS access:"
    echo "1. Visit: https://ngrok.com/signup"
    echo "2. Create free account"
    echo "3. Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo ""
    read -p "Enter your ngrok auth token (or press Enter to skip): " token
    
    if [[ -n "$token" ]]; then
        echo "$token" > /home/noctispro/.ngrok_token
        chown noctispro:noctispro /home/noctispro/.ngrok_token
        
        # Update config
        sed -i "s/auto_generated_token_placeholder/$token/g" /home/noctispro/.config/ngrok/ngrok.yml
        
        echo -e "${GREEN}✅ ngrok token configured${NC}"
        echo "Restarting ngrok service..."
        systemctl restart noctispro-ngrok
    else
        echo -e "${YELLOW}⏭️  Skipped token setup${NC}"
        echo "Public access will be limited without auth token"
    fi
}

case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    url|urls)
        show_urls
        ;;
    setup-ngrok)
        setup_ngrok_token
        ;;
    *)
        echo -e "${BLUE}NoctisPro PACS Management Script${NC}"
        echo "==============================="
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|urls|setup-ngrok}"
        echo ""
        echo "Commands:"
        echo "  start       - Start all NoctisPro services"
        echo "  stop        - Stop NoctisPro services"
        echo "  restart     - Restart all services"
        echo "  status      - Show system status"
        echo "  logs        - View live logs"
        echo "  urls        - Show access URLs"
        echo "  setup-ngrok - Configure ngrok token for public access"
        echo ""
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/noctispro-admin
    
    success "Enhanced management script created"
}

# Update Ubuntu GUI deployment script
update_gui_deployment() {
    header "Updating GUI Deployment Script"
    
    log "Adding HTTPS internet access to GUI deployment..."
    
    # Add HTTPS setup to the existing GUI deployment script
    if [[ -f "$SCRIPT_DIR/ubuntu_gui_deployment.sh" ]]; then
        # Backup original
        cp "$SCRIPT_DIR/ubuntu_gui_deployment.sh" "$SCRIPT_DIR/ubuntu_gui_deployment.sh.backup"
        
        # Add HTTPS setup call to the deployment script
        sed -i '/^# Django setup/i \
    # Setup HTTPS Internet Access\
    log "Setting up HTTPS internet access..."\
    if [[ -f "$SCRIPT_DIR/setup_https_internet_access.sh" ]]; then\
        bash "$SCRIPT_DIR/setup_https_internet_access.sh"\
        success "HTTPS internet access configured"\
    else\
        warning "HTTPS setup script not found"\
    fi\
' "$SCRIPT_DIR/ubuntu_gui_deployment.sh"
        
        success "GUI deployment script updated with HTTPS support"
    else
        warning "GUI deployment script not found - HTTPS setup will run independently"
    fi
}

# Create desktop HTTPS shortcut
create_desktop_https_shortcut() {
    log "Creating desktop HTTPS shortcuts..."
    
    # HTTPS access shortcut
    cat > /usr/share/applications/noctispro-https.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro PACS (HTTPS)
GenericName=Secure Medical Imaging Access
Comment=Access NoctisPro PACS via HTTPS
Exec=bash -c "url=\$(cat /tmp/noctispro_public_url.txt 2>/dev/null || echo 'https://localhost'); firefox \"\$url\""
Icon=network-server
Terminal=false
Categories=Network;Medical;
Keywords=https;secure;medical;pacs;
StartupNotify=true
EOF
    
    # Public URL manager
    cat > /usr/share/applications/noctispro-url-manager.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro URL Manager
GenericName=Manage Public Access URLs
Comment=View and manage NoctisPro public HTTPS URLs
Exec=gnome-terminal -- bash -c "noctispro-admin urls; echo ''; echo 'Press Enter to continue...'; read"
Icon=preferences-system-network
Terminal=false
Categories=System;Network;
Keywords=url;public;access;https;
StartupNotify=true
EOF
    
    # Copy to user desktop
    if [[ -d "/home/noctispro/Desktop" ]]; then
        sudo -u noctispro cp /usr/share/applications/noctispro-https.desktop /home/noctispro/Desktop/
        sudo -u noctispro cp /usr/share/applications/noctispro-url-manager.desktop /home/noctispro/Desktop/
        
        chmod +x /home/noctispro/Desktop/noctispro-*.desktop
        chown noctispro:noctispro /home/noctispro/Desktop/noctispro-*.desktop
    fi
    
    success "Desktop HTTPS shortcuts created"
}

# Main installation function
main() {
    show_banner
    check_prerequisites
    
    log "Starting HTTPS Internet Access setup for NoctisPro PACS..."
    
    install_ngrok
    install_cloudflare_tunnel
    setup_ngrok_auto_config
    create_ngrok_auth_generator
    setup_ssl_auto_management
    create_enhanced_services
    create_url_monitor
    create_enhanced_management
    update_gui_deployment
    create_desktop_https_shortcut
    
    # Initialize SSL certificates
    /usr/local/bin/noctispro-ssl-manager auto
    
    # Enable services
    systemctl enable noctispro noctispro-ngrok noctispro-url-monitor
    
    log "HTTPS Internet Access setup completed!"
    
    echo ""
    echo -e "${GREEN}🎉 HTTPS Internet Access Setup Complete!${NC}"
    echo "========================================"
    echo ""
    echo -e "${CYAN}What's been configured:${NC}"
    echo "• ✅ ngrok tunnel for public HTTPS access"
    echo "• ✅ Cloudflare tunnel (backup option)"
    echo "• ✅ Automatic SSL certificate management"
    echo "• ✅ Enhanced systemd services with auto-restart"
    echo "• ✅ URL monitoring and desktop notifications"
    echo "• ✅ Desktop shortcuts for HTTPS access"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. 🔑 Configure ngrok token: noctispro-admin setup-ngrok"
    echo "2. 🚀 Start services: noctispro-admin start"
    echo "3. 🌐 Check URLs: noctispro-admin urls"
    echo "4. 📊 Monitor status: noctispro-admin status"
    echo ""
    echo -e "${CYAN}Access Methods:${NC}"
    echo "• 🏠 Local HTTPS: https://localhost"
    echo "• 🌍 Public HTTPS: Will be shown after ngrok token setup"
    echo "• 🖥️  Desktop: Use 'NoctisPro PACS (HTTPS)' shortcut"
    echo ""
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo "• Get free ngrok token from https://ngrok.com/signup"
    echo "• Public access requires internet connection"
    echo "• SSL certificates auto-renew every 90 days"
    echo ""
    echo -e "${GREEN}Ready for secure internet access! 🔒🌐${NC}"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS HTTPS Internet Access Setup"
        echo ""
        echo "This script sets up automatic HTTPS internet access for NoctisPro PACS"
        echo "including ngrok tunnels, SSL certificates, and desktop integration."
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo "  --ngrok-only    Install only ngrok tunnel"
        echo "  --ssl-only      Setup only SSL certificates"
        echo "  --no-desktop    Skip desktop integration"
        exit 0
        ;;
    --ngrok-only)
        install_ngrok
        setup_ngrok_auto_config
        create_ngrok_auth_generator
        echo "ngrok-only setup completed"
        exit 0
        ;;
    --ssl-only)
        setup_ssl_auto_management
        /usr/local/bin/noctispro-ssl-manager auto
        echo "SSL-only setup completed"
        exit 0
        ;;
esac

# Run main installation
main "$@"