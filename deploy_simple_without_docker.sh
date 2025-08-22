#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "🏥 NOCTIS PRO MEDICAL IMAGING SYSTEM - SIMPLE NON-DOCKER DEPLOYMENT 🏥"
echo "════════════════════════════════════════════════════════════"
echo ""

# Exit on any error
set -e

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to start PostgreSQL manually
start_postgresql() {
    echo "🗄️  Starting PostgreSQL..."
    
    # Initialize database if needed
    if [ ! -d "/var/lib/postgresql/16/main" ]; then
        sudo -u postgres /usr/lib/postgresql/16/bin/initdb -D /var/lib/postgresql/16/main
    fi
    
    # Start PostgreSQL
    sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main -l /var/log/postgresql/postgresql-16-main.log start || true
    
    # Wait for PostgreSQL to start
    sleep 5
    
    echo "✅ PostgreSQL started!"
}

# Function to start Redis manually
start_redis() {
    echo "📊 Starting Redis..."
    
    # Start Redis in background
    redis-server --daemonize yes --logfile /var/log/redis/redis-server.log || true
    
    echo "✅ Redis started!"
}

# Function to setup PostgreSQL database
setup_postgresql_db() {
    echo "🗄️  Setting up PostgreSQL database..."
    
    # Create database and user
    DB_NAME="noctis_pro"
    DB_USER="noctis_user"
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql << EOF || true
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
ALTER ROLE ${DB_USER} SET client_encoding TO 'utf8';
ALTER ROLE ${DB_USER} SET default_transaction_isolation TO 'read committed';
ALTER ROLE ${DB_USER} SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
\q
EOF

    echo "✅ PostgreSQL database setup complete!"
    echo "Database: ${DB_NAME}"
    echo "User: ${DB_USER}"
    echo "Password: ${DB_PASSWORD}"
    
    # Save database credentials
    echo "DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}" > /tmp/db_credentials.txt
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
    mkdir -p ./data/{media,staticfiles,logs,dicom_storage,backups}
    mkdir -p ./logs
    
    # Set permissions
    chmod -R 755 ./data
    chmod -R 755 ./logs
    
    echo "✅ Directory structure created!"
}

# Function to create environment configuration
create_environment_config() {
    echo "⚙️  Creating environment configuration..."
    
    # Generate secret key
    SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    # Get database URL
    DB_URL=$(cat /tmp/db_credentials.txt)
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}' | tr -d '[:space:]')
    
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
ALLOWED_HOSTS=localhost,127.0.0.1,${SERVER_IP}
DOMAIN_NAME=

# Media and Static Files
MEDIA_ROOT=$(pwd)/data/media
STATIC_ROOT=$(pwd)/data/staticfiles

# DICOM Configuration
DICOM_STORAGE_PATH=$(pwd)/data/dicom_storage
DICOM_PORT=11112

# Logging
LOG_LEVEL=INFO
LOG_FILE=$(pwd)/logs/noctis.log

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

# Function to start Nginx
start_nginx() {
    echo "🌐 Starting Nginx..."
    
    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/noctis-pro > /dev/null << EOF
server {
    listen 80;
    server_name localhost $(hostname -I | awk '{print $1}');
    
    client_max_body_size 100M;
    
    location /static/ {
        alias $(pwd)/data/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias $(pwd)/data/media/;
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
    
    # Start Nginx
    sudo nginx || sudo service nginx start || true
    
    echo "✅ Nginx started!"
}

# Function to create startup script
create_startup_script() {
    echo "📝 Creating startup script..."
    
    cat > start_noctis.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Noctis Pro Medical Imaging System..."

# Change to application directory
cd "$(dirname "$0")"

# Load environment variables
set -a
source .env.production
set +a

# Activate virtual environment
source venv/bin/activate

# Start services in background
echo "📊 Starting Redis..."
redis-server --daemonize yes --logfile logs/redis.log || echo "Redis already running"

echo "🗄️  Starting PostgreSQL..."
sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main -l logs/postgresql.log start || echo "PostgreSQL already running"

sleep 3

echo "🌐 Starting Django web server..."
nohup gunicorn --bind 127.0.0.1:8000 --workers 3 --worker-class gthread --threads 2 --timeout 120 noctis_pro.wsgi:application > logs/gunicorn.log 2>&1 &

echo "⚙️  Starting Celery worker..."
nohup celery -A noctis_pro worker --loglevel=info > logs/celery.log 2>&1 &

echo "📡 Starting DICOM receiver..."
nohup python dicom_receiver.py > logs/dicom.log 2>&1 &

echo "🌐 Starting Nginx..."
sudo nginx || sudo service nginx start

echo ""
echo "✅ Noctis Pro is now running!"
echo ""
echo "🌐 Access Information:"
echo "====================="
echo "Web Interface: http://localhost"
echo "Web Interface: http://$(hostname -I | awk '{print $1}')"
echo "DICOM Receiver: $(hostname -I | awk '{print $1}'):11112"
echo ""
echo "👤 Admin Login:"
echo "==============="
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "📝 Log files are in the logs/ directory"
echo "🛑 To stop: ./stop_noctis.sh"
EOF

    chmod +x start_noctis.sh
    
    # Create stop script
    cat > stop_noctis.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Noctis Pro Medical Imaging System..."

# Kill Django/Gunicorn
pkill -f gunicorn || true

# Kill Celery
pkill -f celery || true

# Kill DICOM receiver
pkill -f dicom_receiver.py || true

# Stop Nginx
sudo nginx -s quit || sudo service nginx stop || true

# Stop Redis
redis-cli shutdown || true

# Stop PostgreSQL
sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /var/lib/postgresql/16/main stop || true

echo "✅ Noctis Pro stopped!"
EOF

    chmod +x stop_noctis.sh
    
    echo "✅ Startup scripts created!"
}

# Main deployment function
main() {
    echo "Starting Noctis Pro deployment without Docker (Simple Mode)..."
    echo ""
    
    # Check if we have the required dependencies already installed
    if ! command_exists python3; then
        echo "❌ Python3 is required. Please install it first."
        exit 1
    fi
    
    if ! command_exists pip3; then
        echo "❌ pip3 is required. Please install it first."
        exit 1
    fi
    
    # Try to start existing services
    start_redis
    start_postgresql
    
    # Setup database if needed
    setup_postgresql_db
    
    # Create directories and environment
    create_directories
    setup_python_environment
    create_environment_config
    setup_django
    
    # Setup web server
    start_nginx
    
    # Create startup scripts
    create_startup_script
    
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "🚀 To start the system, run: ./start_noctis.sh"
    echo "🛑 To stop the system, run: ./stop_noctis.sh"
    echo ""
    echo "Your Noctis Pro Medical Imaging System is ready!"
    echo "Please save the database credentials from /tmp/db_credentials.txt"
}

# Run main function
main "$@"