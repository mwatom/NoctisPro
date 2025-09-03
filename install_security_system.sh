#!/bin/bash

# Ubuntu Security System Installation Script
# This script installs and configures the complete security system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Install system dependencies
install_system_deps() {
    log "Installing system dependencies..."
    
    apt-get update
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        sqlite3 \
        lvm2 \
        parted \
        gdisk \
        util-linux \
        bc \
        curl \
        wget \
        systemd \
        rsyslog \
        logrotate \
        build-essential \
        python3-dev
    
    success "System dependencies installed"
}

# Create virtual environment and install Python packages
install_python_deps() {
    log "Setting up Python environment..."
    
    # Create virtual environment
    python3 -m venv /opt/ubuntu-security-system
    source /opt/ubuntu-security-system/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install required packages
    if [[ -f "/workspace/requirements_security.txt" ]]; then
        pip install -r /workspace/requirements_security.txt
    else
        # Install core packages manually
        pip install \
            psutil \
            watchdog \
            aiofiles \
            pydicom \
            cryptography \
            bleach \
            textstat \
            langdetect \
            requests
        
        warning "requirements_security.txt not found, installed core packages only"
    fi
    
    # Install spaCy model
    python -m spacy download en_core_web_sm || warning "Could not download spaCy model"
    
    success "Python environment configured"
}

# Create directories and set permissions
setup_directories() {
    log "Setting up directories..."
    
    # Create log directories
    mkdir -p /var/log/ubuntu-security-system
    mkdir -p /var/lib/ubuntu-security-system
    mkdir -p /etc/ubuntu-security-system
    
    # Create script directory if not exists
    mkdir -p /opt/ubuntu-security-system/scripts
    
    # Copy scripts to system location
    if [[ -d "/workspace/scripts" ]]; then
        cp /workspace/scripts/*.py /opt/ubuntu-security-system/scripts/
        cp /workspace/scripts/*.sh /opt/ubuntu-security-system/scripts/
        chmod +x /opt/ubuntu-security-system/scripts/*
    fi
    
    # Copy configuration
    if [[ -f "/workspace/config/security_orchestrator.conf" ]]; then
        cp /workspace/config/security_orchestrator.conf /etc/ubuntu-security-system/
    fi
    
    # Set permissions
    chown -R root:root /opt/ubuntu-security-system
    chown -R root:root /var/log/ubuntu-security-system
    chown -R root:root /var/lib/ubuntu-security-system
    chown -R root:root /etc/ubuntu-security-system
    
    chmod 755 /opt/ubuntu-security-system/scripts/*
    chmod 644 /etc/ubuntu-security-system/*.conf
    
    success "Directories configured"
}

# Install systemd services
install_services() {
    log "Installing systemd services..."
    
    # Main orchestrator service
    cat > /etc/systemd/system/ubuntu-security-orchestrator.service << EOF
[Unit]
Description=Ubuntu Security Orchestrator
After=multi-user.target network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/opt/ubuntu-security-system/bin/python /opt/ubuntu-security-system/scripts/ubuntu_security_orchestrator.py --daemon --config /etc/ubuntu-security-system/security_orchestrator.conf
Restart=always
RestartSec=10
User=root
Group=root
StandardOutput=journal
StandardError=journal
WorkingDirectory=/opt/ubuntu-security-system

[Install]
WantedBy=multi-user.target
EOF

    # Partition extension timer service
    cat > /etc/systemd/system/ubuntu-partition-extend.service << EOF
[Unit]
Description=Ubuntu Automatic Partition Extension
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/ubuntu-security-system/scripts/auto_partition_extend.sh --monitor
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/ubuntu-partition-extend.timer << EOF
[Unit]
Description=Run Ubuntu Partition Extension every 30 minutes
Requires=ubuntu-partition-extend.service

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable ubuntu-security-orchestrator.service
    systemctl enable ubuntu-partition-extend.timer
    
    success "Systemd services installed"
}

# Configure log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/ubuntu-security-system << EOF
/var/log/ubuntu-security-system/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload ubuntu-security-orchestrator || true
    endscript
}

/var/log/*.db {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    success "Log rotation configured"
}

# Create startup script
create_startup_script() {
    log "Creating startup script..."
    
    cat > /usr/local/bin/ubuntu-security-system << 'EOF'
#!/bin/bash

# Ubuntu Security System Control Script

case "$1" in
    start)
        echo "Starting Ubuntu Security System..."
        systemctl start ubuntu-security-orchestrator
        systemctl start ubuntu-partition-extend.timer
        echo "Services started"
        ;;
    stop)
        echo "Stopping Ubuntu Security System..."
        systemctl stop ubuntu-security-orchestrator
        systemctl stop ubuntu-partition-extend.timer
        echo "Services stopped"
        ;;
    restart)
        echo "Restarting Ubuntu Security System..."
        systemctl restart ubuntu-security-orchestrator
        systemctl restart ubuntu-partition-extend.timer
        echo "Services restarted"
        ;;
    status)
        echo "Ubuntu Security System Status:"
        systemctl status ubuntu-security-orchestrator --no-pager
        systemctl status ubuntu-partition-extend.timer --no-pager
        ;;
    logs)
        echo "Recent logs:"
        journalctl -u ubuntu-security-orchestrator -n 50 --no-pager
        ;;
    install-deps)
        echo "Installing additional dependencies..."
        /opt/ubuntu-security-system/bin/pip install -r /workspace/requirements_security.txt
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|install-deps}"
        exit 1
        ;;
esac

exit 0
EOF

    chmod +x /usr/local/bin/ubuntu-security-system
    
    success "Startup script created at /usr/local/bin/ubuntu-security-system"
}

# Perform system checks
system_checks() {
    log "Performing system checks..."
    
    # Check available space
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # Less than 1GB
        warning "Low disk space detected. Consider freeing up space."
    fi
    
    # Check memory
    total_mem=$(free -m | grep '^Mem:' | awk '{print $2}')
    if [[ $total_mem -lt 2048 ]]; then  # Less than 2GB
        warning "Low memory detected. System may run slowly."
    fi
    
    # Check if LVM is available
    if ! command -v lvm &> /dev/null; then
        warning "LVM tools not found. Partition extension may not work properly."
    fi
    
    # Test Python environment
    if /opt/ubuntu-security-system/bin/python -c "import psutil, asyncio, sqlite3" 2>/dev/null; then
        success "Python environment test passed"
    else
        error "Python environment test failed"
        return 1
    fi
    
    success "System checks completed"
}

# Main installation function
main() {
    log "Starting Ubuntu Security System installation..."
    
    check_root
    install_system_deps
    install_python_deps
    setup_directories
    install_services
    setup_log_rotation
    create_startup_script
    system_checks
    
    success "Ubuntu Security System installation completed!"
    
    echo
    echo "Next steps:"
    echo "1. Review configuration in /etc/ubuntu-security-system/security_orchestrator.conf"
    echo "2. Start the system with: ubuntu-security-system start"
    echo "3. Check status with: ubuntu-security-system status"
    echo "4. View logs with: ubuntu-security-system logs"
    echo
    echo "The system provides:"
    echo "- Automatic partition extension when space is low"
    echo "- Advanced log filtering and exploit detection"
    echo "- DICOM traffic sanitization"
    echo "- Content sanitization for reports and chats"
    echo "- Centralized monitoring and alerting"
}

# Run main function
main "$@"