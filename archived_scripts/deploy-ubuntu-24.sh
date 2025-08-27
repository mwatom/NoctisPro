#!/bin/bash

# 🚀 NoctisPro - Ubuntu 24.04 Server Deployment
# Fixed for Ubuntu 24.04 LTS compatibility

set -e

echo "🚀 Starting NoctisPro Ubuntu 24.04 Deployment..."
echo "================================================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root or with sudo"
    echo "   Run: sudo bash deploy-ubuntu-24.sh"
    exit 1
fi

# Check Ubuntu version
if ! cat /etc/os-release | grep -q "24.04"; then
    echo "⚠️  Warning: This script is optimized for Ubuntu 24.04"
    echo "   Your version: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
        exit 1
    fi
fi

# Get deployment type
echo ""
echo "🔧 Choose deployment type:"
echo "   1) Development server (Django dev server, port 8000)"
echo "   2) Production server (Gunicorn + Nginx, no SSL)"
echo "   3) Production with SSL (Gunicorn + Nginx + Let's Encrypt)"
echo "   4) Docker deployment (using docker-compose)"
read -p "Enter choice (1-4): " DEPLOY_TYPE

case $DEPLOY_TYPE in
    1) DEPLOY_MODE="development" ;;
    2) DEPLOY_MODE="production" ;;
    3) DEPLOY_MODE="ssl" ;;
    4) DEPLOY_MODE="docker" ;;
    *) echo "❌ Invalid choice"; exit 1 ;;
esac

if [[ "$DEPLOY_MODE" == "ssl" ]]; then
    echo ""
    echo "🌐 SSL Setup Requirements:"
    echo "   - You need a domain name pointing to this server"
    echo "   - The domain must be publicly accessible"
    echo ""
    read -p "Domain name (e.g., clinic.example.com): " DOMAIN_NAME
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        echo "❌ Domain name is required for SSL setup!"
        exit 1
    fi
    
    # Validate domain format
    if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Invalid domain format!"
        exit 1
    fi
fi

# Update system
echo ""
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
    unzip

# Fix python command
echo "🐍 Setting up Python..."
if [ ! -L /usr/bin/python ]; then
    ln -sf /usr/bin/python3 /usr/bin/python
fi

# Install Docker if needed
if [[ "$DEPLOY_MODE" == "docker" ]]; then
    if ! command -v docker &> /dev/null; then
        echo "🐳 Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Install Docker Compose
        apt install -y docker-compose-plugin
        
        # Start Docker
        systemctl start docker
        systemctl enable docker
        
        echo "✅ Docker installed"
    else
        echo "✅ Docker already installed"
    fi
fi

# Setup application directory
echo "📁 Setting up application..."
APP_DIR="/opt/noctis_pro"
mkdir -p $APP_DIR

# Check if we're in the source directory
if [ -f "manage.py" ]; then
    echo "📋 Copying application files from current directory..."
    cp -r . $APP_DIR/
else
    echo "❌ Error: manage.py not found in current directory"
    echo "   Please run this script from the NoctisPro source directory"
    exit 1
fi

cd $APP_DIR

if [[ "$DEPLOY_MODE" == "docker" ]]; then
    # Docker deployment
    echo "🐳 Setting up Docker deployment..."
    
    # Generate secrets
    DB_PASSWORD=$(openssl rand -base64 32)
    SECRET_KEY=$(openssl rand -base64 64)
    
    # Create environment file
    cat > .env << EOF
DOMAIN_NAME=${DOMAIN_NAME:-localhost}
DB_PASSWORD=$DB_PASSWORD
SECRET_KEY=$SECRET_KEY
POSTGRES_PASSWORD=$DB_PASSWORD
EOF
    
    # Choose appropriate docker-compose file
    if [[ "$DEPLOY_MODE" == "ssl" ]]; then
        COMPOSE_FILE="docker-compose.server.yml"
    else
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ Error: $COMPOSE_FILE not found"
        exit 1
    fi
    
    # Build and start
    echo "🔨 Building and starting containers..."
    docker compose -f $COMPOSE_FILE build
    docker compose -f $COMPOSE_FILE up -d
    
    # Wait for services
    echo "⏳ Waiting for services to start..."
    sleep 30
    
    # Check if services are running
    if docker compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        echo "✅ Docker services are running!"
        
        # Create admin user
        echo "👤 Creating admin user..."
        docker compose -f $COMPOSE_FILE exec web python manage.py createsuperuser
        
        echo ""
        echo "🎉 Docker Deployment Complete!"
        echo "==============================="
        echo ""
        echo "🌐 Access your application:"
        if [[ "$DEPLOY_MODE" == "ssl" ]]; then
            echo "   https://$DOMAIN_NAME"
        else
            echo "   http://$(hostname -I | awk '{print $1}')"
            echo "   http://localhost (if local)"
        fi
        echo ""
        echo "🔧 Useful commands:"
        echo "   View logs:     docker compose -f $COMPOSE_FILE logs -f"
        echo "   Stop:          docker compose -f $COMPOSE_FILE down"
        echo "   Restart:       docker compose -f $COMPOSE_FILE restart"
        echo ""
        
    else
        echo "❌ Some services failed to start. Check logs:"
        docker compose -f $COMPOSE_FILE logs
        exit 1
    fi
    
