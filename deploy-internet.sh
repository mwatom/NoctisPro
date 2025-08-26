#!/bin/bash

# 🌐 NoctisPro Internet Deployment Script
# Deploy directly from cloned repository to internet with SSL

set -e

echo "🌐 NoctisPro Internet Deployment"
echo "================================="
echo "🚀 Deploy your medical imaging system to the internet!"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root or with sudo"
    echo "   Run: sudo bash deploy-internet.sh"
    exit 1
fi

# Check if in correct directory
if [ ! -f "manage.py" ]; then
    echo "❌ Error: manage.py not found"
    echo "   Please run this script from the NoctisPro repository directory"
    echo "   Example:"
    echo "   git clone <repository-url>"
    echo "   cd <repository-name>"
    echo "   sudo bash deploy-internet.sh"
    exit 1
fi

echo "✅ Found NoctisPro application files"
echo ""

# Domain setup options
echo "🌐 Domain Setup Options:"
echo "   1) Use noctispro.com (you mentioned this)"
echo "   2) Use DuckDNS free subdomain (automatic setup)"
echo "   3) Use ngrok tunnel (instant access)"
echo "   4) I have my own domain"
read -p "Choose option (1-4): " DOMAIN_OPTION

case $DOMAIN_OPTION in
    1)
        DOMAIN_NAME="noctispro.com"
        DOMAIN_TYPE="custom"
        echo "🌐 Using domain: $DOMAIN_NAME"
        echo "⚠️  NOTE: Make sure noctispro.com points to this server's IP!"
        ;;
    2)
        DOMAIN_TYPE="duckdns"
        echo "🦆 DuckDNS Setup"
        echo "   We'll create a free subdomain like: yourname.duckdns.org"
        read -p "Choose subdomain name (e.g., 'mynoctis' for mynoctis.duckdns.org): " SUBDOMAIN
        DOMAIN_NAME="${SUBDOMAIN}.duckdns.org"
        read -p "DuckDNS token (get from https://www.duckdns.org): " DUCKDNS_TOKEN
        ;;
    3)
        DOMAIN_TYPE="ngrok"
        echo "🚇 Ngrok tunnel will provide instant internet access"
        read -p "Ngrok auth token (get from https://ngrok.com): " NGROK_TOKEN
        ;;
    4)
        DOMAIN_TYPE="custom"
        read -p "Enter your domain name: " DOMAIN_NAME
        echo "⚠️  Make sure $DOMAIN_NAME points to this server's IP!"
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "🛠️  System Setup Starting..."
echo "=============================="

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "Unable to detect")
echo "🌍 Server IP: $SERVER_IP"

# Update system
echo "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y

# Install essential packages
echo "📦 Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libcups2-dev \
    libpq-dev \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    ufw \
    supervisor \
    htop \
    tree \
    unzip \
    cron

# Fix python command
if [ ! -L /usr/bin/python ]; then
    ln -sf /usr/bin/python3 /usr/bin/python
fi

# Setup application directory
APP_DIR="/opt/noctis_pro"
echo "📁 Setting up application in $APP_DIR..."
mkdir -p $APP_DIR
cp -r . $APP_DIR/
cd $APP_DIR

# Setup Python environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Setup PostgreSQL
echo "🗄️ Setting up PostgreSQL database..."
systemctl start postgresql
systemctl enable postgresql

# Generate secrets
DB_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 64)

# Create database
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS noctis_pro;
DROP USER IF EXISTS noctis_pro;
CREATE DATABASE noctis_pro;
CREATE USER noctis_pro WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_pro;
ALTER USER noctis_pro CREATEDB;
\q
EOF

# Create environment file
echo "📝 Creating environment configuration..."
if [[ "$DOMAIN_TYPE" == "ngrok" ]]; then
    ALLOWED_HOSTS="localhost,127.0.0.1,$SERVER_IP,*.ngrok.io,*.ngrok-free.app"
