#!/bin/bash
# Production PostgreSQL Setup Script for NoctisPro PACS
# This script sets up the complete production environment with PostgreSQL

set -e

echo "🚀 NoctisPro PACS - Production PostgreSQL Setup"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root for system package installation
if [[ $EUID -ne 0 ]]; then
    echo "This script needs to install system packages. Please run with sudo:"
    echo "sudo bash $0"
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set default values
DB_NAME=${DB_NAME:-noctis_pro}
DB_USER=${DB_USER:-noctis_user}
DB_PASSWORD=${DB_PASSWORD:-QGO5IebYph3b1V2InOhv4OBLytpWCvOXoGevBs8M-cY}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-NoctisAdmin2024!}

log "🔧 Installing system dependencies..."

# Update package list
apt-get update

# Install PostgreSQL and related packages
apt-get install -y \
    postgresql \
    postgresql-contrib \
    python3-psycopg2 \
    python3-venv \
    python3-pip \
    python3-dev \
    libpq-dev \
    build-essential \
    redis-server \
    nginx

log "🐘 Setting up PostgreSQL..."

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create database user and database
sudo -u postgres psql << EOF
-- Drop existing user and database if they exist
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;

-- Create user
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Create database
CREATE DATABASE $DB_NAME OWNER $DB_USER;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
ALTER USER $DB_USER SUPERUSER;

-- Quit
\q
EOF

log "🔧 Applying PostgreSQL optimizations..."

# Apply the initialization script if it exists
if [ -f "deployment/postgres/init.sql" ]; then
    sudo -u postgres psql -d $DB_NAME -f deployment/postgres/init.sql
    log "PostgreSQL optimization script applied"
fi

# Configure PostgreSQL for production
PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oE '[0-9]+\.[0-9]+' | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"

if [ -f "$PG_CONFIG_DIR/postgresql.conf" ]; then
    # Backup original configuration
    cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup"
    
    # Apply production settings
    cat >> "$PG_CONFIG_DIR/postgresql.conf" << EOF

# NoctisPro Production Settings
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
max_connections = 200
EOF

    log "PostgreSQL production configuration applied"
fi

# Restart PostgreSQL
systemctl restart postgresql

log "🧪 Testing PostgreSQL connection..."
PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT version();" || {
    error "PostgreSQL connection test failed!"
}

log "🔧 Setting up Python environment..."

# Create virtual environment for the application
if [ ! -d "venv_optimized" ]; then
    python3 -m venv venv_optimized
fi

# Activate virtual environment
source venv_optimized/bin/activate

# Upgrade pip
pip install --upgrade pip

log "📦 Installing Python requirements..."

# Install requirements
pip install -r requirements.txt || {
    warn "Main requirements installation had issues, trying minimal requirements..."
    pip install -r requirements.minimal.txt || {
        error "Failed to install Python requirements!"
    }
}

log "🔧 Setting up Django..."

# Load environment variables
export $(grep -v '^#' .env | xargs)

# Create necessary directories
mkdir -p logs
mkdir -p media/dicom
mkdir -p staticfiles

# Run Django setup
python manage.py collectstatic --noinput
python manage.py makemigrations
python manage.py migrate

# Create superuser
python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', '$ADMIN_PASSWORD')
    print('✅ Superuser created: admin/$ADMIN_PASSWORD')
else:
    print('ℹ️  Superuser already exists')
"

log "🔧 Setting up Redis..."
systemctl start redis-server
systemctl enable redis-server

log "🔧 Setting up Nginx (basic configuration)..."
systemctl start nginx
systemctl enable nginx

# Create basic Nginx configuration
cat > /etc/nginx/sites-available/noctispro << EOF
server {
    listen 80;
    server_name localhost;
    
    location /static/ {
        alias /workspace/staticfiles/;
    }
    
    location /media/ {
        alias /workspace/media/;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t && systemctl reload nginx

log "🧪 Running system tests..."

# Test database connection
PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM django_migrations;" || {
    error "Django database test failed!"
}

# Test Redis connection
redis-cli ping || {
    warn "Redis connection test failed, but continuing..."
}

echo ""
echo "✅ Production PostgreSQL setup completed successfully!"
echo "=============================================="
echo "📊 Database: $DB_NAME"
echo "👤 User: $DB_USER"
echo "🏠 Host: localhost:5432"
echo "🔐 Admin User: admin"
echo "🔑 Admin Password: $ADMIN_PASSWORD"
echo ""
echo "🚀 To start the application:"
echo "   source venv_optimized/bin/activate"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
echo "🌐 Or use the deployment script:"
echo "   bash deploy_master.sh"
echo ""
echo "🔧 Services Status:"
systemctl is-active postgresql && echo "   ✅ PostgreSQL: Running" || echo "   ❌ PostgreSQL: Not running"
systemctl is-active redis-server && echo "   ✅ Redis: Running" || echo "   ❌ Redis: Not running"
systemctl is-active nginx && echo "   ✅ Nginx: Running" || echo "   ❌ Nginx: Not running"