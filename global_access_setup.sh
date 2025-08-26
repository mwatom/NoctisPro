#!/bin/bash

# Global Access Setup for NoctisPro - Make Your System Accessible Anywhere
# This script configures your Ubuntu Desktop to be accessible from anywhere in the world

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

echo "=============================================================="
echo "   🌐 GLOBAL ACCESS SETUP FOR NOCTISPRO"
echo "   Make Your System Accessible From Anywhere in the World"
echo "=============================================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "Please run this script as regular user, not root"
   log_error "Use: ./global_access_setup.sh"
   exit 1
fi

# Get current system info
PUBLIC_IP=""
LOCAL_IP=$(hostname -I | awk '{print $1}')
CURRENT_USER=$(whoami)

log_step "1. Detecting your current network configuration..."

# Get public IP
log_info "Detecting your public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || curl -s ipecho.net/plain 2>/dev/null)

if [ -z "$PUBLIC_IP" ]; then
    log_error "Could not detect public IP address"
    log_error "Please check your internet connection and try again"
    exit 1
fi

log_success "Public IP detected: $PUBLIC_IP"
log_info "Local IP: $LOCAL_IP"
log_info "Current user: $CURRENT_USER"

echo ""
log_step "2. Choose your domain option..."

echo "Choose how you want to access your system globally:"
echo ""
echo "1) 🆓 FREE SUBDOMAIN (Recommended for testing)"
echo "   - Get: yourname.duckdns.org"
echo "   - Automatically updates IP"
echo "   - Ready in 5 minutes"
echo ""
echo "2) 🆓 NO-IP FREE SUBDOMAIN"
echo "   - Get: yourname.hopto.org"
echo "   - Manual IP updates"
echo "   - More domain options"
echo ""
echo "3) 💰 CUSTOM DOMAIN (Professional)"
echo "   - Use your own domain: yourcompany.com"
echo "   - Requires domain purchase"
echo "   - Most professional option"
echo ""
echo "4) 🔗 NGROK TUNNEL (Temporary testing)"
echo "   - Instant access"
echo "   - Temporary URLs"
echo "   - Great for testing"
echo ""

read -p "Enter your choice (1-4): " domain_choice

case $domain_choice in
    1)
        setup_duckdns
        ;;
    2)
        setup_noip
        ;;
    3)
        setup_custom_domain
        ;;
    4)
        setup_ngrok
        ;;
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

# Function to setup DuckDNS (Free and automatic)
setup_duckdns() {
    log_step "3. Setting up DuckDNS (Free Dynamic DNS)..."
    
    echo ""
    log_info "DuckDNS provides free subdomains with automatic IP updates"
    echo ""
    echo "📋 Instructions:"
    echo "1. Go to https://www.duckdns.org"
    echo "2. Sign in with Google/GitHub/Twitter"
    echo "3. Create a subdomain (e.g., 'noctispro' → noctispro.duckdns.org)"
    echo "4. Copy your token from the dashboard"
    echo ""
    
    read -p "Enter your DuckDNS subdomain name (without .duckdns.org): " subdomain
    read -p "Enter your DuckDNS token: " token
    
    DOMAIN_NAME="${subdomain}.duckdns.org"
    
    # Test DuckDNS update
    log_info "Testing DuckDNS configuration..."
    curl_result=$(curl -s "https://www.duckdns.org/update?domains=${subdomain}&token=${token}&ip=${PUBLIC_IP}")
    
    if [[ "$curl_result" == "OK" ]]; then
        log_success "DuckDNS configuration successful!"
        log_success "Your domain: https://${DOMAIN_NAME}"
    else
        log_error "DuckDNS configuration failed. Please check your subdomain and token."
        exit 1
    fi
    
    # Setup automatic IP updates
    log_info "Setting up automatic IP updates..."
    
    # Create update script
    cat > /tmp/duckdns_update.sh << EOF
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=${subdomain}&token=${token}&ip=" | curl -k -o /tmp/duck.log -K -
EOF
    
    chmod +x /tmp/duckdns_update.sh
    sudo mv /tmp/duckdns_update.sh /usr/local/bin/
    
    # Add to crontab for automatic updates every 5 minutes
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/duckdns_update.sh >/dev/null 2>&1") | crontab -
    
    log_success "Automatic IP updates configured (every 5 minutes)"
    
    configure_system_for_domain "$DOMAIN_NAME"
}