else
    ALLOWED_HOSTS="localhost,127.0.0.1,$SERVER_IP,$DOMAIN_NAME"
fi

cat > .env << EOF
DEBUG=False
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://noctis_pro:$DB_PASSWORD@localhost:5432/noctis_pro
ALLOWED_HOSTS=$ALLOWED_HOSTS
REDIS_URL=redis://localhost:6379/0
STATIC_ROOT=$APP_DIR/staticfiles
MEDIA_ROOT=$APP_DIR/media
EOF

# Setup Django
echo "⚙️ Configuring Django..."
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput

# Create directories
mkdir -p logs media backups

# Setup Redis
systemctl start redis-server
systemctl enable redis-server

# Create systemd service
echo "🔧 Creating systemd service..."
cat > /etc/systemd/system/noctis-pro.service << EOF
[Unit]
Description=NoctisPro Django Application
After=network.target postgresql.service redis.service

[Service]
Type=exec
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind unix:$APP_DIR/noctis_pro.sock noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# Start Django service
systemctl daemon-reload
systemctl start noctis-pro
systemctl enable noctis-pro

# Domain-specific setup
if [[ "$DOMAIN_TYPE" == "ngrok" ]]; then
    echo "🚇 Setting up Ngrok tunnel..."
    
    # Install ngrok
    if ! command -v ngrok &> /dev/null; then
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | gpg --dearmor > /usr/share/keyrings/ngrok.gpg
        echo "deb [signed-by=/usr/share/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" > /etc/apt/sources.list.d/ngrok.list
        apt update
        apt install -y ngrok
    fi
    
    # Configure ngrok
    ngrok config add-authtoken $NGROK_TOKEN
    
    # Create simple nginx config for ngrok
    cat > /etc/nginx/sites-available/noctis-pro << EOF
server {
    listen 80;
    server_name localhost;
    
    client_max_body_size 500M;
    
    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        alias $APP_DIR/staticfiles/;
    }
    
    location /media/ {
        alias $APP_DIR/media/;
    }
    
    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/noctis_pro.sock;
    }
}
EOF
    
    # Enable nginx
    ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    # Configure firewall for ngrok
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw --force enable
    
    # Start ngrok tunnel
    echo "🚇 Starting ngrok tunnel..."
    nohup ngrok http 80 > /var/log/ngrok.log 2>&1 &
    sleep 5
    
    # Get ngrok URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data['tunnels'] else 'Not available')" 2>/dev/null || echo "Check manually")
    
elif [[ "$DOMAIN_TYPE" == "duckdns" ]]; then
    echo "🦆 Setting up DuckDNS..."
    
    # Update DuckDNS
    curl -s "https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$SERVER_IP"
    
    # Create cron job for DuckDNS updates
    echo "*/5 * * * * curl -s 'https://www.duckdns.org/update?domains=$SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=' > /var/log/duckdns.log 2>&1" | crontab -
    
    # Setup nginx with SSL
    cat > /etc/nginx/sites-available/noctis-pro << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    # Enable nginx temporarily
    ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl restart nginx
    
    # Install certbot and get SSL
    apt install -y certbot python3-certbot-nginx
    mkdir -p /var/www/html
    
    echo "🔒 Getting SSL certificate..."
    certbot certonly --webroot -w /var/www/html -d $DOMAIN_NAME --agree-tos --register-unsafely-without-email --non-interactive
    
    # Update nginx with SSL
    cat > /etc/nginx/sites-available/noctis-pro << EOF
upstream noctis_pro {
    server unix:$APP_DIR/noctis_pro.sock;
}

server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    client_max_body_size 500M;
    
    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        alias $APP_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $APP_DIR/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        include proxy_params;
        proxy_pass http://noctis_pro;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

