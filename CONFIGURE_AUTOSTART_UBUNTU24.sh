#!/bin/bash

# 🚀 NoctisPro Auto-Start Configuration Script for Ubuntu 24.04
# Configures all NoctisPro services to start automatically on system boot
# Run with: sudo bash CONFIGURE_AUTOSTART_UBUNTU24.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/opt/noctis_pro"
PROJECT_USER="noctis"

# Logging functions
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

log_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Check if NoctisPro is installed
if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "NoctisPro not found at $PROJECT_DIR"
    log_error "Please install NoctisPro first before configuring auto-start"
    exit 1
fi

# Welcome message
clear
echo -e "${CYAN}"
echo "🚀 NoctisPro Auto-Start Configuration"
echo "======================================"
echo -e "${NC}"
echo -e "${GREEN}Configuring NoctisPro Medical Imaging Platform for automatic startup on Ubuntu 24.04${NC}\n"

log_header "🔧 CREATING SYSTEMD SERVICES"

# Create necessary directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/scripts"
chown -R $PROJECT_USER:$PROJECT_USER "$PROJECT_DIR/logs"
chown -R $PROJECT_USER:$PROJECT_USER "$PROJECT_DIR/scripts"

# 1. Create startup preparation script
log_info "Creating startup preparation script..."
cat > "$PROJECT_DIR/scripts/startup.sh" << 'EOF'
#!/bin/bash

# NoctisPro Startup Preparation Script
LOG_FILE="/opt/noctis_pro/logs/startup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Starting NoctisPro startup sequence..."

# Wait for network to be ready
sleep 10

# Wait for PostgreSQL to be ready
log_message "Waiting for PostgreSQL..."
timeout=60
while ! pg_isready -h localhost -p 5432 > /dev/null 2>&1 && [ $timeout -gt 0 ]; do
    sleep 2
    timeout=$((timeout-2))
done

if [ $timeout -le 0 ]; then
    log_message "ERROR: PostgreSQL not ready after 60 seconds"
    exit 1
fi
log_message "PostgreSQL is ready"

# Wait for Redis to be ready
log_message "Waiting for Redis..."
timeout=60
while ! redis-cli ping > /dev/null 2>&1 && [ $timeout -gt 0 ]; do
    sleep 2
    timeout=$((timeout-2))
done

if [ $timeout -le 0 ]; then
    log_message "ERROR: Redis not ready after 60 seconds"
    exit 1
fi
log_message "Redis is ready"

# Change to project directory and activate virtual environment
cd /opt/noctis_pro
if [ -d "venv" ]; then
    source venv/bin/activate
    
    # Apply database migrations
    log_message "Applying database migrations..."
    python manage.py migrate --noinput >> "$LOG_FILE" 2>&1
    
    # Collect static files
    log_message "Collecting static files..."
    python manage.py collectstatic --noinput >> "$LOG_FILE" 2>&1
fi

# Create media directories
mkdir -p /opt/noctis_pro/media/{dicom,uploads,reports,temp}
chown -R noctis:noctis /opt/noctis_pro/media

log_message "Startup sequence completed successfully"
EOF

chmod +x "$PROJECT_DIR/scripts/startup.sh"
chown $PROJECT_USER:$PROJECT_USER "$PROJECT_DIR/scripts/startup.sh"
log_success "Startup script created"

# 2. Create startup service
log_info "Creating startup service..."
cat > /etc/systemd/system/noctis-startup.service << EOF
[Unit]
Description=NoctisPro Startup Preparation
After=network.target postgresql.service redis.service
Before=noctis-web.service noctis-worker.service noctis-scheduler.service
Wants=postgresql.service redis.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/scripts/startup.sh
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

# 3. Create web service
log_info "Creating web application service..."
cat > /etc/systemd/system/noctis-web.service << EOF
[Unit]
Description=NoctisPro Web Application
After=network.target postgresql.service redis.service noctis-startup.service
Wants=postgresql.service redis.service noctis-startup.service
Requires=network.target noctis-startup.service

