#!/bin/bash

# 🚀 NoctisPro - Ubuntu 25.04 Server Deployment
# Compatible with Ubuntu 25.04 (Plucky Puffin) and newer

set -e

echo "🚀 Starting NoctisPro Ubuntu 25.04 Deployment..."
echo "================================================="
echo "🐧 Detected: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root or with sudo"
    echo "   Run: sudo bash deploy-ubuntu-25.sh"
    exit 1
fi

# Get deployment type
echo "🔧 Choose deployment type:"
echo "   1) Local development server (port 8000)"
echo "   2) Production server with Nginx (port 80/443)"
echo "   3) Production with SSL domain setup"
read -p "Enter choice (1-3): " DEPLOY_TYPE

case $DEPLOY_TYPE in
    1) DEPLOY_MODE="development" ;;
    2) DEPLOY_MODE="production" ;;
    3) DEPLOY_MODE="ssl" ;;
    *) echo "❌ Invalid choice"; exit 1 ;;
esac

if [[ "$DEPLOY_MODE" == "ssl" ]]; then
    echo "🌐 What domain will you use for your NoctisPro system?"
    echo "   Examples: clinic.example.com, noctis.mydomain.com"
    echo "   (Make sure your domain points to this server's IP)"
    read -p "Domain name: " DOMAIN_NAME
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        echo "❌ Domain name is required for SSL setup!"
        exit 1
    fi
fi

# Update system
echo "📦 Updating system packages..."
apt update
apt upgrade -y

# Install essential packages for Ubuntu 25.04
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
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    ufw \
    supervisor

# Create symbolic link for python command
ln -sf /usr/bin/python3 /usr/bin/python

# Install Docker for Ubuntu 25.04
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository (using Ubuntu 24.04 repo as fallback for 25.04)
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
    
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    echo "✅ Docker installed and started"
else
    echo "✅ Docker already installed"
fi

# Setup application directory
echo "📁 Setting up application directory..."
APP_DIR="/opt/noctis_pro"
mkdir -p $APP_DIR
cp -r /workspace/* $APP_DIR/ 2>/dev/null || true
cd $APP_DIR

# Setup Python virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Setup PostgreSQL database
echo "🗄️ Setting up PostgreSQL database..."
systemctl start postgresql
systemctl enable postgresql

# Generate database password
DB_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 64)

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE noctis_pro;
CREATE USER noctis_pro WITH PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_pro;
ALTER USER noctis_pro CREATEDB;
\q
EOF

# Create environment file
echo "📝 Creating environment configuration..."
cat > .env << EOF
DEBUG=False
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://noctis_pro:$DB_PASSWORD@localhost:5432/noctis_pro
ALLOWED_HOSTS=localhost,127.0.0.1,$(hostname -I | tr -d ' ')
REDIS_URL=redis://localhost:6379/0
STATIC_ROOT=/opt/noctis_pro/staticfiles
MEDIA_ROOT=/opt/noctis_pro/media
EOF

if [[ "$DEPLOY_MODE" == "ssl" ]]; then
    echo "ALLOWED_HOSTS=localhost,127.0.0.1,$DOMAIN_NAME,$(hostname -I | tr -d ' ')" >> .env
fi

# Update Django settings for production
echo "⚙️ Configuring Django for production..."
source venv/bin/activate

# Run migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Create directories
mkdir -p logs media backups

# Create systemd service for Django
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

# Set proper permissions
echo "🔐 Setting file permissions..."
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# Start and enable services
echo "🚀 Starting services..."
systemctl start redis-server
systemctl enable redis-server
systemctl daemon-reload
systemctl start noctis-pro
systemctl enable noctis-pro

if [[ "$DEPLOY_MODE" == "development" ]]; then
    # Development mode - simple setup
    echo "🔥 Configuring firewall for development..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 8000/tcp  # Django dev server
    ufw --force enable
    
    echo ""
    echo "🎉 Development Deployment Complete!"
    echo "=================================="
    echo ""
    echo "🚀 To start your development server:"
    echo "   cd $APP_DIR"
    echo "   source venv/bin/activate"
    echo "   python manage.py runserver 0.0.0.0:8000"
    echo ""
    echo "🌐 Your app will be accessible at:"
    echo "   http://$(hostname -I | tr -d ' '):8000"
    echo "   http://localhost:8000 (if local)"
    echo ""
    
else
    # Production mode - setup Nginx
    echo "🌐 Configuring Nginx..."
    
    cat > /etc/nginx/sites-available/noctis-pro << EOF
upstream noctis_pro {
    server unix:$APP_DIR/noctis_pro.sock;
}

server {
    listen 80;
    server_name $(hostname -I | tr -d ' ') localhost;
    
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

    # Enable site
    ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and start Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    # Configure firewall
    echo "🔥 Configuring firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    if [[ "$DEPLOY_MODE" == "ssl" ]]; then
        ufw allow 443/tcp
    fi
    ufw allow 11112/tcp  # DICOM port
    ufw --force enable
    
    if [[ "$DEPLOY_MODE" == "ssl" ]]; then
        # Setup SSL with Certbot
        echo "🔒 Setting up SSL certificate..."
        apt install -y certbot python3-certbot-nginx
        
        # Update nginx config for domain
        sed -i "s/server_name .*/server_name $DOMAIN_NAME;/" /etc/nginx/sites-available/noctis-pro
        systemctl reload nginx
        
        # Get certificate
        certbot --nginx -d $DOMAIN_NAME --agree-tos --register-unsafely-without-email --non-interactive
        
        # Setup auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
        
        echo ""
        echo "🎉 SSL Production Deployment Complete!"
        echo "====================================="
        echo ""
        echo "🌐 Your NoctisPro system is accessible at:"
        echo "   https://$DOMAIN_NAME"
        echo "   https://$DOMAIN_NAME/admin"
        echo ""
    else
        echo ""
        echo "🎉 Production Deployment Complete!"
        echo "================================="
        echo ""
        echo "🌐 Your NoctisPro system is accessible at:"
        echo "   http://$(hostname -I | tr -d ' ')"
        echo "   http://$(hostname -I | tr -d ' ')/admin"
        echo ""
    fi
    
    echo "🔧 Useful commands:"
    echo "   Service logs:    journalctl -u noctis-pro -f"
    echo "   Nginx logs:      tail -f /var/log/nginx/error.log"
    echo "   Restart app:     systemctl restart noctis-pro"
    echo "   Restart nginx:   systemctl restart nginx"
    echo ""
fi

# Create admin user
echo "👤 Creating admin user..."
cd $APP_DIR
source venv/bin/activate
python manage.py createsuperuser

echo ""
echo "📋 Important information:"
echo "   Application dir: $APP_DIR"
echo "   Virtual env:     $APP_DIR/venv"
echo "   Configuration:   $APP_DIR/.env"
echo "   Logs:           $APP_DIR/logs"
echo "   Static files:   $APP_DIR/staticfiles"
echo "   Media files:    $APP_DIR/media"
echo ""
echo "🚀 Your medical imaging system is now live!"
echo ""