# 🚀 Ubuntu 24.04 Startup Configuration - NoctisPro

> **Auto-Start Configuration**: Complete guide to configure NoctisPro Medical Imaging Platform to start automatically on Ubuntu Server 24.04 boot

## 📋 STARTUP CONFIGURATION OVERVIEW

This guide ensures that your NoctisPro system starts automatically when your Ubuntu server boots up, including:
- **All NoctisPro services** (web, worker, scheduler)
- **Database services** (PostgreSQL)
- **Cache services** (Redis)
- **Web server** (Nginx)
- **Docker services** (if using containerized deployment)
- **Background services** (DICOM receiver, print services)

---

## 🔧 SYSTEMD SERVICE CONFIGURATION

### 1. Core NoctisPro Services

Ubuntu 24.04 uses systemd for service management. Here's how to configure each service:

#### 1.1 Main Web Application Service
```bash
# Create the main web service
sudo nano /etc/systemd/system/noctis-web.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Web Application
After=network.target postgresql.service redis.service
Wants=postgresql.service redis.service
Requires=network.target

[Service]
Type=exec
User=noctis
Group=noctis
WorkingDirectory=/opt/noctis_pro
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=/opt/noctis_pro
ExecStart=/opt/noctis_pro/venv/bin/gunicorn noctis_pro.wsgi:application \
    --bind 127.0.0.1:8000 \
    --workers 4 \
    --worker-class gevent \
    --worker-connections 1000 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --timeout 30 \
    --keep-alive 2 \
    --access-logfile /opt/noctis_pro/logs/gunicorn_access.log \
    --error-logfile /opt/noctis_pro/logs/gunicorn_error.log \
    --log-level info
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
TimeoutStopSec=30
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### 1.2 Background Worker Service
```bash
# Create the worker service
sudo nano /etc/systemd/system/noctis-worker.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Background Worker
After=network.target postgresql.service redis.service noctis-web.service
Wants=postgresql.service redis.service
Requires=network.target

[Service]
Type=exec
User=noctis
Group=noctis
WorkingDirectory=/opt/noctis_pro
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=/opt/noctis_pro
ExecStart=/opt/noctis_pro/venv/bin/python manage.py runworker
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

#### 1.3 Task Scheduler Service
```bash
# Create the scheduler service
sudo nano /etc/systemd/system/noctis-scheduler.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Task Scheduler
After=network.target postgresql.service redis.service noctis-web.service
Wants=postgresql.service redis.service
Requires=network.target

[Service]
Type=exec
User=noctis
Group=noctis
WorkingDirectory=/opt/noctis_pro
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=/opt/noctis_pro
ExecStart=/opt/noctis_pro/venv/bin/python manage.py scheduler
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

#### 1.4 DICOM Receiver Service
```bash
# Create the DICOM receiver service
sudo nano /etc/systemd/system/noctis-dicom.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro DICOM Receiver
After=network.target postgresql.service redis.service noctis-web.service
Wants=postgresql.service redis.service
Requires=network.target

[Service]
Type=exec
User=noctis
Group=noctis
WorkingDirectory=/opt/noctis_pro
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings.production
Environment=PYTHONPATH=/opt/noctis_pro
ExecStart=/opt/noctis_pro/venv/bin/python dicom_receiver.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 2. Enable All Services
```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Enable all NoctisPro services to start on boot
sudo systemctl enable noctis-web
sudo systemctl enable noctis-worker
sudo systemctl enable noctis-scheduler
sudo systemctl enable noctis-dicom

# Enable supporting services
sudo systemctl enable postgresql
sudo systemctl enable redis
sudo systemctl enable nginx
sudo systemctl enable docker

# Start all services now
sudo systemctl start noctis-web
sudo systemctl start noctis-worker
sudo systemctl start noctis-scheduler
sudo systemctl start noctis-dicom
```

---

## 🐳 DOCKER STARTUP CONFIGURATION

### If Using Docker Deployment

