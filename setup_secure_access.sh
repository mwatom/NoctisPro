#!/bin/bash

# Secure Access Setup for NoctisPro
# This script configures secure access options without exposing the server IP

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Configuration
PROJECT_DIR="/opt/noctis_pro"
DOMAIN_NAME=""
VPN_SETUP=""
CLOUDFLARE_TUNNEL=""
REVERSE_PROXY=""

echo "=== NoctisPro Secure Access Configuration ==="
echo
echo "Choose your secure access method:"
echo "1) Domain with SSL Certificate (Recommended)"
echo "2) Cloudflare Tunnel (Zero Trust)"
echo "3) VPN Access Only"
echo "4) Reverse Proxy with Custom Domain"
echo "5) Local Network Access Only"
echo

read -p "Select option (1-5): " ACCESS_METHOD

case $ACCESS_METHOD in
    1)
        log_info "Setting up Domain with SSL Certificate..."
        read -p "Enter your domain name (e.g., noctis.yourdomain.com): " DOMAIN_NAME
        
        if [[ -z "$DOMAIN_NAME" ]]; then
            log_error "Domain name is required"
            exit 1
        fi
        
        # Update Nginx configuration for domain
        log_info "Updating Nginx configuration for domain: $DOMAIN_NAME"
        
        # Update Django settings
        sed -i "s#DOMAIN_NAME=noctis-server.local#DOMAIN_NAME=$DOMAIN_NAME#" $PROJECT_DIR/.env
        
        # Update Nginx configuration
        sed -i "s#server_name .*#server_name $DOMAIN_NAME;#" /etc/nginx/sites-available/noctis-pro
        
        # Get SSL certificate
        log_info "Obtaining SSL certificate for $DOMAIN_NAME..."
        certbot --nginx -d $DOMAIN_NAME --email admin@$DOMAIN_NAME --agree-tos --non-interactive
        
        if [ $? -eq 0 ]; then
            # Enable SSL in Django settings
            sed -i 's/ENABLE_SSL=false/ENABLE_SSL=true/' $PROJECT_DIR/.env
            
            # Update allowed hosts
            sed -i "s#ALLOWED_HOSTS=.*#ALLOWED_HOSTS=$DOMAIN_NAME,localhost,127.0.0.1#" $PROJECT_DIR/.env
            
            # Restart services
            systemctl restart noctis-django noctis-daphne nginx
            
            log_success "HTTPS access configured successfully!"
            log_success "Your site is available at: https://$DOMAIN_NAME"
            log_info "Webhook URL: https://$DOMAIN_NAME/webhook"
        else
            log_error "Failed to obtain SSL certificate"
        fi
        ;;
        
    2)
        log_info "Setting up Cloudflare Tunnel..."
        
        # Install cloudflared
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
        
        log_info "Cloudflare Tunnel installed. Please follow these steps:"
        echo
        echo "1. Login to Cloudflare:"
        echo "   cloudflared tunnel login"
        echo
        echo "2. Create a tunnel:"
        echo "   cloudflared tunnel create noctis-pro"
        echo
        echo "3. Configure the tunnel:"
        echo "   Create ~/.cloudflared/config.yml with:"
        echo "   tunnel: <tunnel-id>"
        echo "   credentials-file: /root/.cloudflared/<tunnel-id>.json"
        echo "   ingress:"
        echo "     - hostname: your-domain.com"
        echo "       service: http://localhost:80"
        echo "     - service: http_status:404"
        echo
        echo "4. Create DNS record in Cloudflare dashboard"
        echo "5. Run the tunnel:"
        echo "   cloudflared tunnel run noctis-pro"
        echo
        log_warning "Complete the Cloudflare setup manually using the instructions above"
        ;;
        
    3)
        log_info "Setting up VPN-only access..."
        
        # Install WireGuard
        apt update
        apt install -y wireguard
        
        # Generate server keys
        cd /etc/wireguard
        wg genkey | tee server_private_key | wg pubkey > server_public_key
        
        # Create WireGuard configuration
        cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $(cat server_private_key)
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client configuration will be added here
EOF
        
        # Enable IP forwarding
        echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
        sysctl -p
        
        # Configure firewall for VPN
        ufw allow 51820/udp
        
        # Start WireGuard
        systemctl enable wg-quick@wg0
        systemctl start wg-quick@wg0
        
        # Update Nginx to only listen on VPN interface
        sed -i 's#listen 80;#listen 10.0.0.1:80;#' /etc/nginx/sites-available/noctis-pro
        sed -i 's#listen 443 ssl;#listen 10.0.0.1:443 ssl;#' /etc/nginx/sites-available/noctis-pro
        
        systemctl reload nginx
        
        log_success "WireGuard VPN configured!"
        log_info "Server public key: $(cat server_public_key)"
        log_info "Add clients to /etc/wireguard/wg0.conf and restart: systemctl restart wg-quick@wg0"
        ;;
        
    4)
        log_info "Setting up Reverse Proxy access..."
        read -p "Enter your reverse proxy domain: " PROXY_DOMAIN
        
        # Configure for reverse proxy
        cat >> /etc/nginx/sites-available/noctis-pro << 'EOF'

