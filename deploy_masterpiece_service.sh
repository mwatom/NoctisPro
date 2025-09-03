#!/bin/bash

# 🚀 Deploy Masterpiece Refined as Service
# Compatible with both old and new Linux systems
# Auto-starts on server bootup with ngrok static URL

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
REFINED_SYSTEM_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro-masterpiece"
PID_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.pid"
LOG_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.log"
NGROK_LOG="$WORKSPACE_DIR/ngrok_${SERVICE_NAME}.log"

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  Masterpiece Refined Service Deployment${NC}"
    echo -e "${CYAN}   Auto-Start + Ngrok Static URL${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Detect system type
detect_system() {
    if command -v systemctl > /dev/null 2>&1 && [ -d /etc/systemd/system ]; then
        echo "systemd"
    elif [ -d /etc/init.d ] && [ -w /etc/init.d ] 2>/dev/null; then
        echo "initd"
    else
        echo "legacy"
    fi
}

# Check if ngrok is configured
check_ngrok() {
    print_info "Checking ngrok configuration..."
    
    if [ ! -f "$WORKSPACE_DIR/ngrok" ]; then
        print_error "Ngrok binary not found at $WORKSPACE_DIR/ngrok"
        return 1
    fi
    
    if ! $WORKSPACE_DIR/ngrok config check > /dev/null 2>&1; then
        print_warning "Ngrok auth token not configured!"
        echo ""
        echo -e "${YELLOW}To configure ngrok:${NC}"
        echo "1. Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "2. Run: $WORKSPACE_DIR/ngrok config add-authtoken YOUR_TOKEN_HERE"
        echo ""
        read -p "Press Enter after configuring ngrok, or Ctrl+C to exit..."
        
        if ! $WORKSPACE_DIR/ngrok config check > /dev/null 2>&1; then
            print_error "Ngrok still not configured properly"
            return 1
        fi
    fi
    
    print_success "Ngrok is properly configured"
    return 0
}

# Check if refined system exists
check_refined_system() {
    print_info "Checking refined system..."
    
    if [ ! -d "$REFINED_SYSTEM_DIR" ]; then
        print_error "Refined system not found at $REFINED_SYSTEM_DIR"
        return 1
    fi
    
    if [ ! -f "$REFINED_SYSTEM_DIR/manage.py" ]; then
        print_error "Django manage.py not found in refined system"
        return 1
    fi
    
    print_success "Refined system found and ready"
    return 0
}

# Stop existing services
stop_existing() {
    print_info "Stopping existing services..."
    
    # Kill existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    
    # Kill tmux sessions
    tmux kill-session -t noctispro 2>/dev/null || true
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    
    # Remove old PID files
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
    [ -f "$WORKSPACE_DIR/noctispro_service.pid" ] && rm -f "$WORKSPACE_DIR/noctispro_service.pid"
    
    sleep 3
    print_success "Existing services stopped"
}

# Start the masterpiece service
start_service() {
    print_info "Starting Masterpiece Refined Service..."
    
    cd "$REFINED_SYSTEM_DIR"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment and install dependencies
    source venv/bin/activate
    
    if [ -f "requirements.txt" ]; then
        print_info "Installing/updating dependencies..."
        pip install -q -r requirements.txt
    fi
    
    # Run migrations
    print_info "Running database migrations..."
    python manage.py migrate --noinput > /dev/null 2>&1 || true
    
    # Collect static files
    print_info "Collecting static files..."
    python manage.py collectstatic --noinput > /dev/null 2>&1 || true
    
    # Start Django server in tmux session
    print_info "Starting Django server..."
    tmux new-session -d -s $SERVICE_NAME
    tmux send-keys -t $SERVICE_NAME "cd $REFINED_SYSTEM_DIR" C-m
    tmux send-keys -t $SERVICE_NAME "source venv/bin/activate" C-m
    tmux send-keys -t $SERVICE_NAME "python manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
    
    # Wait for Django to start
    sleep 5
    
    # Check if Django is running
    if ! curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
        print_error "Django server failed to start"
        return 1
    fi
    
    print_success "Django server started on port $DJANGO_PORT"
    
    # Start ngrok with static URL
    print_info "Starting ngrok with static URL..."
    tmux new-window -t $SERVICE_NAME
    tmux send-keys -t $SERVICE_NAME "cd $WORKSPACE_DIR" C-m
    tmux send-keys -t $SERVICE_NAME "./ngrok http $DJANGO_PORT --hostname=$STATIC_URL --log=stdout" C-m
    
    # Wait for ngrok to start
    sleep 5
    
    # Save service PID (tmux session)
    tmux list-sessions | grep $SERVICE_NAME | cut -d: -f1 > "$PID_FILE"
    
    print_success "Masterpiece service started successfully!"
    echo ""
    echo -e "${GREEN}🌐 Your application is now available at:${NC}"
    echo -e "${CYAN}   https://$STATIC_URL${NC}"
    echo -e "${CYAN}   Admin: https://$STATIC_URL/admin/${NC}"
    echo ""
    echo -e "${BLUE}📊 Service Status:${NC}"
    echo -e "   Django Server: Running on port $DJANGO_PORT"
    echo -e "   Ngrok Tunnel: Active with static URL"
    echo -e "   Tmux Session: $SERVICE_NAME"
    echo ""
}

