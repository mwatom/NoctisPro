#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "🏥 NOCTIS PRO MEDICAL IMAGING SYSTEM - NON-DOCKER DEPLOYMENT 🏥"
echo "════════════════════════════════════════════════════════════"
echo ""

# Exit on any error
set -e

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Function to check if service is running
check_service() {
    if systemctl is-active --quiet $1; then
        echo "✅ $1 is running"
        return 0
    else
        echo "❌ $1 is not running"
        return 1
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    echo "📦 Installing system dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install Python development tools
    sudo apt install -y python3-dev python3-pip python3-venv
    
    # Install PostgreSQL
    sudo apt install -y postgresql postgresql-contrib libpq-dev
    
    # Install Redis
    sudo apt install -y redis-server
    
    # Install Nginx
    sudo apt install -y nginx
    
    # Install system libraries for DICOM and image processing
    sudo apt install -y libgdcm-dev libopenjp2-7-dev libjpeg-dev libpng-dev
    sudo apt install -y libssl-dev libffi-dev
    
    # Install CUPS for printing support
    sudo apt install -y cups libcups2-dev
    
    echo "✅ System dependencies installed!"
}

# Function to setup PostgreSQL
setup_postgresql() {
    echo "🗄️  Setting up PostgreSQL..."
    
    # Start and enable PostgreSQL
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Create database and user
    DB_NAME="noctis_pro"
    DB_USER="noctis_user"
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql << EOF
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
ALTER ROLE ${DB_USER} SET client_encoding TO 'utf8';
ALTER ROLE ${DB_USER} SET default_transaction_isolation TO 'read committed';
ALTER ROLE ${DB_USER} SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
\q
EOF

    echo "✅ PostgreSQL setup complete!"
    echo "Database: ${DB_NAME}"
    echo "User: ${DB_USER}"
    echo "Password: ${DB_PASSWORD}"
    
    # Save database credentials
    echo "DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}" > /tmp/db_credentials.txt
}

# Function to setup Redis
setup_redis() {
    echo "📊 Setting up Redis..."
    
    # Configure Redis
    sudo sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
    sudo sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
    
    # Start and enable Redis
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    
    echo "✅ Redis setup complete!"
}

# Function to create Python virtual environment
setup_python_environment() {
    echo "🐍 Setting up Python virtual environment..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python dependencies
    echo "📦 Installing Python dependencies..."
    pip install -r requirements.txt
    
    echo "✅ Python environment setup complete!"
}

# Function to create directory structure
create_directories() {
    echo "📁 Creating directory structure..."
    
    # Create application directories
    sudo mkdir -p /opt/noctis/{media,staticfiles,logs,dicom_storage,backups}
    sudo mkdir -p /var/log/noctis
    
    # Set ownership
    sudo chown -R $USER:$USER /opt/noctis
    sudo chown -R $USER:$USER /var/log/noctis
    
    # Set permissions
    chmod -R 755 /opt/noctis
    chmod -R 755 /var/log/noctis
    
    echo "✅ Directory structure created!"
}

# Function to create environment configuration
create_environment_config() {
    echo "⚙️  Creating environment configuration..."
    
    # Generate secret key
    SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    # Get database URL
    DB_URL=$(cat /tmp/db_credentials.txt)
    
    # Create production environment file
    cat > .env.production << EOF
# Django Configuration
SECRET_KEY=${SECRET_KEY}
DEBUG=False
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production

# Database
${DB_URL}

# Redis
REDIS_URL=redis://localhost:6379/0

# Server Configuration
ALLOWED_HOSTS=localhost,127.0.0.1,$(hostname -I | awk '{print $1}')
DOMAIN_NAME=

# Media and Static Files
MEDIA_ROOT=/opt/noctis/media
STATIC_ROOT=/opt/noctis/staticfiles

# DICOM Configuration
DICOM_STORAGE_PATH=/opt/noctis/dicom_storage
DICOM_PORT=11112

# Logging
LOG_LEVEL=INFO
LOG_FILE=/var/log/noctis/noctis.log

# Security
SECURE_SSL_REDIRECT=False
SECURE_HSTS_SECONDS=0
EOF

    echo "✅ Environment configuration created!"
    echo "📝 Configuration saved to .env.production"
}