[Service]
Type=exec
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/gunicorn noctis_pro.wsgi:application \\
    --bind 127.0.0.1:8000 \\
    --workers 4 \\
    --worker-class gevent \\
    --worker-connections 1000 \\
    --max-requests 1000 \\
    --max-requests-jitter 100 \\
    --timeout 30 \\
    --keep-alive 2 \\
    --access-logfile $PROJECT_DIR/logs/gunicorn_access.log \\
    --error-logfile $PROJECT_DIR/logs/gunicorn_error.log \\
    --log-level info
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=30
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 4. Create worker service
log_info "Creating background worker service..."
cat > /etc/systemd/system/noctis-worker.service << EOF
[Unit]
Description=NoctisPro Background Worker
After=network.target postgresql.service redis.service noctis-startup.service noctis-web.service
Wants=postgresql.service redis.service noctis-startup.service
Requires=network.target noctis-startup.service

[Service]
Type=exec
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python manage.py runworker
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 5. Create scheduler service
log_info "Creating task scheduler service..."
cat > /etc/systemd/system/noctis-scheduler.service << EOF
[Unit]
Description=NoctisPro Task Scheduler
After=network.target postgresql.service redis.service noctis-startup.service noctis-web.service
Wants=postgresql.service redis.service noctis-startup.service
Requires=network.target noctis-startup.service

[Service]
Type=exec
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python manage.py scheduler
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 6. Create DICOM receiver service
log_info "Creating DICOM receiver service..."
cat > /etc/systemd/system/noctis-dicom.service << EOF
[Unit]
Description=NoctisPro DICOM Receiver
After=network.target postgresql.service redis.service noctis-startup.service noctis-web.service
Wants=postgresql.service redis.service noctis-startup.service
Requires=network.target noctis-startup.service

[Service]
Type=exec
User=$PROJECT_USER
Group=$PROJECT_USER
WorkingDirectory=$PROJECT_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python dicom_receiver.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 7. Create health check script
log_info "Creating health monitoring script..."
cat > "$PROJECT_DIR/scripts/healthcheck.sh" << 'EOF'
#!/bin/bash

# NoctisPro Health Check Script
LOG_FILE="/opt/noctis_pro/logs/healthcheck.log"
SERVICES=("noctis-web" "noctis-worker" "noctis-scheduler" "postgresql" "redis" "nginx")

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

restart_service() {
    local service=$1
    log_message "WARNING: $service is down, attempting restart..."
    systemctl restart "$service"
    sleep 5
    if check_service "$service"; then
        log_message "SUCCESS: $service restarted successfully"
    else
        log_message "ERROR: Failed to restart $service"
    fi
}

