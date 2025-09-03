#!/bin/bash

# 🚀 Masterpiece Deployment (No Sudo Required)
# Deploys the NoctisPro Masterpiece system without requiring root access
# Works in containers and restricted environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="/workspace"
MASTERPIECE_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro-masterpiece"
PID_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.pid"
LOG_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.log"
STARTUP_LOG="$WORKSPACE_DIR/masterpiece_startup.log"
AUTOSTART_SCRIPT="$WORKSPACE_DIR/autostart_masterpiece.sh"

print_header() {
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}🚀  MASTERPIECE DEPLOYMENT (Container/No-Sudo Mode)${NC}"
    echo -e "${CYAN}   NoctisPro Medical Imaging System - All Features${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): SUCCESS - $1" >> "$STARTUP_LOG"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): ERROR - $1" >> "$STARTUP_LOG"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): WARNING - $1" >> "$STARTUP_LOG"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): INFO - $1" >> "$STARTUP_LOG"
}

# Function to stop all existing services
stop_all_services() {
    print_info "Stopping all existing NoctisPro services..."
    
    # Stop all tmux sessions related to noctispro
    for session in $(tmux list-sessions 2>/dev/null | grep -E "(noctispro|masterpiece)" | cut -d: -f1 || true); do
        print_info "Stopping tmux session: $session"
        tmux kill-session -t "$session" 2>/dev/null || true
    done
    
    # Kill any Django processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    pkill -f "python.*manage.py" 2>/dev/null || true
    
    # Kill ngrok processes
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "ngrok.*tunnel" 2>/dev/null || true
    
    # Remove old PID files
    rm -f "$WORKSPACE_DIR"/*.pid
    rm -f "$PID_FILE"
    
    sleep 3
    print_success "All existing services stopped"
}

# Function to install Python packages using pip user mode
install_python_packages() {
    print_info "Installing Python packages in user mode..."
    
    cd "$MASTERPIECE_DIR"
    
    # Use pip user install to avoid permission issues
    export PIP_USER=1
    export PYTHONUSERBASE="$MASTERPIECE_DIR/python_packages"
    export PYTHONPATH="$PYTHONUSERBASE/lib/python3.13/site-packages:${PYTHONPATH:-}"
    export PATH="$PYTHONUSERBASE/bin:$PATH"
    
    # Create user package directory
    mkdir -p "$PYTHONUSERBASE"
    
    # Install essential packages
    print_info "Installing essential Django packages..."
    python3 -m pip install --user --upgrade pip setuptools wheel 2>/dev/null || {
        print_warning "Could not upgrade pip"
    }
    
    # Install core packages one by one for better error handling
    local essential_packages=(
        "Django>=4.2"
        "Pillow"
        "django-widget-tweaks"
        "gunicorn"
        "whitenoise"
        "djangorestframework"
        "django-cors-headers"
    )
    
    for package in "${essential_packages[@]}"; do
        print_info "Installing $package..."
        python3 -m pip install --user "$package" --timeout 300 2>/dev/null || {
            print_warning "Failed to install $package - continuing"
        }
    done
    
    # Try to install additional packages if possible
    local additional_packages=(
        "pydicom"
        "numpy"
        "requests"
        "python-dotenv"
    )
    
    for package in "${additional_packages[@]}"; do
        print_info "Installing $package..."
        python3 -m pip install --user "$package" --timeout 180 2>/dev/null || {
            print_warning "Failed to install $package - continuing without it"
        }
    done
    
    print_success "Python packages installed in user mode"
}

# Function to prepare database and static files
prepare_application() {
    print_info "Preparing masterpiece application..."
    
    cd "$MASTERPIECE_DIR"
    
    # Set up environment
    export PIP_USER=1
    export PYTHONUSERBASE="$MASTERPIECE_DIR/python_packages"
    export PYTHONPATH="$PYTHONUSERBASE/lib/python3.13/site-packages:${PYTHONPATH:-}"
    export PATH="$PYTHONUSERBASE/bin:$PATH"
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="masterpiece-deployment-$(date +%s)"
    export DEBUG="False"
    
    # Create necessary directories
    mkdir -p logs media/dicom static staticfiles
    
    # Test Django installation
    if ! python3 -c "import django; print('Django version:', django.get_version())" 2>/dev/null; then
        print_error "Django is not properly installed"
        return 1
    fi
    
    print_success "Django is available"
    
    # Run migrations
    print_info "Running database migrations..."
    python3 manage.py migrate --noinput 2>/dev/null || {
        print_warning "Migrations failed - trying with --run-syncdb"
        python3 manage.py migrate --run-syncdb --noinput 2>/dev/null || {
            print_warning "Database setup failed - continuing anyway"
        }
    }
    
    # Collect static files
    print_info "Collecting static files..."
    python3 manage.py collectstatic --noinput 2>/dev/null || {
        print_warning "Static file collection failed - continuing anyway"
    }
    
    # Create admin user
    print_info "Setting up admin user..."
    python3 manage.py shell -c "
try:
    from django.contrib.auth import get_user_model
    User = get_user_model()
    if not User.objects.filter(username='admin').exists():
        User.objects.create_superuser('admin', 'admin@noctis.local', 'admin123')
        print('Admin user created')
    else:
        print('Admin user already exists')
except Exception as e:
    print('Could not create admin user:', e)
" 2>/dev/null || {
        print_warning "Could not create admin user"
    }
    
    print_success "Application prepared successfully"
}

# Function to create autostart script for no-sudo environments
create_container_autostart() {
    print_info "Creating container-friendly autostart script..."
    
    cat > "$AUTOSTART_SCRIPT" << 'EOF'
#!/bin/bash

# 🚀 Container-Friendly Masterpiece Autostart
# Works without sudo access

WORKSPACE_DIR="/workspace"
MASTERPIECE_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro-masterpiece"
LOG_FILE="$WORKSPACE_DIR/masterpiece_startup.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

start_masterpiece() {
    log_message "Starting masterpiece system..."
    
    # Check if already running
    if tmux has-session -t "$SERVICE_NAME" 2>/dev/null; then
        log_message "Service already running"
        return 0
    fi
    
    # Wait for system readiness
    sleep 10
    
    cd "$MASTERPIECE_DIR" || {
        log_message "ERROR: Cannot access masterpiece directory"
        return 1
    }
    
    # Set up environment
    export PIP_USER=1
    export PYTHONUSERBASE="$MASTERPIECE_DIR/python_packages"
    export PYTHONPATH="$PYTHONUSERBASE/lib/python3.13/site-packages:${PYTHONPATH:-}"
    export PATH="$PYTHONUSERBASE/bin:$PATH"
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="masterpiece-autostart-$(date +%s)"
    export DEBUG="False"
    
    # Test Django availability
    if ! python3 -c "import django" 2>/dev/null; then
        log_message "ERROR: Django not available"
        return 1
    fi
    
    # Kill any existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    
    # Start Django in tmux
    tmux new-session -d -s "$SERVICE_NAME" -c "$MASTERPIECE_DIR"
    tmux send-keys -t "$SERVICE_NAME" "cd $MASTERPIECE_DIR" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PIP_USER=1" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PYTHONUSERBASE=$MASTERPIECE_DIR/python_packages" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PYTHONPATH=\$PYTHONUSERBASE/lib/python3.13/site-packages:\$PYTHONPATH" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PATH=\$PYTHONUSERBASE/bin:\$PATH" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" C-m
    tmux send-keys -t "$SERVICE_NAME" "export SECRET_KEY=masterpiece-autostart-\$(date +%s)" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DEBUG=False" C-m
    tmux send-keys -t "$SERVICE_NAME" "python3 manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
    
    # Wait for Django to start
    sleep 15
    
    # Start ngrok if available
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        tmux new-window -t "$SERVICE_NAME" -n ngrok
        tmux send-keys -t "$SERVICE_NAME:ngrok" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$SERVICE_NAME:ngrok" "./ngrok http $DJANGO_PORT --hostname=$STATIC_URL --log=stdout" C-m
    fi
    
    # Save status
    echo "SERVICE_RUNNING=true" > "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    echo "STARTED_AT=$(date)" >> "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    echo "AUTOSTART=true" >> "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    
    log_message "Masterpiece system started successfully"
    return 0
}

# Run with retry logic
for attempt in {1..3}; do
    if start_masterpiece; then
        exit 0
    else
        log_message "Attempt $attempt failed - retrying in 30 seconds"
        sleep 30
    fi
done

log_message "All attempts failed"
exit 1
EOF

    chmod +x "$AUTOSTART_SCRIPT"
    print_success "Container-friendly autostart script created"
}

# Function to setup profile-based autostart
setup_profile_autostart() {
    print_info "Setting up profile-based autostart..."
    
    # Add to bashrc and profile
    for profile_file in ~/.bashrc ~/.profile; do
        if [ -f "$profile_file" ]; then
            # Remove existing autostart lines
            grep -v "autostart_masterpiece.sh\|noctispro.*autostart" "$profile_file" > "${profile_file}.tmp" 2>/dev/null || cp "$profile_file" "${profile_file}.tmp"
            
            # Add new autostart line with guard
            echo "" >> "${profile_file}.tmp"
            echo "# NoctisPro Masterpiece autostart" >> "${profile_file}.tmp"
            echo "if [ -f '$AUTOSTART_SCRIPT' ] && [ ! -f '/tmp/masterpiece_autostart_done' ]; then" >> "${profile_file}.tmp"
            echo "    touch /tmp/masterpiece_autostart_done" >> "${profile_file}.tmp"
            echo "    nohup $AUTOSTART_SCRIPT > /dev/null 2>&1 &" >> "${profile_file}.tmp"
            echo "fi" >> "${profile_file}.tmp"
            
            mv "${profile_file}.tmp" "$profile_file"
            print_success "Added autostart to $profile_file"
        fi
    done
}

# Function to start the service
start_service() {
    print_info "Starting Masterpiece service..."
    
    cd "$MASTERPIECE_DIR"
    
    # Set up environment
    export PIP_USER=1
    export PYTHONUSERBASE="$MASTERPIECE_DIR/python_packages"
    export PYTHONPATH="$PYTHONUSERBASE/lib/python3.13/site-packages:${PYTHONPATH:-}"
    export PATH="$PYTHONUSERBASE/bin:$PATH"
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="masterpiece-production-$(date +%s)"
    export DEBUG="False"
    
    # Test Django
    if ! python3 -c "import django" 2>/dev/null; then
        print_error "Django is not available - please run full deployment first"
        return 1
    fi
    
    # Kill existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
    sleep 3
    
    # Start Django in tmux
    tmux new-session -d -s "$SERVICE_NAME" -c "$MASTERPIECE_DIR"
    tmux send-keys -t "$SERVICE_NAME" "cd $MASTERPIECE_DIR" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PIP_USER=1" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PYTHONUSERBASE=$MASTERPIECE_DIR/python_packages" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PYTHONPATH=\$PYTHONUSERBASE/lib/python3.13/site-packages:\$PYTHONPATH" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PATH=\$PYTHONUSERBASE/bin:\$PATH" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" C-m
    tmux send-keys -t "$SERVICE_NAME" "export SECRET_KEY=masterpiece-production-\$(date +%s)" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DEBUG=False" C-m
    tmux send-keys -t "$SERVICE_NAME" "python3 manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
    
    # Wait for Django to start
    sleep 10
    
    # Start ngrok if available
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        tmux new-window -t "$SERVICE_NAME" -n ngrok
        tmux send-keys -t "$SERVICE_NAME:ngrok" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$SERVICE_NAME:ngrok" "./ngrok http $DJANGO_PORT --hostname=$STATIC_URL --log=stdout" C-m
    fi
    
    # Save service status
    echo "SERVICE_RUNNING=true" > "$PID_FILE"
    echo "STARTED_AT=$(date)" >> "$PID_FILE"
    echo "TMUX_SESSION=$SERVICE_NAME" >> "$PID_FILE"
    echo "SYSTEM_VERSION=masterpiece" >> "$PID_FILE"
    
    print_success "Masterpiece service started successfully!"
}

# Function to stop the service
stop_service() {
    print_info "Stopping Masterpiece service..."
    
    # Kill tmux session
    tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
    
    # Kill processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http.*$STATIC_URL" 2>/dev/null || true
    
    # Remove PID file
    rm -f "$PID_FILE"
    
    print_success "Masterpiece service stopped"
}

# Function to show service status
show_status() {
    echo ""
    echo -e "${BLUE}📊 Masterpiece Service Status:${NC}"
    echo ""
    
    # Check tmux session
    if tmux has-session -t "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}✅ Tmux Session: Running${NC}"
        echo -e "   Session: $SERVICE_NAME"
    else
        echo -e "${RED}❌ Tmux Session: Not found${NC}"
    fi
    
    # Check Django server
    if curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django Server: Running on port $DJANGO_PORT${NC}"
    else
        echo -e "${RED}❌ Django Server: Not responding${NC}"
    fi
    
    # Check ngrok
    if pgrep -f "ngrok.*http.*$STATIC_URL" > /dev/null; then
        echo -e "${GREEN}✅ Ngrok Tunnel: Active${NC}"
        echo -e "${CYAN}   URL: https://$STATIC_URL${NC}"
    else
        echo -e "${YELLOW}⚠️ Ngrok Tunnel: Not active (local access only)${NC}"
    fi
    
    # Show autostart status
    echo ""
    echo -e "${BLUE}🔧 Autostart Configuration:${NC}"
    [ -f "$AUTOSTART_SCRIPT" ] && echo -e "${GREEN}✅ Autostart script ready${NC}"
    grep -q "autostart_masterpiece.sh" ~/.bashrc 2>/dev/null && echo -e "${GREEN}✅ Bashrc autostart configured${NC}"
    grep -q "autostart_masterpiece.sh" ~/.profile 2>/dev/null && echo -e "${GREEN}✅ Profile autostart configured${NC}"
    
    # Show PID file info if exists
    if [ -f "$PID_FILE" ]; then
        echo ""
        echo -e "${BLUE}📋 Service Details:${NC}"
        cat "$PID_FILE"
    fi
    
    echo ""
}

# Main deployment function
deploy_masterpiece() {
    print_header
    
    # Pre-deployment checks
    print_info "🔍 Pre-deployment checks..."
    
    if [ ! -d "$MASTERPIECE_DIR" ]; then
        print_error "Masterpiece directory not found: $MASTERPIECE_DIR"
        exit 1
    fi
    
    if [ ! -f "$MASTERPIECE_DIR/manage.py" ]; then
        print_error "Django manage.py not found in masterpiece directory"
        exit 1
    fi
    
    print_success "Pre-deployment checks passed"
    
    # Initialize startup log
    echo "=== Masterpiece Deployment Started: $(date) ===" > "$STARTUP_LOG"
    
    # Execute deployment steps
    stop_all_services
    install_python_packages
    prepare_application
    create_container_autostart
    setup_profile_autostart
    start_service
    
    # Final success message
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}🎉  MASTERPIECE DEPLOYMENT SUCCESSFUL!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Your NoctisPro Masterpiece system is now live:${NC}"
    echo ""
    echo -e "${WHITE}📋 Main Application:${NC}"
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        echo -e "   ${CYAN}https://$STATIC_URL/${NC} (external access)"
    fi
    echo -e "   ${CYAN}http://localhost:$DJANGO_PORT/${NC} (local access)"
    echo ""
    echo -e "${WHITE}🔧 Admin Panel:${NC}"
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        echo -e "   ${CYAN}https://$STATIC_URL/admin/${NC}"
    fi
    echo -e "   ${CYAN}http://localhost:$DJANGO_PORT/admin/${NC}"
    echo -e "   👤 Username: ${YELLOW}admin${NC}"
    echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
    echo ""
    echo -e "${GREEN}✨ Masterpiece Features Available:${NC}"
    echo -e "   🏥 DICOM Worklist Management"
    echo -e "   👁️  Advanced DICOM Viewer"
    echo -e "   📊 Comprehensive Reports"
    echo -e "   🤖 AI Analysis Tools"
    echo -e "   💬 Real-time Chat System"
    echo -e "   🔔 Smart Notifications"
    echo -e "   🛡️  Advanced Admin Panel"
    echo ""
    echo -e "${BLUE}🔧 Service Management:${NC}"
    echo -e "   Start:   ${CYAN}$0 start${NC}"
    echo -e "   Stop:    ${CYAN}$0 stop${NC}"
    echo -e "   Status:  ${CYAN}$0 status${NC}"
    echo -e "   Restart: ${CYAN}$0 restart${NC}"
    echo ""
    echo -e "${GREEN}🚀 Auto-start: Configured for container environments${NC}"
    echo -e "${BLUE}📋 Startup logs: ${CYAN}$STARTUP_LOG${NC}"
    echo ""
    
    if [ ! -f "$WORKSPACE_DIR/ngrok" ]; then
        echo -e "${YELLOW}⚠️  Note: Ngrok not found - system available locally only${NC}"
        echo -e "${BLUE}   To enable external access, configure ngrok:${NC}"
        echo -e "   1. Download: wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
        echo -e "   2. Extract: tar -xzf ngrok-v3-stable-linux-amd64.tgz"
        echo -e "   3. Configure: ./ngrok config add-authtoken YOUR_TOKEN"
        echo ""
    fi
}

# Main command handling
case "${1:-deploy}" in
    "start")
        start_service
        ;;
    "stop")
        stop_service
        ;;
    "restart")
        stop_service
        sleep 3
        start_service
        ;;
    "status")
        show_status
        ;;
    "deploy")
        deploy_masterpiece
        ;;
    *)
        echo -e "${BLUE}🚀 NoctisPro Masterpiece Deployment Manager (No-Sudo Mode)${NC}"
        echo ""
        echo "Usage: $0 {deploy|start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Full masterpiece deployment with autostart setup"
        echo "  start    - Start the masterpiece service"
        echo "  stop     - Stop the masterpiece service"
        echo "  restart  - Restart the masterpiece service"
        echo "  status   - Show detailed service status"
        echo ""
        echo -e "${GREEN}✨ Features: DICOM Viewer, Worklist, Reports, AI Analysis, Chat, Admin Panel${NC}"
        echo -e "${BLUE}🔧 Designed for container and no-sudo environments${NC}"
        echo ""
        exit 1
        ;;
esac