# Function to run Django setup
setup_django() {
    echo "🚀 Setting up Django application..."
    
    source venv/bin/activate
    
    # Load environment variables
    set -a
    source .env.production
    set +a
    
    # Run migrations
    echo "🔄 Running database migrations..."
    python manage.py migrate --settings=noctis_pro.settings_production
    
    # Collect static files
    echo "📦 Collecting static files..."
    python manage.py collectstatic --noinput --settings=noctis_pro.settings_production
    
    # Create superuser automatically
    echo "👤 Creating superuser..."
    python create_superuser.py
    
    echo "✅ Django setup complete!"
}

# Function to create systemd services
create_systemd_services() {
    echo "🔧 Creating systemd services..."
    
    # Django/Gunicorn service
    sudo tee /etc/systemd/system/noctis-web.service > /dev/null << EOF
[Unit]
Description=Noctis Pro Web Application
After=network.target postgresql.service redis-server.service
Requires=postgresql.service redis-server.service

[Service]
Type=notify
User=$USER
Group=$USER
WorkingDirectory=$(pwd)
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
EnvironmentFile=$(pwd)/.env.production
ExecStart=$(pwd)/venv/bin/gunicorn --bind 127.0.0.1:8000 --workers 3 --worker-class gthread --threads 2 --timeout 120 noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Celery worker service
    sudo tee /etc/systemd/system/noctis-celery.service > /dev/null << EOF
[Unit]
Description=Noctis Pro Celery Worker
After=network.target redis-server.service
Requires=redis-server.service

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$(pwd)
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
EnvironmentFile=$(pwd)/.env.production
ExecStart=$(pwd)/venv/bin/celery -A noctis_pro worker --loglevel=info --detach
ExecStop=$(pwd)/venv/bin/celery -A noctis_pro control shutdown
ExecReload=$(pwd)/venv/bin/celery -A noctis_pro control reload
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # DICOM receiver service
    sudo tee /etc/systemd/system/noctis-dicom.service > /dev/null << EOF
[Unit]
Description=Noctis Pro DICOM Receiver
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$(pwd)
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
EnvironmentFile=$(pwd)/.env.production
ExecStart=$(pwd)/venv/bin/python dicom_receiver.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    echo "✅ Systemd services created!"
}

# Function to configure Nginx
configure_nginx() {
    echo "🌐 Configuring Nginx..."
    
    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/noctis-pro > /dev/null << EOF
server {
    listen 80;
    server_name localhost $(hostname -I | awk '{print $1}');
    
    client_max_body_size 100M;
    
    location /static/ {
        alias /opt/noctis/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctis/media/;
        expires 7d;
        add_header Cache-Control "public";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/noctis-pro /etc/nginx/sites-enabled/
    
    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    sudo nginx -t
    
    # Start and enable Nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    echo "✅ Nginx configured!"
}

# Function to start services
start_services() {
    echo "🚀 Starting services..."
    
    # Enable and start services
    sudo systemctl enable noctis-web noctis-celery noctis-dicom
    sudo systemctl start noctis-web noctis-celery noctis-dicom
    
    # Restart Nginx
    sudo systemctl restart nginx
    
    echo "✅ Services started!"
}

# Function to show status
show_status() {
    echo ""
    echo "📊 Service Status:"
    echo "=================="
    
    check_service postgresql
    check_service redis-server
    check_service nginx
    check_service noctis-web
    check_service noctis-celery
    check_service noctis-dicom
    
    echo ""
    echo "🌐 Access Information:"
    echo "====================="
    echo "Web Interface: http://localhost"
    echo "Web Interface: http://$(hostname -I | awk '{print $1}')"
    echo "DICOM Receiver: $(hostname -I | awk '{print $1}'):11112"
    echo ""
    echo "📝 Useful Commands:"
    echo "=================="
    echo "View logs: sudo journalctl -u noctis-web -f"
    echo "Restart services: sudo systemctl restart noctis-web noctis-celery noctis-dicom"
    echo "Stop services: sudo systemctl stop noctis-web noctis-celery noctis-dicom"
    echo ""
}

# Main deployment function
main() {
    echo "Starting Noctis Pro deployment without Docker..."
    echo ""
    
    install_system_dependencies
    setup_postgresql
    setup_redis
    create_directories
    setup_python_environment
    create_environment_config
    setup_django
    create_systemd_services
    configure_nginx
    start_services
    show_status
    
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "Your Noctis Pro Medical Imaging System is now running!"
    echo "Please save the database credentials from /tmp/db_credentials.txt"
}

# Run main function
main "$@"