# Function to setup No-IP
setup_noip() {
    log_step "3. Setting up No-IP (Free Dynamic DNS)..."
    
    echo ""
    log_info "No-IP provides free subdomains with various options"
    echo ""
    echo "📋 Instructions:"
    echo "1. Go to https://www.noip.com"
    echo "2. Create a free account"
    echo "3. Create a hostname (e.g., noctispro.hopto.org)"
    echo "4. Note your login credentials"
    echo ""
    
    read -p "Enter your No-IP hostname (e.g., noctispro.hopto.org): " noip_hostname
    read -p "Enter your No-IP username: " noip_username
    read -s -p "Enter your No-IP password: " noip_password
    echo ""
    
    DOMAIN_NAME="$noip_hostname"
    
    # Install No-IP client
    log_info "Installing No-IP dynamic update client..."
    
    # Download and compile No-IP client
    cd /tmp
    wget -q https://www.noip.com/client/linux/noip-duc-linux.tar.gz
    tar xzf noip-duc-linux.tar.gz
    cd noip-2.1.9-1/
    make
    sudo mv noip2 /usr/local/bin/
    
    # Configure No-IP client
    log_info "Configuring No-IP client..."
    sudo /usr/local/bin/noip2 -C -u "$noip_username" -p "$noip_password"
    
    # Create systemd service
    sudo tee /etc/systemd/system/noip.service > /dev/null << EOF
[Unit]
Description=No-IP Dynamic DNS Update Client
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/noip2
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl enable noip
    sudo systemctl start noip
    
    log_success "No-IP client configured and started"
    log_success "Your domain: https://${DOMAIN_NAME}"
    
    configure_system_for_domain "$DOMAIN_NAME"
}

# Function to setup custom domain
setup_custom_domain() {
    log_step "3. Setting up Custom Domain..."
    
    echo ""
    log_info "Using your own custom domain for professional deployment"
    echo ""
    echo "📋 Requirements:"
    echo "1. You must own a domain (purchased from registrar)"
    echo "2. Access to domain DNS settings"
    echo "3. Ability to create A records"
    echo ""
    
    read -p "Enter your custom domain (e.g., noctispro.yourcompany.com): " custom_domain
    
    DOMAIN_NAME="$custom_domain"
    
    echo ""
    log_warning "MANUAL DNS CONFIGURATION REQUIRED:"
    echo "=============================================="
    echo "1. Log into your domain registrar's control panel"
    echo "2. Go to DNS settings for your domain"
    echo "3. Create an A record:"
    echo "   - Name: $(echo $custom_domain | cut -d. -f1)"
    echo "   - Type: A"
    echo "   - Value: $PUBLIC_IP"
    echo "   - TTL: 300 (5 minutes)"
    echo ""
    echo "4. Optionally create CNAME for www:"
    echo "   - Name: www"
    echo "   - Type: CNAME"
    echo "   - Value: $custom_domain"
    echo "=============================================="
    echo ""
    
    read -p "Press Enter after you've configured the DNS settings..."
    
    # Test DNS propagation
    log_info "Testing DNS propagation..."
    for i in {1..5}; do
        resolved_ip=$(dig +short "$custom_domain" @8.8.8.8 2>/dev/null || echo "")
        if [ "$resolved_ip" = "$PUBLIC_IP" ]; then
            log_success "DNS propagation successful!"
            break
        else
            log_warning "DNS not propagated yet, waiting 30 seconds... (attempt $i/5)"
            if [ $i -eq 5 ]; then
                log_warning "DNS not fully propagated, but continuing. May take up to 24 hours."
            else
                sleep 30
            fi
        fi
    done
    
    configure_system_for_domain "$DOMAIN_NAME"
}