else
    # Custom domain or noctispro.com
    echo "🌐 Setting up custom domain: $DOMAIN_NAME..."
    
    # Basic nginx config first
    cat > /etc/nginx/sites-available/noctis-pro << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
    
    # Enable nginx
    ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t
    systemctl restart nginx
    
    # Install certbot
    apt install -y certbot python3-certbot-nginx
    mkdir -p /var/www/html
    
    echo "🔒 Attempting to get SSL certificate for $DOMAIN_NAME..."
    if certbot certonly --webroot -w /var/www/html -d $DOMAIN_NAME --agree-tos --register-unsafely-without-email --non-interactive; then
        echo "✅ SSL certificate obtained!"
        
        # Update nginx with SSL
        cat > /etc/nginx/sites-available/noctis-pro << EOF
upstream noctis_pro {
    server unix:$APP_DIR/noctis_pro.sock;
}

server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    client_max_body_size 500M;
    
    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        alias $APP_DIR/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $APP_DIR/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        include proxy_params;
        proxy_pass http://noctis_pro;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF
        
        # Setup SSL renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx" | crontab -
        
    else
        echo "⚠️  SSL certificate failed. Setting up HTTP only..."
        
        cat > /etc/nginx/sites-available/noctis-pro << EOF
upstream noctis_pro {
    server unix:$APP_DIR/noctis_pro.sock;
}

server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    client_max_body_size 500M;
    
    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        alias $APP_DIR/staticfiles/;
    }
    
    location /media/ {
        alias $APP_DIR/media/;
    }
    
    location / {
        include proxy_params;
        proxy_pass http://noctis_pro;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF
    fi
fi

# Final nginx restart
systemctl restart nginx
systemctl enable nginx

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

# Create admin user
echo ""
echo "👤 Creating admin user..."
cd $APP_DIR
source venv/bin/activate
python manage.py createsuperuser

echo ""
echo "🎉 Internet Deployment Complete!"
echo "================================="
echo ""

if [[ "$DOMAIN_TYPE" == "ngrok" ]]; then
    echo "🌐 Your NoctisPro system is accessible at:"
    echo "   $NGROK_URL"
    echo "   Admin: $NGROK_URL/admin"
    echo ""
    echo "🚇 Ngrok tunnel info:"
    echo "   View tunnel dashboard: http://localhost:4040"
    echo "   Tunnel logs: tail -f /var/log/ngrok.log"
    echo ""
elif [[ "$DOMAIN_TYPE" == "duckdns" ]]; then
    echo "🌐 Your NoctisPro system is accessible at:"
    echo "   https://$DOMAIN_NAME"
    echo "   Admin: https://$DOMAIN_NAME/admin"
    echo ""
    echo "🦆 DuckDNS automatically updates your IP every 5 minutes"
    echo ""
else
    if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
        echo "🌐 Your NoctisPro system is accessible at:"
        echo "   https://$DOMAIN_NAME"
        echo "   Admin: https://$DOMAIN_NAME/admin"
        echo ""
        echo "🔒 SSL certificate is active and will auto-renew"
    else
        echo "🌐 Your NoctisPro system is accessible at:"
        echo "   http://$DOMAIN_NAME"
        echo "   Admin: http://$DOMAIN_NAME/admin"
        echo ""
        echo "⚠️  SSL setup failed. Make sure $DOMAIN_NAME points to $SERVER_IP"
        echo "   You can retry SSL later with: sudo certbot --nginx -d $DOMAIN_NAME"
    fi
fi

echo "📋 Important information:"
echo "   Server IP:       $SERVER_IP"
echo "   Application:     $APP_DIR"
echo "   Configuration:   $APP_DIR/.env"
echo "   Logs:           journalctl -u noctis-pro -f"
echo ""
echo "🔧 Useful commands:"
echo "   Restart app:     sudo systemctl restart noctis-pro"
echo "   View app logs:   sudo journalctl -u noctis-pro -f"
echo "   View nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "   Check status:    sudo systemctl status noctis-pro nginx"
echo ""
echo "🚀 Your medical imaging system is now live on the internet!"
echo ""