#### 1. Docker Compose Auto-Start Service
```bash
# Create Docker Compose service
sudo nano /etc/systemd/system/noctis-docker.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Docker Compose
Requires=docker.service
After=docker.service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=noctis
Group=docker
WorkingDirectory=/opt/noctis_pro
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

#### 2. Enable Docker Service
```bash
# Enable Docker auto-start
sudo systemctl enable docker
sudo systemctl enable noctis-docker

# Start Docker service now
sudo systemctl start noctis-docker
```

---

## 📁 STARTUP SCRIPTS AND DIRECTORIES

### 1. Create Startup Script
```bash
# Create startup script
sudo nano /opt/noctis_pro/scripts/startup.sh
```

Add this content:
```bash
#!/bin/bash

# NoctisPro Startup Script
# This script ensures all components are ready before starting services

LOG_FILE="/opt/noctis_pro/logs/startup.log"
mkdir -p /opt/noctis_pro/logs

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Starting NoctisPro startup sequence..."

# Wait for network to be ready
sleep 10

# Wait for PostgreSQL to be ready
log_message "Waiting for PostgreSQL..."
while ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; do
    sleep 2
done
log_message "PostgreSQL is ready"

# Wait for Redis to be ready
log_message "Waiting for Redis..."
while ! redis-cli ping > /dev/null 2>&1; do
    sleep 2
done
log_message "Redis is ready"

# Ensure database migrations are applied
log_message "Applying database migrations..."
cd /opt/noctis_pro
source venv/bin/activate
python manage.py migrate --noinput >> "$LOG_FILE" 2>&1

# Collect static files
log_message "Collecting static files..."
python manage.py collectstatic --noinput >> "$LOG_FILE" 2>&1

# Create media directories
mkdir -p /opt/noctis_pro/media/dicom
mkdir -p /opt/noctis_pro/media/uploads
mkdir -p /opt/noctis_pro/media/reports
chown -R noctis:noctis /opt/noctis_pro/media

log_message "Startup sequence completed successfully"
```

Make it executable:
```bash
sudo chmod +x /opt/noctis_pro/scripts/startup.sh
sudo chown noctis:noctis /opt/noctis_pro/scripts/startup.sh
```

### 2. Create Startup Service
```bash
# Create startup service
sudo nano /etc/systemd/system/noctis-startup.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Startup Preparation
After=network.target postgresql.service redis.service
Before=noctis-web.service noctis-worker.service noctis-scheduler.service
Wants=postgresql.service redis.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=noctis
Group=noctis
ExecStart=/opt/noctis_pro/scripts/startup.sh
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
```

Enable the startup service:
```bash
sudo systemctl enable noctis-startup
```

---

## 🔄 SERVICE DEPENDENCIES AND ORDERING

### Update Service Dependencies

#### 1. Update Web Service Dependencies
```bash
# Edit the web service to depend on startup service
sudo nano /etc/systemd/system/noctis-web.service
```

Update the `[Unit]` section:
```ini
[Unit]
Description=NoctisPro Web Application
After=network.target postgresql.service redis.service noctis-startup.service
Wants=postgresql.service redis.service noctis-startup.service
Requires=network.target noctis-startup.service
```

#### 2. Update Worker and Scheduler Services
Apply similar dependencies to worker and scheduler services:
```bash
# Update both services to include noctis-startup.service dependency
sudo sed -i 's/After=network.target postgresql.service redis.service noctis-web.service/After=network.target postgresql.service redis.service noctis-startup.service noctis-web.service/' /etc/systemd/system/noctis-worker.service
sudo sed -i 's/After=network.target postgresql.service redis.service noctis-web.service/After=network.target postgresql.service redis.service noctis-startup.service noctis-web.service/' /etc/systemd/system/noctis-scheduler.service
```

---

## 🔍 HEALTH CHECK AND MONITORING

### 1. Create Health Check Script
```bash
# Create health check script
sudo nano /opt/noctis_pro/scripts/healthcheck.sh
```

Add this content:
```bash
#!/bin/bash