else
    # Native deployment (non-Docker)
    echo "🐍 Setting up Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    
    # Install Python dependencies
    echo "📦 Installing Python dependencies..."
    pip install --upgrade pip
    
    # Check if requirements.txt exists
    if [ ! -f "requirements.txt" ]; then
        echo "❌ Error: requirements.txt not found"
        exit 1
    fi
    
    pip install -r requirements.txt
    
    # Setup PostgreSQL
    echo "🗄️ Setting up PostgreSQL..."
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
    
    # Create environment configuration
    echo "📝 Creating environment configuration..."
    cat > .env << EOF
DEBUG=False
SECRET_KEY=$SECRET_KEY
DATABASE_URL=postgresql://noctis_pro:$DB_PASSWORD@localhost:5432/noctis_pro
ALLOWED_HOSTS=localhost,127.0.0.1,$(hostname -I | awk '{print $1}')
REDIS_URL=redis://localhost:6379/0
STATIC_ROOT=$APP_DIR/staticfiles
MEDIA_ROOT=$APP_DIR/media
EOF
    
    if [[ "$DEPLOY_MODE" == "ssl" ]]; then
        echo "ALLOWED_HOSTS=localhost,127.0.0.1,$DOMAIN_NAME,$(hostname -I | awk '{print $1}')" >> .env
    fi
    
    # Run Django setup
    echo "⚙️ Setting up Django..."
    source venv/bin/activate
    
    # Run migrations
    python manage.py migrate
    
    # Collect static files
    python manage.py collectstatic --noinput
    
    # Create directories
    mkdir -p logs media backups
    
    # Setup Redis
    echo "🔄 Setting up Redis..."
    systemctl start redis-server
    systemctl enable redis-server
    
    if [[ "$DEPLOY_MODE" == "development" ]]; then
        # Development setup
        echo "🔥 Configuring firewall for development..."
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 8000/tcp
        ufw --force enable
        
        # Set permissions
        chown -R $USER:$USER $APP_DIR
        
        echo ""
        echo "🎉 Development Setup Complete!"
        echo "=============================="
        echo ""
        echo "🚀 To start your development server:"
        echo "   cd $APP_DIR"
        echo "   source venv/bin/activate"
        echo "   python manage.py runserver 0.0.0.0:8000"
        echo ""
        echo "🌐 Access your application:"
        echo "   http://$(hostname -I | awk '{print $1}'):8000"
        echo "   http://localhost:8000 (if local)"
        echo ""
        
        # Create admin user
        echo "👤 Creating admin user..."
        python manage.py createsuperuser
        
    else
        # Production setup
        echo "🔧 Setting up production services..."
        
        # Create systemd service
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
        
        # Setup Nginx
        echo "🌐 Configuring Nginx..."
        
        SERVER_NAME="$(hostname -I | awk '{print $1}') localhost"
        if [[ "$DEPLOY_MODE" == "ssl" ]]; then
            SERVER_NAME="$DOMAIN_NAME"
        fi
        
        cat > /etc/nginx/sites-available/noctis-pro << EOF
upstream noctis_pro {
    server unix:$APP_DIR/noctis_pro.sock;
}

server {
    listen 80;
    server_name $SERVER_NAME;
    
    client_max_body_size 500M;
    
    location = /favicon.ico { 
        access_log off; 
        log_not_found off; 
    }
    
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
        
        # Test and start Nginx
        nginx -t
        systemctl restart nginx
        systemctl enable nginx
        
        if [[ "$DEPLOY_MODE" == "ssl" ]]; then
            # Setup SSL
            echo "🔒 Setting up SSL certificate..."
            apt install -y certbot python3-certbot-nginx
            
            # Get certificate
            certbot --nginx -d $DOMAIN_NAME --agree-tos --register-unsafely-without-email --non-interactive
            
            # Setup auto-renewal
            echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
        fi
        
        # Create admin user
        echo "👤 Creating admin user..."
        cd $APP_DIR
        source venv/bin/activate
        python manage.py createsuperuser
        
        echo ""
        echo "🎉 Production Deployment Complete!"
        echo "=================================="
        echo ""
        echo "🌐 Access your application:"
        if [[ "$DEPLOY_MODE" == "ssl" ]]; then
            echo "   https://$DOMAIN_NAME"
            echo "   https://$DOMAIN_NAME/admin"
        else
            echo "   http://$(hostname -I | awk '{print $1}')"
            echo "   http://$(hostname -I | awk '{print $1}')/admin"
        fi
        echo ""
        echo "🔧 Useful commands:"
        echo "   App logs:        journalctl -u noctis-pro -f"
        echo "   Nginx logs:      tail -f /var/log/nginx/error.log"
        echo "   Restart app:     systemctl restart noctis-pro"
        echo "   Restart nginx:   systemctl restart nginx"
        echo "   Check status:    systemctl status noctis-pro"
        echo ""
    fi
fi

echo "📋 Important files and directories:"
echo "   Application:     $APP_DIR"
echo "   Configuration:   $APP_DIR/.env"
echo "   Virtual env:     $APP_DIR/venv"
echo "   Static files:    $APP_DIR/staticfiles"
echo "   Media files:     $APP_DIR/media"
echo "   Logs:           $APP_DIR/logs"
echo ""
echo "🚀 Your NoctisPro medical imaging system is now live!"
echo ""