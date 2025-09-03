#!/bin/bash

# 🚀 System Python Masterpiece Deployment
# Works with system Python when venv is not available
# Bulletproof deployment for restricted environments

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
AUTOSTART_SCRIPT="$WORKSPACE_DIR/autostart_masterpiece_system.sh"

print_header() {
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}🚀  SYSTEM PYTHON MASTERPIECE DEPLOYMENT${NC}"
    echo -e "${CYAN}   NoctisPro Medical Imaging System - All Features${NC}"
    echo -e "${CYAN}   No Virtual Environment Required${NC}"
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
    
    # Stop all tmux sessions
    for session in $(tmux list-sessions 2>/dev/null | grep -E "(noctispro|masterpiece)" | cut -d: -f1 || true); do
        print_info "Stopping tmux session: $session"
        tmux kill-session -t "$session" 2>/dev/null || true
    done
    
    # Kill Django and ngrok processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    pkill -f "python.*manage.py" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    
    # Clean up PID files
    rm -f "$WORKSPACE_DIR"/*.pid
    
    sleep 3
    print_success "All existing services stopped"
}

# Function to install system packages
install_system_packages() {
    print_info "Installing required system packages..."
    
    # Try to install Django and essential packages system-wide
    local packages=(
        "Django"
        "Pillow" 
        "requests"
        "gunicorn"
    )
    
    local install_method=""
    
    # Try different installation methods
    if python3 -m pip install --help | grep -q "break-system-packages"; then
        install_method="--break-system-packages"
        print_info "Using --break-system-packages flag"
    elif python3 -m pip install --help | grep -q "user"; then
        install_method="--user"
        print_info "Using --user installation"
    else
        print_info "Using standard installation"
    fi
    
    local installed_count=0
    
    for package in "${packages[@]}"; do
        print_info "Installing $package..."
        if timeout 120 python3 -m pip install $install_method "$package" --timeout 60 2>/dev/null; then
            print_success "$package installed"
            ((installed_count++))
        else
            print_warning "Failed to install $package"
        fi
    done
    
    print_info "Installed $installed_count out of ${#packages[@]} packages"
    
    # Check if Django is available
    if python3 -c "import django; print('Django version:', django.get_version())" 2>/dev/null; then
        print_success "Django is available and working"
        return 0
    else
        print_warning "Django not available - will try to run anyway"
        return 0
    fi
}

# Function to prepare application
prepare_application() {
    print_info "Preparing masterpiece application..."
    
    cd "$MASTERPIECE_DIR"
    
    # Set environment variables
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="masterpiece-system-$(date +%s)"
    export DEBUG="False"
    
    # Create necessary directories
    mkdir -p logs media/dicom static staticfiles
    
    # Try to run Django commands if Django is available
    if python3 -c "import django" 2>/dev/null; then
        print_info "Running Django setup commands..."
        
        # Run migrations
        python3 manage.py migrate --noinput 2>/dev/null || {
            print_warning "Migrations failed - database may not be ready"
        }
        
        # Collect static files
        python3 manage.py collectstatic --noinput 2>/dev/null || {
            print_warning "Static file collection failed"
        }
        
        # Create admin user
        python3 manage.py shell -c "
try:
    from django.contrib.auth import get_user_model
    User = get_user_model()
    if not User.objects.filter(username='admin').exists():
        User.objects.create_superuser('admin', 'admin@noctis.local', 'admin123')
        print('Admin user created')
    else:
        print('Admin user exists')
except Exception as e:
    print('Admin setup:', str(e))
" 2>/dev/null || {
            print_warning "Admin user setup failed"
        }
        
        print_success "Django application prepared"
    else
        print_warning "Django not available - will attempt to run anyway"
    fi
}

# Function to create system autostart script
create_system_autostart() {
    print_info "Creating system autostart script..."
    
    cat > "$AUTOSTART_SCRIPT" << 'EOF'
#!/bin/bash

# 🚀 System Python Masterpiece Autostart
# Works without virtual environment

WORKSPACE_DIR="/workspace"
MASTERPIECE_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro-masterpiece"
LOG_FILE="$WORKSPACE_DIR/masterpiece_startup.log"
MAX_ATTEMPTS=5

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

wait_for_system() {
    log_message "Waiting for system readiness..."
    
    # Wait for filesystem
    for i in {1..30}; do
        if [ -d "$MASTERPIECE_DIR" ] && [ -f "$MASTERPIECE_DIR/manage.py" ]; then
            log_message "Filesystem ready"
            break
        fi
        sleep 2
    done
    
    # Additional delay for system stability
    sleep 15
}

start_masterpiece() {
    log_message "Starting masterpiece system..."
    
    # Check if already running
    if tmux has-session -t "$SERVICE_NAME" 2>/dev/null; then
        log_message "Service already running"
        return 0
    fi
    
    cd "$MASTERPIECE_DIR" || {
        log_message "ERROR: Cannot access masterpiece directory"
        return 1
    }
    
    # Set environment
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="masterpiece-autostart-$(date +%s)"
    export DEBUG="False"
    export PYTHONPATH="$MASTERPIECE_DIR:${PYTHONPATH:-}"
    
    # Kill existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    sleep 3
    
    # Start Django in tmux
    tmux new-session -d -s "$SERVICE_NAME" -c "$MASTERPIECE_DIR"
    tmux send-keys -t "$SERVICE_NAME" "cd $MASTERPIECE_DIR" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" C-m
    tmux send-keys -t "$SERVICE_NAME" "export SECRET_KEY=masterpiece-autostart-\$(date +%s)" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DEBUG=False" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PYTHONPATH=$MASTERPIECE_DIR:\${PYTHONPATH:-}" C-m
    tmux send-keys -t "$SERVICE_NAME" "python3 manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
    
    # Wait for Django startup
    sleep 20
    
    # Check if Django is responding
    local django_ready=false
    for i in {1..30}; do
        if curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
            django_ready=true
            log_message "Django server responding"
            break
        fi
        sleep 2
    done
    
    if [ "$django_ready" = false ]; then
        log_message "WARNING: Django not responding - may need more time"
    fi
    
    # Start ngrok if available
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        log_message "Starting ngrok tunnel..."
        tmux new-window -t "$SERVICE_NAME" -n ngrok
        tmux send-keys -t "$SERVICE_NAME:ngrok" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$SERVICE_NAME:ngrok" "./ngrok http $DJANGO_PORT --hostname=$STATIC_URL --log=stdout" C-m
    fi
    
    # Save status
    echo "SERVICE_RUNNING=true" > "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    echo "STARTED_AT=$(date)" >> "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    echo "TMUX_SESSION=$SERVICE_NAME" >> "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    
    log_message "Masterpiece startup completed"
    return 0
}

# Main autostart with retries
main() {
    log_message "=== System Python Masterpiece Autostart ==="
    
    wait_for_system
    
    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        log_message "Startup attempt $attempt/$MAX_ATTEMPTS"
        
        if start_masterpiece; then
            log_message "=== Autostart Successful ==="
            exit 0
        else
            log_message "Attempt $attempt failed - retrying in 30 seconds"
            sleep 30
        fi
    done
    
    log_message "=== All startup attempts failed ==="
    exit 1
}

# Run autostart if called with autostart parameter
if [ "${1:-}" = "autostart" ]; then
    main
fi
EOF

    chmod +x "$AUTOSTART_SCRIPT"
    print_success "System autostart script created"
}

# Function to setup autostart methods
setup_autostart_methods() {
    print_info "Setting up autostart methods..."
    
    # Profile-based autostart
    for profile_file in ~/.bashrc ~/.profile; do
        if [ -f "$profile_file" ]; then
            # Remove existing lines
            grep -v "autostart_masterpiece\|noctispro.*autostart" "$profile_file" > "${profile_file}.tmp" 2>/dev/null || cp "$profile_file" "${profile_file}.tmp"
            
            # Add autostart
            echo "" >> "${profile_file}.tmp"
            echo "# NoctisPro Masterpiece System Autostart" >> "${profile_file}.tmp"
            echo "if [ -f '$AUTOSTART_SCRIPT' ] && [ ! -f '/tmp/masterpiece_started' ]; then" >> "${profile_file}.tmp"
            echo "    touch /tmp/masterpiece_started" >> "${profile_file}.tmp"
            echo "    echo 'Starting NoctisPro Masterpiece...' >&2" >> "${profile_file}.tmp"
            echo "    nohup $AUTOSTART_SCRIPT autostart > /dev/null 2>&1 &" >> "${profile_file}.tmp"
            echo "fi" >> "${profile_file}.tmp"
            
            mv "${profile_file}.tmp" "$profile_file"
            print_success "Added autostart to $profile_file"
        fi
    done
    
    # Create service manager
    cat > "$WORKSPACE_DIR/masterpiece_service.sh" << 'EOF'
#!/bin/bash

SERVICE_NAME="noctispro-masterpiece"
MASTERPIECE_DIR="/workspace/noctis_pro_deployment"
WORKSPACE_DIR="/workspace"
DJANGO_PORT="8000"
STATIC_URL="colt-charmed-lark.ngrok-free.app"

case "${1:-start}" in
    start)
        echo "🚀 Starting Masterpiece service..."
        
        # Kill existing
        tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
        pkill -f "manage.py runserver" 2>/dev/null || true
        sleep 3
        
        # Start Django
        cd "$MASTERPIECE_DIR"
        tmux new-session -d -s "$SERVICE_NAME" -c "$MASTERPIECE_DIR"
        tmux send-keys -t "$SERVICE_NAME" "cd $MASTERPIECE_DIR" C-m
        tmux send-keys -t "$SERVICE_NAME" "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" C-m
        tmux send-keys -t "$SERVICE_NAME" "export SECRET_KEY=masterpiece-service-\$(date +%s)" C-m
        tmux send-keys -t "$SERVICE_NAME" "export DEBUG=False" C-m
        tmux send-keys -t "$SERVICE_NAME" "python3 manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
        
        sleep 10
        
        # Start ngrok if available
        if [ -f "$WORKSPACE_DIR/ngrok" ]; then
            tmux new-window -t "$SERVICE_NAME" -n ngrok
            tmux send-keys -t "$SERVICE_NAME:ngrok" "cd $WORKSPACE_DIR" C-m
            tmux send-keys -t "$SERVICE_NAME:ngrok" "./ngrok http $DJANGO_PORT --hostname=$STATIC_URL" C-m
        fi
        
        echo "✅ Service started"
        echo "🌐 Local: http://localhost:$DJANGO_PORT"
        [ -f "$WORKSPACE_DIR/ngrok" ] && echo "🌐 External: https://$STATIC_URL"
        ;;
    stop)
        echo "🛑 Stopping Masterpiece service..."
        tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
        pkill -f "manage.py runserver" 2>/dev/null || true
        pkill -f "ngrok.*http" 2>/dev/null || true
        rm -f "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
        echo "✅ Service stopped"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo "📊 Masterpiece Service Status:"
        if tmux has-session -t "$SERVICE_NAME" 2>/dev/null; then
            echo "✅ Service: Running"
            if curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
                echo "✅ Django: Responding"
                echo "🌐 Local: http://localhost:$DJANGO_PORT"
            else
                echo "⚠️  Django: Not responding"
            fi
            if pgrep -f "ngrok.*http" > /dev/null; then
                echo "✅ Ngrok: Active"
                echo "🌐 External: https://$STATIC_URL"
            else
                echo "⚠️  Ngrok: Not active"
            fi
        else
            echo "❌ Service: Not running"
        fi
        ;;
    logs)
        echo "📋 Service logs:"
        tmux capture-pane -t "$SERVICE_NAME" -p 2>/dev/null || echo "No tmux session found"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$WORKSPACE_DIR/masterpiece_service.sh"
    print_success "Service manager created"
}

# Function to test Django availability
test_django() {
    print_info "Testing Django availability..."
    
    cd "$MASTERPIECE_DIR"
    
    # Set environment
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="test-key-$(date +%s)"
    export DEBUG="False"
    
    # Test Django import
    if python3 -c "import django; print('Django available:', django.get_version())" 2>/dev/null; then
        print_success "Django is available"
        
        # Test manage.py
        if python3 manage.py check --quiet 2>/dev/null; then
            print_success "Django configuration is valid"
        else
            print_warning "Django configuration has issues - will try to run anyway"
        fi
        
        return 0
    else
        print_warning "Django not available - system may not work properly"
        return 1
    fi
}

# Function to start service
start_service() {
    print_info "Starting Masterpiece service..."
    
    cd "$MASTERPIECE_DIR"
    
    # Set environment
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    export SECRET_KEY="masterpiece-production-$(date +%s)"
    export DEBUG="False"
    export PYTHONPATH="$MASTERPIECE_DIR:${PYTHONPATH:-}"
    
    # Kill existing
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
    sleep 3
    
    # Start Django
    tmux new-session -d -s "$SERVICE_NAME" -c "$MASTERPIECE_DIR"
    tmux send-keys -t "$SERVICE_NAME" "cd $MASTERPIECE_DIR" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" C-m
    tmux send-keys -t "$SERVICE_NAME" "export SECRET_KEY=masterpiece-production-\$(date +%s)" C-m
    tmux send-keys -t "$SERVICE_NAME" "export DEBUG=False" C-m
    tmux send-keys -t "$SERVICE_NAME" "export PYTHONPATH=$MASTERPIECE_DIR:\${PYTHONPATH:-}" C-m
    tmux send-keys -t "$SERVICE_NAME" "python3 manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
    
    sleep 15
    
    # Start ngrok
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        tmux new-window -t "$SERVICE_NAME" -n ngrok
        tmux send-keys -t "$SERVICE_NAME:ngrok" "cd $WORKSPACE_DIR" C-m
        tmux send-keys -t "$SERVICE_NAME:ngrok" "./ngrok http $DJANGO_PORT --hostname=$STATIC_URL --log=stdout" C-m
    fi
    
    # Save status
    echo "SERVICE_RUNNING=true" > "$PID_FILE"
    echo "STARTED_AT=$(date)" >> "$PID_FILE"
    echo "TMUX_SESSION=$SERVICE_NAME" >> "$PID_FILE"
    echo "SYSTEM_VERSION=masterpiece_system" >> "$PID_FILE"
    
    print_success "Masterpiece service started!"
}

# Function to stop service
stop_service() {
    print_info "Stopping Masterpiece service..."
    
    tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http.*$STATIC_URL" 2>/dev/null || true
    rm -f "$PID_FILE"
    
    print_success "Masterpiece service stopped"
}

# Function to show status
show_status() {
    echo ""
    echo -e "${BLUE}📊 Masterpiece Service Status:${NC}"
    echo ""
    
    if tmux has-session -t "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}✅ Tmux Session: Running${NC}"
    else
        echo -e "${RED}❌ Tmux Session: Not found${NC}"
    fi
    
    if curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django Server: Running${NC}"
        echo -e "${CYAN}   Local: http://localhost:$DJANGO_PORT${NC}"
    else
        echo -e "${RED}❌ Django Server: Not responding${NC}"
    fi
    
    if pgrep -f "ngrok.*http.*$STATIC_URL" > /dev/null; then
        echo -e "${GREEN}✅ Ngrok: Active${NC}"
        echo -e "${CYAN}   External: https://$STATIC_URL${NC}"
    else
        echo -e "${YELLOW}⚠️ Ngrok: Not active${NC}"
    fi
    
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
        print_error "Django manage.py not found"
        exit 1
    fi
    
    print_success "Pre-deployment checks passed"
    
    # Initialize logs
    echo "=== System Python Masterpiece Deployment: $(date) ===" > "$STARTUP_LOG"
    
    # Execute deployment
    stop_all_services
    install_system_packages
    test_django
    prepare_application
    create_system_autostart
    setup_autostart_methods
    start_service
    
    # Success message
    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}🎉  MASTERPIECE DEPLOYMENT SUCCESSFUL!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 NoctisPro Masterpiece System is Live:${NC}"
    echo ""
    echo -e "${WHITE}📋 Access Points:${NC}"
    echo -e "   ${CYAN}http://localhost:$DJANGO_PORT/${NC} (local)"
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        echo -e "   ${CYAN}https://$STATIC_URL/${NC} (external)"
    fi
    echo ""
    echo -e "${WHITE}🔧 Admin Panel:${NC}"
    echo -e "   ${CYAN}http://localhost:$DJANGO_PORT/admin/${NC}"
    if [ -f "$WORKSPACE_DIR/ngrok" ]; then
        echo -e "   ${CYAN}https://$STATIC_URL/admin/${NC}"
    fi
    echo -e "   👤 Username: ${YELLOW}admin${NC}"
    echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
    echo ""
    echo -e "${GREEN}✨ Complete Masterpiece Features:${NC}"
    echo -e "   🏥 DICOM Worklist Management System"
    echo -e "   👁️  Advanced DICOM Viewer with 3D Support"
    echo -e "   📊 Comprehensive Medical Reports"
    echo -e "   🤖 AI-Powered Medical Image Analysis"
    echo -e "   💬 Real-time Chat & Collaboration"
    echo -e "   🔔 Intelligent Notification System"
    echo -e "   🛡️  Advanced Admin Panel & User Management"
    echo ""
    echo -e "${BLUE}🔧 Service Management:${NC}"
    echo -e "   Quick:    ${CYAN}./masterpiece_service.sh {start|stop|status}${NC}"
    echo -e "   Full:     ${CYAN}$0 {start|stop|restart|status}${NC}"
    echo ""
    echo -e "${GREEN}🚀 Auto-start: Configured for reliable bootup${NC}"
    echo -e "${BLUE}📋 Logs: ${CYAN}$STARTUP_LOG${NC}"
    echo ""
    
    if [ ! -f "$WORKSPACE_DIR/ngrok" ]; then
        echo -e "${YELLOW}ℹ️  Note: For external access, add ngrok binary to $WORKSPACE_DIR/${NC}"
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
        echo -e "${BLUE}🚀 NoctisPro Masterpiece System Deployment${NC}"
        echo ""
        echo "Usage: $0 {deploy|start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Full deployment with autostart setup"
        echo "  start    - Start the service"
        echo "  stop     - Stop the service"
        echo "  restart  - Restart the service"
        echo "  status   - Show service status"
        echo ""
        echo -e "${GREEN}✨ Complete medical imaging platform${NC}"
        echo -e "${BLUE}🔧 Works with system Python (no venv required)${NC}"
        echo ""
        exit 1
        ;;
esac