# NoctisPro Health Check Script
# Monitors service health and restarts if needed

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
    if curl -s -f http://localhost:8000/health/ >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main health check loop
log_message "Starting health check..."

for service in "${SERVICES[@]}"; do
    if ! check_service "$service"; then
        restart_service "$service"
    fi
done

# Check web application health
if ! check_web; then
    log_message "WARNING: Web application health check failed"
    restart_service "noctis-web"
fi

log_message "Health check completed"
```

Make it executable:
```bash
sudo chmod +x /opt/noctis_pro/scripts/healthcheck.sh
sudo chown noctis:noctis /opt/noctis_pro/scripts/healthcheck.sh
```

### 2. Create Health Check Service
```bash
# Create health check timer service
sudo nano /etc/systemd/system/noctis-healthcheck.service
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Health Check
After=noctis-web.service

[Service]
Type=oneshot
User=noctis
Group=noctis
ExecStart=/opt/noctis_pro/scripts/healthcheck.sh
```

### 3. Create Health Check Timer
```bash
# Create timer for regular health checks
sudo nano /etc/systemd/system/noctis-healthcheck.timer
```

Add this configuration:
```ini
[Unit]
Description=NoctisPro Health Check Timer
Requires=noctis-healthcheck.service

[Timer]
OnCalendar=*:0/5  # Every 5 minutes
Persistent=true

[Install]
WantedBy=timers.target
```

Enable the health check timer:
```bash
sudo systemctl enable noctis-healthcheck.timer
sudo systemctl start noctis-healthcheck.timer
```

---

## 🛠️ AUTO-START CONFIGURATION SCRIPT

### Complete Auto-Start Setup Script
```bash
# Create complete auto-start configuration script
sudo nano /opt/noctis_pro/configure_startup.sh
```

Add this content:
```bash
#!/bin/bash

# NoctisPro Auto-Start Configuration Script
# Configures all services to start automatically on Ubuntu 24.04

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo -e "${GREEN}Configuring NoctisPro Auto-Start Services...${NC}\n"

# Create log directory
mkdir -p /opt/noctis_pro/logs
chown noctis:noctis /opt/noctis_pro/logs

# Reload systemd
log_info "Reloading systemd configuration..."
systemctl daemon-reload

# Enable core system services
log_info "Enabling core system services..."
systemctl enable postgresql
systemctl enable redis
systemctl enable nginx
systemctl enable docker

# Enable NoctisPro services
log_info "Enabling NoctisPro services..."
systemctl enable noctis-startup
systemctl enable noctis-web
systemctl enable noctis-worker
systemctl enable noctis-scheduler
systemctl enable noctis-dicom

# Enable health check timer
log_info "Enabling health check monitoring..."
systemctl enable noctis-healthcheck.timer

# Start services if not running
log_info "Starting services..."
systemctl start postgresql
systemctl start redis
systemctl start nginx
systemctl start docker

# Start NoctisPro services
systemctl start noctis-startup
sleep 5
systemctl start noctis-web
systemctl start noctis-worker
systemctl start noctis-scheduler
systemctl start noctis-dicom

# Start health check timer
systemctl start noctis-healthcheck.timer

# Verify all services are running
log_info "Verifying service status..."
services=("postgresql" "redis" "nginx" "noctis-web" "noctis-worker" "noctis-scheduler")

all_ok=true
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_success "✅ $service is running"
    else
        log_warning "❌ $service is not running"
        all_ok=false
    fi
done

if $all_ok; then
    log_success "🎉 All services are configured for auto-start and are currently running!"
else
    log_warning "⚠️  Some services are not running. Check logs for details."
fi

# Display service status
echo -e "\n${BLUE}Service Status Summary:${NC}"
systemctl status noctis-web --no-pager -l | head -3
systemctl status noctis-worker --no-pager -l | head -3
systemctl status noctis-scheduler --no-pager -l | head -3