# Create systemd service file
create_systemd_service() {
    print_info "Creating systemd service..."
    
    cat > /tmp/${SERVICE_NAME}.service << EOF
[Unit]
Description=NoctisPro Masterpiece Refined Service
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=$WORKSPACE_DIR
ExecStart=$WORKSPACE_DIR/deploy_masterpiece_service.sh start
ExecStop=$WORKSPACE_DIR/deploy_masterpiece_service.sh stop
ExecReload=$WORKSPACE_DIR/deploy_masterpiece_service.sh restart
PIDFile=$PID_FILE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    if [ -w /etc/systemd/system ]; then
        sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable ${SERVICE_NAME}.service
        print_success "Systemd service created and enabled"
    else
        print_warning "Cannot write to /etc/systemd/system (no sudo access)"
        cp /tmp/${SERVICE_NAME}.service "$WORKSPACE_DIR/"
        print_info "Service file saved to $WORKSPACE_DIR/${SERVICE_NAME}.service"
    fi
}

# Create init.d service script
create_initd_service() {
    print_info "Creating init.d service..."
    
    cat > /tmp/${SERVICE_NAME} << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          noctispro-masterpiece
# Required-Start:    $local_fs $network $named $time $syslog
# Required-Stop:     $local_fs $network $named $time $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       NoctisPro Masterpiece Refined Service
### END INIT INFO

SCRIPT_DIR="/workspace"
SCRIPT="$SCRIPT_DIR/deploy_masterpiece_service.sh"
LOCK_FILE="/var/lock/subsys/noctispro-masterpiece"

start() {
    if [ -f "$LOCK_FILE" ]; then
        echo "Service is already running"
        return 1
    fi
    
    echo "Starting NoctisPro Masterpiece Service..."
    $SCRIPT start
    
    if [ $? -eq 0 ]; then
        touch "$LOCK_FILE"
        echo "Service started successfully"
        return 0
    else
        echo "Failed to start service"
        return 1
    fi
}

stop() {
    if [ ! -f "$LOCK_FILE" ]; then
        echo "Service is not running"
        return 1
    fi
    
    echo "Stopping NoctisPro Masterpiece Service..."
    $SCRIPT stop
    
    if [ $? -eq 0 ]; then
        rm -f "$LOCK_FILE"
        echo "Service stopped successfully"
        return 0
    else
        echo "Failed to stop service"
        return 1
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        if [ -f "$LOCK_FILE" ]; then
            echo "Service is running"
        else
            echo "Service is stopped"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit $?
EOF

    if [ -w /etc/init.d ]; then
        sudo cp /tmp/${SERVICE_NAME} /etc/init.d/
        sudo chmod +x /etc/init.d/${SERVICE_NAME}
        
        # Enable service for different systems
        if command -v update-rc.d > /dev/null 2>&1; then
            sudo update-rc.d ${SERVICE_NAME} defaults
        elif command -v chkconfig > /dev/null 2>&1; then
            sudo chkconfig --add ${SERVICE_NAME}
            sudo chkconfig ${SERVICE_NAME} on
        fi
        
        print_success "Init.d service created and enabled"
    else
        print_warning "Cannot write to /etc/init.d (no sudo access)"
        cp /tmp/${SERVICE_NAME} "$WORKSPACE_DIR/"
        chmod +x "$WORKSPACE_DIR/${SERVICE_NAME}"
        print_info "Service script saved to $WORKSPACE_DIR/${SERVICE_NAME}"
    fi
}

# Create cron job for auto-start
create_cron_job() {
    print_info "Setting up cron job for auto-start..."
    
    if command -v crontab > /dev/null 2>&1; then
        # Remove existing cron jobs for this service
        (crontab -l 2>/dev/null | grep -v "${SERVICE_NAME}" | grep -v "deploy_masterpiece_service.sh") > /tmp/cron_tmp || true
        
        # Add new cron job
        echo "@reboot sleep 30 && $WORKSPACE_DIR/deploy_masterpiece_service.sh start > $WORKSPACE_DIR/autostart_${SERVICE_NAME}.log 2>&1" >> /tmp/cron_tmp
        
        crontab /tmp/cron_tmp
        rm -f /tmp/cron_tmp
        
        print_success "Cron job created for auto-start"
    else
        print_warning "Cron not available"
    fi
}

# Create profile-based auto-start (for containers/limited environments)
create_profile_autostart() {
    print_info "Setting up profile-based auto-start..."
    
    # Create auto-start script
    cat > "$WORKSPACE_DIR/autostart_masterpiece.sh" << EOF
#!/bin/bash
# Auto-start script for NoctisPro Masterpiece

# Check if already running
if tmux has-session -t $SERVICE_NAME 2>/dev/null; then
    echo "Service already running"
    exit 0
fi

# Wait for system to be ready
sleep 10

# Start the service
cd $WORKSPACE_DIR
./deploy_masterpiece_service.sh start > $WORKSPACE_DIR/autostart_${SERVICE_NAME}.log 2>&1 &

echo "Auto-start initiated"
EOF

    chmod +x "$WORKSPACE_DIR/autostart_masterpiece.sh"
    
    # Add to bashrc and profile
    for profile_file in ~/.bashrc ~/.profile; do
        if [ -f "$profile_file" ]; then
            # Remove existing auto-start lines
            grep -v "autostart_masterpiece.sh" "$profile_file" > "${profile_file}.tmp" 2>/dev/null || cp "$profile_file" "${profile_file}.tmp"
            
            # Add new auto-start line
            echo "" >> "${profile_file}.tmp"
            echo "# NoctisPro Masterpiece auto-start" >> "${profile_file}.tmp"
            echo "$WORKSPACE_DIR/autostart_masterpiece.sh 2>/dev/null || true" >> "${profile_file}.tmp"
            
            mv "${profile_file}.tmp" "$profile_file"
            print_success "Added auto-start to $profile_file"
        fi
    done
}

# Setup auto-start based on system type
setup_autostart() {
    print_info "Setting up auto-start for system bootup..."
    
    SYSTEM_TYPE=$(detect_system)
    print_info "Detected system type: $SYSTEM_TYPE"
    
    case $SYSTEM_TYPE in
        "systemd")
            create_systemd_service
            ;;
        "initd")
            create_initd_service
            ;;
        "legacy")
            print_warning "Legacy system detected - using alternative methods"
            ;;
    esac
    
    # Always setup cron and profile methods as backup
    create_cron_job
    create_profile_autostart
    
    print_success "Auto-start setup completed for $SYSTEM_TYPE system"
}