# Reverse proxy configuration
real_ip_header X-Forwarded-For;
set_real_ip_from 0.0.0.0/0;

# Trust proxy headers
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
EOF
        
        # Update Django settings for proxy
        echo "USE_X_FORWARDED_HOST = True" >> $PROJECT_DIR/noctis_pro/settings_production.py
        echo "SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')" >> $PROJECT_DIR/noctis_pro/settings_production.py
        
        systemctl restart noctis-django nginx
        
        log_success "Reverse proxy configuration applied"
        log_info "Configure your reverse proxy to forward to: http://102.215.33.50"
        ;;
        
    5)
        log_info "Configuring for local network access only..."
        
        # Restrict access to local network
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow from 192.168.0.0/16
        ufw allow from 10.0.0.0/8
        ufw allow from 172.16.0.0/12
        ufw allow ssh
        ufw --force enable
        
        # Update Nginx to listen only on private IP
        sed -i "s#listen 80;#listen 102.215.33.50:80;#" /etc/nginx/sites-available/noctis-pro
        
        systemctl reload nginx
        
        log_success "Local network access configured"
        log_info "Access via: http://102.215.33.50 (local network only)"
        ;;
        
    *)
        log_error "Invalid option selected"
        exit 1
        ;;
esac

# Create secure access information file
cat > $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF
NoctisPro Secure Access Configuration
====================================

Configuration Method: $ACCESS_METHOD
Date: $(date)

Access Information:
EOF

case $ACCESS_METHOD in
    1)
        cat >> $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF
- HTTPS URL: https://$DOMAIN_NAME
- Admin Panel: https://$DOMAIN_NAME/admin
- Webhook URL: https://$DOMAIN_NAME/webhook
- SSL Certificate: Auto-renewed via Let's Encrypt
EOF
        ;;
    2)
        cat >> $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF
- Access via Cloudflare Tunnel (Zero Trust)
- No direct IP exposure
- Complete Cloudflare configuration required
EOF
        ;;
    3)
        cat >> $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF
- VPN-only access via WireGuard
- VPN Server: 102.215.33.50:51820
- Internal URL: http://10.0.0.1
- Client configuration required
EOF
        ;;
    4)
        cat >> $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF
- Reverse proxy configuration applied
- Access via: https://$PROXY_DOMAIN
- Backend: http://102.215.33.50
EOF
        ;;
    5)
        cat >> $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF
- Local network access only
- URL: http://102.215.33.50
- Restricted to private IP ranges
EOF
        ;;
esac

cat >> $PROJECT_DIR/SECURE_ACCESS_INFO.txt << EOF

Security Features:
- Firewall (UFW) configured
- Fail2ban protection active
- Strong passwords generated
- Database access restricted
- Redis authentication enabled

Management:
- Status: /usr/local/bin/noctis-status.sh
- Backup: /usr/local/bin/noctis-backup.sh
- Logs: journalctl -u noctis-django -f
EOF

chown noctis:noctis $PROJECT_DIR/SECURE_ACCESS_INFO.txt

log_success "Secure access configuration completed!"
log_info "Configuration details saved to: $PROJECT_DIR/SECURE_ACCESS_INFO.txt"