echo -e "\n${GREEN}Auto-start configuration completed!${NC}"
echo -e "${BLUE}Your NoctisPro system will now start automatically on server boot.${NC}"
```

Make it executable and run it:
```bash
sudo chmod +x /opt/noctis_pro/configure_startup.sh
sudo /opt/noctis_pro/configure_startup.sh
```

---

## 🧪 TESTING AUTO-START

### 1. Test Service Dependencies
```bash
# Test service startup order
sudo systemctl list-dependencies noctis-web.service
```

### 2. Test Reboot Scenario
```bash
# Test that services start after reboot
sudo reboot

# After reboot, check all services
sudo systemctl status noctis-*
sudo systemctl status postgresql redis nginx
```

### 3. Manual Service Testing
```bash
# Stop all services
sudo systemctl stop noctis-*

# Start in correct order to test dependencies
sudo systemctl start noctis-startup
sudo systemctl start noctis-web
sudo systemctl start noctis-worker
sudo systemctl start noctis-scheduler
sudo systemctl start noctis-dicom
```

---

## 📊 MONITORING STARTUP

### 1. View Startup Logs
```bash
# View startup logs
sudo journalctl -u noctis-startup -f

# View all NoctisPro service logs
sudo journalctl -u noctis-* -f

# View specific service logs
sudo journalctl -u noctis-web -f
```

### 2. Check Service Dependencies
```bash
# Check what services are waiting for
systemctl list-dependencies --reverse noctis-web.service

# Check boot time analysis
systemd-analyze blame
systemd-analyze critical-chain noctis-web.service
```

### 3. Startup Performance
```bash
# Analyze boot performance
systemd-analyze plot > /tmp/bootchart.svg

# Check service startup times
systemd-analyze blame | grep noctis
```

---

## 🔧 TROUBLESHOOTING AUTO-START

### Common Issues and Solutions

#### 1. Service Fails to Start
```bash
# Check service status
sudo systemctl status noctis-web.service

# View detailed logs
sudo journalctl -u noctis-web.service --since "1 hour ago"

# Check dependencies
sudo systemctl list-dependencies noctis-web.service
```

#### 2. Services Start in Wrong Order
```bash
# Check service ordering
systemd-analyze critical-chain

# Fix by updating service dependencies
sudo nano /etc/systemd/system/noctis-web.service
# Add proper After= and Requires= directives
```

#### 3. Database Not Ready
```bash
# Check if startup script is working
sudo journalctl -u noctis-startup.service

# Manually run startup script
sudo -u noctis /opt/noctis_pro/scripts/startup.sh
```

#### 4. Permission Issues
```bash
# Fix file permissions
sudo chown -R noctis:noctis /opt/noctis_pro
sudo chmod +x /opt/noctis_pro/scripts/*.sh
```

### 5. Reset All Services
```bash
# If everything breaks, reset all services
sudo systemctl disable noctis-*
sudo systemctl daemon-reload
sudo /opt/noctis_pro/configure_startup.sh
```

---

## ✅ AUTO-START VERIFICATION CHECKLIST

### Final Verification Steps

1. **✅ All systemd services enabled**:
   ```bash
   systemctl is-enabled noctis-web noctis-worker noctis-scheduler
   ```

2. **✅ Services start in correct order**:
   ```bash
   systemd-analyze critical-chain noctis-web.service
   ```

3. **✅ Health monitoring active**:
   ```bash
   systemctl status noctis-healthcheck.timer
   ```

4. **✅ Logs are being written**:
   ```bash
   ls -la /opt/noctis_pro/logs/
   ```

5. **✅ Reboot test passes**:
   ```bash
   sudo reboot
   # After reboot:
   curl -I http://localhost:8000/
   ```

---

🎉 **Auto-Start Configuration Complete!** Your NoctisPro Medical Imaging Platform will now start automatically every time your Ubuntu server boots up!