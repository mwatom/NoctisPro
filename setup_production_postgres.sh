#!/bin/bash

# 🏥 PostgreSQL Production Setup for NoctisPro
# This script configures PostgreSQL for optimal production performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (sudo)"
fi

# Source environment variables
if [ -f ".env.production.fixed" ]; then
    source .env.production.fixed
    log "✓ Loaded production environment variables"
else
    error "Production environment file not found. Please run this from the project root."
fi

log "🐘 Setting up PostgreSQL for NoctisPro Production..."

# Install PostgreSQL if not already installed
if ! command -v psql &> /dev/null; then
    log "📦 Installing PostgreSQL..."
    apt-get update
    apt-get install -y postgresql postgresql-contrib postgresql-client
    systemctl enable postgresql
    systemctl start postgresql
else
    log "✓ PostgreSQL is already installed"
fi

# Check PostgreSQL service status
if ! systemctl is-active --quiet postgresql; then
    log "🔄 Starting PostgreSQL service..."
    systemctl start postgresql
fi

# Get PostgreSQL version and data directory
PG_VERSION=$(psql --version | awk '{print $3}' | sed 's/\..*//')
PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONFIG_DIR="/etc/postgresql/${PG_VERSION}/main"

log "📍 PostgreSQL version: ${PG_VERSION}"
log "📍 Data directory: ${PG_DATA_DIR}"
log "📍 Config directory: ${PG_CONFIG_DIR}"

# Backup original configuration files
log "💾 Backing up original PostgreSQL configuration..."
cp "${PG_CONFIG_DIR}/postgresql.conf" "${PG_CONFIG_DIR}/postgresql.conf.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
cp "${PG_CONFIG_DIR}/pg_hba.conf" "${PG_CONFIG_DIR}/pg_hba.conf.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Copy our optimized configuration files
log "⚙️  Applying optimized PostgreSQL configuration..."
cp "deployment/postgres/postgresql.conf.production" "${PG_CONFIG_DIR}/postgresql.conf"
cp "deployment/postgres/pg_hba.conf.production" "${PG_CONFIG_DIR}/pg_hba.conf"

# Set proper ownership and permissions
chown postgres:postgres "${PG_CONFIG_DIR}/postgresql.conf"
chown postgres:postgres "${PG_CONFIG_DIR}/pg_hba.conf"
chmod 644 "${PG_CONFIG_DIR}/postgresql.conf"
chmod 640 "${PG_CONFIG_DIR}/pg_hba.conf"

# Create the database and user
log "👤 Creating database and user..."

# Switch to postgres user and create database
sudo -u postgres psql -c "CREATE DATABASE ${POSTGRES_DB:-noctisprodb};" 2>/dev/null || warning "Database ${POSTGRES_DB:-noctisprodb} already exists"

# Create user with secure password
sudo -u postgres psql -c "CREATE USER ${POSTGRES_USER:-noctispro} WITH PASSWORD '${POSTGRES_PASSWORD}';" 2>/dev/null || warning "User ${POSTGRES_USER:-noctispro} already exists"

# Grant privileges
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB:-noctisprodb} TO ${POSTGRES_USER:-noctispro};"
sudo -u postgres psql -c "ALTER USER ${POSTGRES_USER:-noctispro} CREATEDB;"

# Apply initialization script
if [ -f "deployment/postgres/init.sql" ]; then
    log "🔧 Applying database initialization script..."
    sudo -u postgres psql -d "${POSTGRES_DB:-noctisprodb}" -f "deployment/postgres/init.sql"
fi

# Create logs directory
mkdir -p /var/log/postgresql
chown postgres:postgres /var/log/postgresql

# Restart PostgreSQL to apply configuration changes
log "🔄 Restarting PostgreSQL with new configuration..."
systemctl restart postgresql

# Wait for PostgreSQL to be ready
log "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Test connection
log "🔍 Testing database connection..."
if sudo -u postgres psql -d "${POSTGRES_DB:-noctisprodb}" -c "SELECT version();" > /dev/null 2>&1; then
    log "✅ Database connection successful!"
else
    error "❌ Database connection failed!"
fi

# Update environment file to use PostgreSQL
log "📝 Updating environment configuration..."
sed -i 's/USE_SQLITE=True/USE_SQLITE=False/' .env.production 2>/dev/null || true

# Create systemd service for auto-restart
log "🔧 Setting up PostgreSQL monitoring..."
cat > /etc/systemd/system/noctis-postgres-monitor.service << EOF
[Unit]
Description=NoctisPro PostgreSQL Monitor
After=postgresql.service
Requires=postgresql.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'systemctl is-active --quiet postgresql || systemctl restart postgresql'
User=root

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/noctis-postgres-monitor.timer << EOF
[Unit]
Description=NoctisPro PostgreSQL Monitor Timer
Requires=noctis-postgres-monitor.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable noctis-postgres-monitor.timer
systemctl start noctis-postgres-monitor.timer

# Display connection information
log "📋 PostgreSQL Production Setup Complete!"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏥 NoctisPro PostgreSQL Production Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "📊 Database Information:"
echo "  • Database Name: ${POSTGRES_DB:-noctisprodb}"
echo "  • Database User: ${POSTGRES_USER:-noctispro}"
echo "  • Host: ${POSTGRES_HOST:-localhost}"
echo "  • Port: ${POSTGRES_PORT:-5432}"
echo
echo "🔧 Configuration Files:"
echo "  • PostgreSQL Config: ${PG_CONFIG_DIR}/postgresql.conf"
echo "  • Authentication: ${PG_CONFIG_DIR}/pg_hba.conf"
echo "  • Data Directory: ${PG_DATA_DIR}"
echo
echo "📝 Connection Command:"
echo "  psql -U ${POSTGRES_USER:-noctispro} -d ${POSTGRES_DB:-noctisprodb} -h ${POSTGRES_HOST:-localhost} -p ${POSTGRES_PORT:-5432}"
echo
echo "🔍 Service Status:"
systemctl status postgresql --no-pager -l
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "✅ PostgreSQL is now ready for production use!"
echo "🔧 Next steps:"
echo "  1. Update your .env.production file to use the fixed configuration"
echo "  2. Run Django migrations: python manage.py migrate --settings=noctis_pro.settings_production"
echo "  3. Test the application with the new database configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"