# Function to setup Ngrok tunnel
setup_ngrok() {
    log_step "3. Setting up Ngrok Tunnel (Temporary Access)..."
    
    echo ""
    log_info "Ngrok provides instant tunnels for testing"
    echo ""
    echo "📋 Instructions:"
    echo "1. Go to https://ngrok.com"
    echo "2. Sign up for a free account"
    echo "3. Get your authtoken from dashboard"
    echo ""
    
    read -p "Enter your Ngrok authtoken: " ngrok_token
    
    # Install ngrok
    log_info "Installing Ngrok..."
    
    # Download ngrok
    cd /tmp
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    sudo mv ngrok /usr/local/bin/
    
    # Configure ngrok
    ngrok config add-authtoken "$ngrok_token"
    
    log_success "Ngrok installed and configured"
    
    # We'll start ngrok after the main deployment
    DOMAIN_NAME="ngrok"  # Special marker
    configure_system_for_domain "$DOMAIN_NAME"
}

# Function to configure system for domain
configure_system_for_domain() {
    local domain="$1"
    
    log_step "4. Configuring system for global access..."
    
    # Install required packages
    log_info "Installing required packages..."
    sudo apt update
    sudo apt install -y nginx certbot python3-certbot-nginx ufw fail2ban
    
    # Configure firewall
    log_info "Configuring firewall for internet access..."
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    
    # Configure fail2ban
    log_info "Setting up intrusion prevention..."
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
EOF
    
    sudo systemctl restart fail2ban
    
    if [ "$domain" = "ngrok" ]; then
        setup_ngrok_deployment
    else
        setup_standard_deployment "$domain"
    fi
}

# Function for standard deployment with domain
setup_standard_deployment() {
    local domain="$1"
    
    log_step "5. Deploying NoctisPro for global access..."
    
    # Create internet production deployment script
    log_info "Preparing deployment script for internet access..."
    
    # Modify the existing deployment script
    cp deploy_noctis_production.sh deploy_internet_production.sh
    
    # Update configuration for internet deployment
    sed -i "s/DOMAIN_NAME=\"noctis-server.local\"/DOMAIN_NAME=\"$domain\"/" deploy_internet_production.sh
    sed -i "s/SERVER_IP=\"192.168.100.15\"/SERVER_IP=\"$PUBLIC_IP\"/" deploy_internet_production.sh
    
    # Add internet security configurations
    cat >> deploy_internet_production.sh << 'EOF'

# Additional security for internet deployment
configure_internet_security() {
    log_info "Applying additional security for internet exposure..."
    
    # Update Django settings for internet
    cat >> /opt/noctis_pro/.env << DJANGO_EOF
# Internet Security Settings
SECURE_SSL_REDIRECT=True
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_HSTS_SECONDS=31536000
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
X_FRAME_OPTIONS=DENY
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
DJANGO_EOF
    
    # Configure nginx for production security
    cat > /etc/nginx/sites-available/noctispro << NGINX_EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    # SSL certificates will be added by certbot
    
    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; media-src 'self'; object-src 'none'; child-src 'none'; frame-src 'none'; worker-src 'none'; frame-ancestors 'none'; form-action 'self'; base-uri 'self';" always;

    # File upload size for DICOM images
    client_max_body_size 2G;
    
    # Timeouts
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    proxy_buffering off;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Additional security headers for proxy
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header X-Forwarded-Port \$server_port;
    }

    location /static/ {
        alias /opt/noctis_pro/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff";
    }

    location /media/ {
        alias /opt/noctis_pro/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options "nosniff";
        
        # Additional security for media files
        location ~* \.(php|jsp|pl|py|asp|sh|cgi)$ {
            deny all;
        }
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ ^/(\.git|\.env|\.htaccess|\.htpasswd) {
        deny all;
    }
}
NGINX_EOF

    ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
}

# Call the internet security function
configure_internet_security
EOF
    
    # Make script executable
    chmod +x deploy_internet_production.sh
    
    log_info "Starting NoctisPro deployment..."
    sudo ./deploy_internet_production.sh
    
    # Setup SSL certificate
    if [ "$domain" != "ngrok" ]; then
        log_info "Setting up SSL certificate..."
        sudo certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos --email admin@"$domain"
        
        # Setup auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
    fi
    
    log_success "Deployment completed!"
    
    echo ""
    echo "🎉 SUCCESS! Your NoctisPro system is now accessible globally!"
    echo "=============================================================="
    echo "🌐 Access your system at: https://$domain"
    echo "👤 Admin login: Create account at first visit"
    echo "📱 Mobile access: Yes, responsive design"
    echo "🔒 Security: HTTPS enabled with security headers"
    echo "🛡️  Protection: Fail2ban active, firewall configured"
    echo "=============================================================="
}