# Stop service
stop_service() {
    print_info "Stopping Masterpiece service..."
    
    # Kill tmux session
    if tmux has-session -t $SERVICE_NAME 2>/dev/null; then
        tmux kill-session -t $SERVICE_NAME
        print_success "Tmux session terminated"
    fi
    
    # Kill processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http.*$STATIC_URL" 2>/dev/null || true
    
    # Remove PID file
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
    
    print_success "Service stopped"
}

# Show service status
show_status() {
    echo ""
    echo -e "${BLUE}📊 Masterpiece Service Status:${NC}"
    echo ""
    
    # Check tmux session
    if tmux has-session -t $SERVICE_NAME 2>/dev/null; then
        echo -e "${GREEN}✅ Tmux Session: Running${NC}"
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
        echo -e "${RED}❌ Ngrok Tunnel: Not active${NC}"
    fi
    
    echo ""
    
    # Show auto-start status
    echo -e "${BLUE}🔧 Auto-Start Status:${NC}"
    [ -f /etc/systemd/system/${SERVICE_NAME}.service ] && echo -e "${GREEN}✅ Systemd service installed${NC}"
    [ -f /etc/init.d/${SERVICE_NAME} ] && echo -e "${GREEN}✅ Init.d service installed${NC}"
    crontab -l 2>/dev/null | grep -q "deploy_masterpiece_service.sh" && echo -e "${GREEN}✅ Cron job configured${NC}"
    [ -f "$WORKSPACE_DIR/autostart_masterpiece.sh" ] && echo -e "${GREEN}✅ Profile auto-start configured${NC}"
    
    echo ""
}

# Main function
main() {
    case "${1:-}" in
        "start")
            print_header
            check_ngrok || exit 1
            check_refined_system || exit 1
            stop_existing
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            stop_service
            sleep 2
            main start
            ;;
        "status")
            show_status
            ;;
        "setup-autostart")
            setup_autostart
            ;;
        "deploy")
            print_header
            check_ngrok || exit 1
            check_refined_system || exit 1
            stop_existing
            start_service
            setup_autostart
            echo ""
            print_success "🎉 Masterpiece deployment completed!"
            echo ""
            echo -e "${CYAN}🌐 Your application: https://$STATIC_URL${NC}"
            echo -e "${CYAN}🔧 Admin panel: https://$STATIC_URL/admin/${NC}"
            echo -e "${GREEN}🚀 Auto-start: Configured for system bootup${NC}"
            echo ""
            ;;
        *)
            echo -e "${BLUE}🚀 NoctisPro Masterpiece Service Manager${NC}"
            echo ""
            echo "Usage: $0 {start|stop|restart|status|setup-autostart|deploy}"
            echo ""
            echo "Commands:"
            echo "  start         - Start the service"
            echo "  stop          - Stop the service"
            echo "  restart       - Restart the service"
            echo "  status        - Show service status"
            echo "  setup-autostart - Configure auto-start only"
            echo "  deploy        - Full deployment with auto-start"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"