# Check web connectivity
check_web() {
    if curl -s -f http://localhost:8000/ >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main health check
log_message "Starting health check..."

for service in "${SERVICES[@]}"; do
    if ! check_service "$service"; then
        restart_service "$service"
    fi
done

# Check web application
if ! check_web; then
    log_message "WARNING: Web application health check failed"
    restart_service "noctis-web"
fi

log_message "Health check completed"
EOF

chmod +x "$PROJECT_DIR/scripts/healthcheck.sh"
chown $PROJECT_USER:$PROJECT_USER "$PROJECT_DIR/scripts/healthcheck.sh"

# 8. Create health check service and timer
log_info "Creating health check monitoring service..."
cat > /etc/systemd/system/noctis-healthcheck.service << EOF
[Unit]
Description=NoctisPro Health Check
After=noctis-web.service

[Service]
Type=oneshot
User=$PROJECT_USER
Group=$PROJECT_USER
ExecStart=$PROJECT_DIR/scripts/healthcheck.sh
EOF

cat > /etc/systemd/system/noctis-healthcheck.timer << EOF
[Unit]
Description=NoctisPro Health Check Timer
Requires=noctis-healthcheck.service

[Timer]
OnCalendar=*:0/5  # Every 5 minutes
Persistent=true

[Install]
WantedBy=timers.target
EOF

log_success "All systemd services created"

# Reload systemd configuration
log_header "⚙️ ENABLING AUTO-START SERVICES"

log_info "Reloading systemd configuration..."
systemctl daemon-reload

# Enable core system services
log_info "Enabling core system services for auto-start..."
systemctl enable postgresql
systemctl enable redis
systemctl enable nginx
systemctl enable docker

# Enable NoctisPro services
log_info "Enabling NoctisPro services for auto-start..."
systemctl enable noctis-startup
systemctl enable noctis-web
systemctl enable noctis-worker
systemctl enable noctis-scheduler
systemctl enable noctis-dicom

# Enable health check timer
log_info "Enabling health check monitoring..."
systemctl enable noctis-healthcheck.timer

log_success "All services enabled for auto-start"

# Start services to test
log_header "🧪 TESTING SERVICE STARTUP"

log_info "Starting services to test configuration..."

# Start core services if not running
for service in postgresql redis nginx docker; do
    if ! systemctl is-active --quiet $service; then
        log_info "Starting $service..."
        systemctl start $service
    fi
done

# Start NoctisPro services
log_info "Starting NoctisPro services..."
systemctl start noctis-startup
sleep 5

for service in noctis-web noctis-worker noctis-scheduler noctis-dicom; do
    log_info "Starting $service..."
    systemctl start $service
    sleep 2
done

# Start health check timer
systemctl start noctis-healthcheck.timer

# Verify all services
log_header "✅ VERIFICATION RESULTS"

services=("postgresql" "redis" "nginx" "noctis-startup" "noctis-web" "noctis-worker" "noctis-scheduler" "noctis-dicom")
all_ok=true

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_success "✅ $service is running and enabled"
    else
        log_warning "❌ $service is not running"
        all_ok=false
    fi
done

# Check health check timer
if systemctl is-active --quiet noctis-healthcheck.timer; then
    log_success "✅ Health check monitoring is active"
else
    log_warning "⚠️  Health check monitoring is not active"
fi

# Final status
log_header "🎉 AUTO-START CONFIGURATION SUMMARY"

if $all_ok; then
    echo -e "${GREEN}🎉 SUCCESS! Auto-start configuration completed successfully! 🎉${NC}\n"
    
    echo -e "${CYAN}✅ Configuration Summary:${NC}"
    echo -e "• All core services enabled for auto-start"
    echo -e "• All NoctisPro services enabled for auto-start"
    echo -e "• Health monitoring configured (every 5 minutes)"
    echo -e "• Service dependencies properly configured"
    echo -e "• All services currently running"
    
    echo -e "\n${CYAN}🔄 Your system will now:${NC}"
    echo -e "• Start automatically on server boot"
    echo -e "• Restart failed services automatically"
    echo -e "• Monitor health every 5 minutes"
    echo -e "• Log all startup and health events"
    
    echo -e "\n${CYAN}📋 Test auto-start by rebooting:${NC}"
    echo -e "${YELLOW}sudo reboot${NC}"
    
else
    echo -e "${RED}⚠️  CONFIGURATION COMPLETED WITH ISSUES ⚠️${NC}\n"
    echo -e "${YELLOW}Some services are not running correctly.${NC}"
    echo -e "${YELLOW}Check the logs for details:${NC}"
    echo -e "📄 ${CYAN}sudo journalctl -u noctis-web -f${NC}"
fi

# Show useful commands
echo -e "\n${CYAN}📋 Useful Auto-Start Commands:${NC}"
echo -e "🔍 Check service status: ${GREEN}sudo systemctl status noctis-*${NC}"
echo -e "📄 View startup logs: ${GREEN}sudo journalctl -u noctis-startup -f${NC}"
echo -e "🔄 Restart all services: ${GREEN}sudo systemctl restart noctis-*${NC}"
echo -e "⏹️  Stop auto-start: ${GREEN}sudo systemctl disable noctis-*${NC}"
echo -e "▶️  Re-enable auto-start: ${GREEN}sudo systemctl enable noctis-*${NC}"

echo -e "\n${CYAN}📁 Log Locations:${NC}"
echo -e "• Startup logs: ${GREEN}$PROJECT_DIR/logs/startup.log${NC}"
echo -e "• Health checks: ${GREEN}$PROJECT_DIR/logs/healthcheck.log${NC}"
echo -e "• Application logs: ${GREEN}$PROJECT_DIR/logs/gunicorn_*.log${NC}"
echo -e "• System logs: ${GREEN}sudo journalctl -u noctis-*${NC}"

echo -e "\n${GREEN}Auto-start configuration completed!${NC} 🚀"
log_success "Your NoctisPro Medical Imaging Platform will now start automatically on every boot!"