# Function for Ngrok deployment
setup_ngrok_deployment() {
    log_step "5. Deploying NoctisPro with Ngrok tunnel..."
    
    # Deploy NoctisPro locally first
    log_info "Deploying NoctisPro locally..."
    sudo ./deploy_noctis_production.sh
    
    # Start ngrok tunnel
    log_info "Starting Ngrok tunnel..."
    
    # Create ngrok configuration
    cat > ~/.ngrok2/ngrok.yml << EOF
version: "2"
authtoken: $(ngrok config check | grep authtoken | cut -d' ' -f2)
tunnels:
  noctispro:
    addr: 8000
    proto: http
    bind_tls: true
    inspect: false
EOF
    
    # Start ngrok in background
    nohup ngrok start noctispro > /tmp/ngrok.log 2>&1 &
    
    # Wait for ngrok to start
    sleep 5
    
    # Get ngrok URL
    NGROK_URL=$(curl -s localhost:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    print('Error getting URL')
")
    
    if [ -n "$NGROK_URL" ]; then
        log_success "Ngrok tunnel active!"
        echo ""
        echo "🎉 SUCCESS! Your NoctisPro system is now accessible globally!"
        echo "=============================================================="
        echo "🌐 Access your system at: $NGROK_URL"
        echo "⚠️  NOTE: This is a temporary URL (changes on restart)"
        echo "👤 Admin login: Create account at first visit"
        echo "📱 Mobile access: Yes, responsive design"
        echo "🔒 Security: HTTPS enabled"
        echo "=============================================================="
        echo ""
        echo "🔄 To restart tunnel: ngrok start noctispro"
        echo "📊 Tunnel dashboard: http://localhost:4040"
    else
        log_error "Failed to get Ngrok URL. Check /tmp/ngrok.log for details"
    fi
}

# Main execution starts here
log_step "Starting global access setup..."

# Check internet connectivity
if ! ping -c 1 google.com &> /dev/null; then
    log_error "No internet connection detected. Please check your connection and try again."
    exit 1
fi

log_success "Internet connectivity confirmed"

# Check if NoctisPro files exist
if [ ! -f "deploy_noctis_production.sh" ]; then
    log_error "NoctisPro deployment script not found in current directory"
    log_error "Please run this script from the NoctisPro project directory"
    exit 1
fi

log_success "NoctisPro deployment script found"

# Show final instructions
show_final_instructions() {
    echo ""
    echo "🎯 NEXT STEPS:"
    echo "=============="
    echo "1. 🌐 Access your system from anywhere using the URL above"
    echo "2. 👤 Create your admin account on first visit"
    echo "3. 📋 Upload and test with DICOM images"
    echo "4. 🖨️  Configure printers for medical image printing"
    echo "5. 👥 Add users and configure permissions"
    echo ""
    echo "📚 USEFUL COMMANDS:"
    echo "==================="
    echo "• Check system status: sudo systemctl status noctis_pro"
    echo "• View logs: sudo journalctl -u noctis_pro -f"
    echo "• Restart service: sudo systemctl restart noctis_pro"
    echo "• Check SSL: curl -I https://yourdomain.com"
    echo ""
    echo "🛡️  SECURITY NOTES:"
    echo "==================="
    echo "• Firewall is active (UFW)"
    echo "• Fail2ban protects against brute force"
    echo "• HTTPS enforced with security headers"
    echo "• Regular backups recommended"
    echo ""
    echo "📞 SUPPORT:"
    echo "==========="
    echo "• System health check: /opt/noctis_pro/scripts/health_check.sh"
    echo "• Backup system: /opt/noctis_pro/scripts/backup_production.sh"
    echo ""
}

# Run the script
echo ""
log_success "Setup completed successfully!"
show_final_instructions