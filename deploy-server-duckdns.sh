#!/bin/bash

# 🦆 NoctisPro - Simple Server Deployment with DuckDNS
# This script deploys NoctisPro to Ubuntu Server with free DuckDNS domain!

set -e

echo "🦆 NoctisPro Server Deployment with DuckDNS"
echo "==========================================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root or with sudo"
    exit 1
fi

# Check if running on Ubuntu
if ! lsb_release -a 2>/dev/null | grep -q Ubuntu; then
    echo "❌ This script is designed for Ubuntu Server."
    exit 1
fi

echo "🦆 Let's set up your free DuckDNS domain!"
echo ""
echo "📋 Before we start, you need:"
echo "1. Go to https://www.duckdns.org"
echo "2. Sign in with Google/GitHub/Reddit"
echo "3. Create a subdomain (e.g., 'myclinic' becomes myclinic.duckdns.org)"
echo "4. Get your token from the top of the page"
echo ""
read -p "Press Enter when you have your DuckDNS subdomain and token ready..."

# Get DuckDNS details
echo ""
read -p "🦆 Enter your DuckDNS subdomain (without .duckdns.org): " SUBDOMAIN
read -p "🔑 Enter your DuckDNS token: " DUCKDNS_TOKEN

if [[ -z "$SUBDOMAIN" || -z "$DUCKDNS_TOKEN" ]]; then
    echo "❌ Both subdomain and token are required!"
    exit 1
fi

DOMAIN_NAME="${SUBDOMAIN}.duckdns.org"

echo ""
echo "🌐 Your domain will be: $DOMAIN_NAME"
read -p "Is this correct? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Get current public IP
echo "🌍 Getting your public IP address..."
PUBLIC_IP=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org)
if [[ -z "$PUBLIC_IP" ]]; then
    echo "❌ Could not determine public IP address"
    exit 1
fi
echo "📍 Your public IP: $PUBLIC_IP"

# Update DuckDNS
echo "🦆 Updating DuckDNS with your IP..."
DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")
if [[ "$DUCKDNS_RESPONSE" == "OK" ]]; then
    echo "✅ DuckDNS updated successfully!"
else
    echo "❌ DuckDNS update failed: $DUCKDNS_RESPONSE"
    echo "Please check your subdomain and token"
    exit 1
fi

# Wait for DNS propagation
echo "⏳ Waiting for DNS propagation (30 seconds)..."
sleep 30

# Test DNS resolution
echo "🔍 Testing DNS resolution..."
if nslookup $DOMAIN_NAME >/dev/null 2>&1; then
    echo "✅ DNS is working!"
else
    echo "⚠️  DNS not yet propagated, but continuing..."
fi

# Generate secure passwords
DB_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 64)

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "✅ Docker installed!"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    apt update
    apt install -y docker-compose-plugin
    echo "✅ Docker Compose installed!"
fi

# Install Certbot and other tools
echo "📦 Installing required tools..."
apt update
apt install -y certbot nginx-light ufw cron

# Configure firewall
echo "🔥 Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 11112/tcp  # DICOM port
ufw --force enable

# Create environment file
echo "📝 Creating environment configuration..."
cat > .env << EOF
DOMAIN_NAME=$DOMAIN_NAME
DB_PASSWORD=$DB_PASSWORD
SECRET_KEY=$SECRET_KEY
DUCKDNS_SUBDOMAIN=$SUBDOMAIN
DUCKDNS_TOKEN=$DUCKDNS_TOKEN
EOF

# Create directories
echo "📁 Creating directories..."
mkdir -p backups logs ssl

# Create nginx configuration
echo "📝 Creating Nginx configuration..."
cat > nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 500M;
    
    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name DOMAIN_PLACEHOLDER;
        return 301 https://$server_name$request_uri;
    }
    
    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name DOMAIN_PLACEHOLDER;
        
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        
        location / {
            proxy_pass http://web:8000;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 300s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;
        }
        
        location /static/ {
            alias /var/www/static/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        location /media/ {
            alias /var/www/media/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

# Replace domain placeholder
sed -i "s#DOMAIN_PLACEHOLDER#$DOMAIN_NAME#g" nginx.conf

# Stop nginx if running
systemctl stop nginx 2>/dev/null || true

# Get SSL certificate
echo "🔒 Obtaining SSL certificate..."
certbot certonly --standalone -d $DOMAIN_NAME --agree-tos --register-unsafely-without-email --non-interactive

# Copy SSL certificates
cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem ssl/
cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem ssl/

# Build and start services
echo "🔨 Building and starting NoctisPro..."
docker compose -f docker-compose.server.yml build
docker compose -f docker-compose.server.yml up -d

echo "⏳ Waiting for services to start..."
sleep 60

# Check if services are running
echo "🔍 Checking service status..."
if docker compose -f docker-compose.server.yml ps | grep -q "Up"; then
    echo "✅ Services are running!"
else
    echo "❌ Some services failed to start. Check logs:"
    docker compose -f docker-compose.server.yml logs
    exit 1
fi

# Test HTTPS access
echo "🔍 Testing HTTPS access..."
if curl -s -k https://$DOMAIN_NAME > /dev/null; then
    echo "✅ HTTPS is working!"
else
    echo "⚠️  HTTPS test failed, but services are running. DNS may still be propagating."
fi

# Setup DuckDNS auto-update cron job
echo "🔄 Setting up DuckDNS auto-update..."
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -s 'https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=' >/dev/null 2>&1") | crontab -

# Setup SSL renewal
echo "🔄 Setting up SSL certificate renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --pre-hook 'docker compose -f $(pwd)/docker-compose.server.yml stop nginx' --post-hook 'cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem $(pwd)/ssl/ && cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem $(pwd)/ssl/ && docker compose -f $(pwd)/docker-compose.server.yml start nginx'") | crontab -

# Create admin user
echo ""
echo "👤 Creating admin user..."
docker compose -f docker-compose.server.yml exec web python manage.py createsuperuser

echo ""
echo "🎉 NoctisPro with DuckDNS Deployment Complete!"
echo "============================================="
echo ""
echo "🌐 Your NoctisPro system is now accessible at:"
echo "   🔗 Main Site: https://$DOMAIN_NAME"
echo "   👑 Admin:     https://$DOMAIN_NAME/admin"
echo ""
echo "🦆 DuckDNS Configuration:"
echo "   📋 Subdomain: $SUBDOMAIN"
echo "   🌍 Full URL:  https://$DOMAIN_NAME"
echo "   🔄 Auto-update: Every 5 minutes"
echo ""
echo "🔧 Useful commands:"
echo "   📊 View logs:  docker compose -f docker-compose.server.yml logs -f"
echo "   🛑 Stop:       docker compose -f docker-compose.server.yml down"
echo "   🔄 Restart:    docker compose -f docker-compose.server.yml restart"
echo ""
echo "🔒 Security Features:"
echo "   ✅ HTTPS with auto-renewal"
echo "   ✅ Firewall configured"
echo "   ✅ Security headers enabled"
echo "   ✅ DuckDNS auto-update every 5 minutes"
echo ""
echo "📋 Important files saved:"
echo "   🔐 Environment: .env"
echo "   🔒 SSL certs:   ssl/"
echo "   💾 Backups:     backups/"
echo "   📝 Logs:        logs/"
echo ""
echo "🚀 Your medical imaging system is now live on the internet!"
echo "Share your link: https://$DOMAIN_NAME"
echo ""