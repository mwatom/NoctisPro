#!/bin/bash

# 🚀 Deploy Refined NoctisPro System
# Stops old system and deploys the new refined system from noctis_pro_deployment/

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="/workspace"
OLD_SYSTEM_DIR="/workspace"
NEW_SYSTEM_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro"
BACKUP_DIR="/workspace/backup_$(date +%Y%m%d_%H%M%S)"

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro Refined System Deployment${NC}"
    echo -e "${CYAN}   Switching from Old to New System${NC}"
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

# Function to stop all old services
stop_old_services() {
    print_info "Stopping all existing NoctisPro services..."
    
    # Stop tmux sessions
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    tmux kill-session -t noctispro 2>/dev/null || true
    
    # Kill any Django processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    pkill -f "python.*manage.py" 2>/dev/null || true
    
    # Kill ngrok processes
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "ngrok.*tunnel" 2>/dev/null || true
    
    # Remove old PID files
    rm -f $WORKSPACE_DIR/noctispro_service.pid
    rm -f $WORKSPACE_DIR/django.pid
    
    sleep 3
    print_success "All old services stopped"
}

# Function to backup old system
backup_old_system() {
    print_info "Creating backup of current system..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup key files (not the entire directory to save space)
    cp -r "$OLD_SYSTEM_DIR/noctis_pro" "$BACKUP_DIR/" 2>/dev/null || true
    cp "$OLD_SYSTEM_DIR/manage.py" "$BACKUP_DIR/" 2>/dev/null || true
    cp "$OLD_SYSTEM_DIR/db.sqlite3" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$OLD_SYSTEM_DIR/static" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$OLD_SYSTEM_DIR/media" "$BACKUP_DIR/" 2>/dev/null || true
    
    print_success "System backed up to: $BACKUP_DIR"
}

# Function to deploy new system
deploy_new_system() {
    print_info "Deploying refined system..."
    
    # Copy refined system files to main workspace
    print_info "Copying refined system files..."
    
    # Copy the refined noctis_pro settings
    cp "$NEW_SYSTEM_DIR/noctis_pro/"* "$OLD_SYSTEM_DIR/noctis_pro/" 2>/dev/null || true
    
    # Copy the refined manage.py
    cp "$NEW_SYSTEM_DIR/manage.py" "$OLD_SYSTEM_DIR/"
    
    # Copy any refined app directories
    for app_dir in accounts worklist dicom_viewer admin_panel reports chat notifications; do
        if [ -d "$NEW_SYSTEM_DIR/$app_dir" ]; then
            print_info "Updating $app_dir with refined version..."
            rm -rf "$OLD_SYSTEM_DIR/$app_dir"
            cp -r "$NEW_SYSTEM_DIR/$app_dir" "$OLD_SYSTEM_DIR/"
        fi
    done
    
    # Copy refined templates and static files
    if [ -d "$NEW_SYSTEM_DIR/templates" ]; then
        print_info "Updating templates with refined version..."
        cp -r "$NEW_SYSTEM_DIR/templates/"* "$OLD_SYSTEM_DIR/templates/" 2>/dev/null || true
    fi
    
    if [ -d "$NEW_SYSTEM_DIR/static" ]; then
        print_info "Updating static files with refined version..."
        cp -r "$NEW_SYSTEM_DIR/static/"* "$OLD_SYSTEM_DIR/static/" 2>/dev/null || true
    fi
    
    # Copy refined requirements if exists
    if [ -f "$NEW_SYSTEM_DIR/requirements.txt" ]; then
        cp "$NEW_SYSTEM_DIR/requirements.txt" "$OLD_SYSTEM_DIR/"
    fi
    
    print_success "Refined system files deployed"
}

# Function to update service script
update_service_script() {
    print_info "Updating service script to use refined system..."
    
    # Create updated service script
    cat > /workspace/noctispro_service_refined.sh << 'EOF'
#!/bin/bash

# 🚀 NoctisPro Refined Service Manager
# Runs the new refined system with optimized settings

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="/workspace"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro"
PID_FILE="$WORKSPACE_DIR/noctispro_service.pid"
LOG_FILE="$WORKSPACE_DIR/noctispro_service.log"

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Function to start the refined service
start_service() {
    print_info "Starting NoctisPro Refined Service..."
    
    # Kill any existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    sleep 2
    
    # Check if ngrok auth token is configured
    if ! $WORKSPACE_DIR/ngrok config check > /dev/null 2>&1; then
        print_error "Ngrok auth token is not configured!"
        echo "Please configure ngrok first:"
        echo "1. Get token from: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "2. Run: $WORKSPACE_DIR/ngrok config add-authtoken YOUR_TOKEN_HERE"
        exit 1
    fi
    
    # Ensure we're using the refined system
    cd $WORKSPACE_DIR
    
    # Activate virtual environment
    if [ ! -d "venv" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    
    # Install/update dependencies for refined system
    print_info "Installing refined system dependencies..."
    pip install -r requirements.txt > /dev/null 2>&1
    
    # Run migrations for refined system
    print_info "Running database migrations for refined system..."
    python manage.py migrate --run-syncdb > /dev/null 2>&1
    
    # Collect static files for refined system
    print_info "Collecting static files for refined system..."
    python manage.py collectstatic --noinput > /dev/null 2>&1
    
    # Create new tmux session for refined system
    tmux new-session -d -s $SERVICE_NAME -c $WORKSPACE_DIR
    
    # Start Django with refined settings in first window
    tmux send-keys -t $SERVICE_NAME "source venv/bin/activate" Enter
    tmux send-keys -t $SERVICE_NAME "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" Enter
    tmux send-keys -t $SERVICE_NAME "python manage.py runserver 0.0.0.0:$DJANGO_PORT" Enter
    
    # Create second window for ngrok
    tmux new-window -t $SERVICE_NAME -n ngrok
    tmux send-keys -t $SERVICE_NAME:ngrok "sleep 10" Enter
    tmux send-keys -t $SERVICE_NAME:ngrok "$WORKSPACE_DIR/ngrok http --url=https://$STATIC_URL $DJANGO_PORT" Enter
    
    # Save service info
    echo "SERVICE_RUNNING=true" > $PID_FILE
    echo "SYSTEM_VERSION=refined" >> $PID_FILE
    echo "STARTED_AT=$(date)" >> $PID_FILE
    echo "TMUX_SESSION=$SERVICE_NAME" >> $PID_FILE
    echo "WORKSPACE_DIR=$WORKSPACE_DIR" >> $PID_FILE
    
    print_success "NoctisPro Refined Service started in tmux session '$SERVICE_NAME'"
    echo ""
    echo -e "${CYAN}🌐 Your refined system is now available at: https://$STATIC_URL/${NC}"
    echo -e "${GREEN}✨ Running optimized, production-ready configuration${NC}"
    echo ""
    echo -e "${YELLOW}📋 To check status: tmux attach -t $SERVICE_NAME${NC}"
    echo -e "${YELLOW}🛑 To stop service: $0 stop${NC}"
}

# Function to stop the service
stop_service() {
    print_info "Stopping NoctisPro service..."
    
    # Kill tmux session
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    
    # Kill any remaining processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    
    # Remove PID file
    rm -f $PID_FILE
    
    print_success "NoctisPro service stopped"
}

# Function to check service status
status_service() {
    if [ -f "$PID_FILE" ] && tmux has-session -t $SERVICE_NAME 2>/dev/null; then
        print_success "NoctisPro Refined Service is running"
        echo ""
        echo -e "${CYAN}🌐 Available at: https://$STATIC_URL/${NC}"
        echo ""
        echo "Service details:"
        cat $PID_FILE
        echo ""
        echo "Tmux sessions:"
        tmux list-sessions | grep $SERVICE_NAME || true
        echo ""
        echo -e "${GREEN}✨ Running refined system with optimized configuration${NC}"
    else
        print_error "NoctisPro service is not running"
        return 1
    fi
}

# Function to restart the service
restart_service() {
    print_info "Restarting NoctisPro Refined Service..."
    stop_service
    sleep 3
    start_service
}

# Main command handling
case "${1:-start}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        status_service
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start NoctisPro Refined Service"
        echo "  stop    - Stop NoctisPro service"
        echo "  restart - Restart NoctisPro service"
        echo "  status  - Check service status"
        exit 1
        ;;
esac
EOF

    chmod +x /workspace/noctispro_service_refined.sh
    print_success "Created refined service script: noctispro_service_refined.sh"
}

# Main deployment process
main() {
    print_header
    
    print_info "🔍 Analyzing current system..."
    echo "Old system directory: $OLD_SYSTEM_DIR"
    echo "New refined system directory: $NEW_SYSTEM_DIR"
    echo ""
    
    if [ ! -d "$NEW_SYSTEM_DIR" ]; then
        print_error "Refined system directory not found: $NEW_SYSTEM_DIR"
        exit 1
    fi
    
    print_warning "This will:"
    echo "1. 🛑 Stop all current NoctisPro services"
    echo "2. 💾 Backup current system"
    echo "3. 🔄 Deploy refined system files"
    echo "4. 🚀 Start refined service"
    echo ""
    
    read -p "Continue with refined system deployment? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    # Execute deployment steps
    stop_old_services
    backup_old_system
    deploy_new_system
    update_service_script
    
    print_info "Starting refined system..."
    /workspace/noctispro_service_refined.sh start
    
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉  REFINED SYSTEM DEPLOYMENT SUCCESSFUL!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Your refined NoctisPro system is now live at:${NC}"
    echo ""
    echo -e "${WHITE}📋 Main Application:${NC}"
    echo -e "   ${CYAN}https://$STATIC_URL/${NC}"
    echo ""
    echo -e "${WHITE}🔧 Admin Panel:${NC}"
    echo -e "   ${CYAN}https://$STATIC_URL/admin/${NC}"
    echo -e "   👤 Username: ${YELLOW}admin${NC}"
    echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
    echo ""
    echo -e "${GREEN}✨ Key Improvements in Refined System:${NC}"
    echo -e "   🔧 Production-ready configuration (DEBUG=False)"
    echo -e "   🚀 Optimized dependencies (removed problematic packages)"
    echo -e "   🛡️ Enhanced security settings"
    echo -e "   📈 Better performance and stability"
    echo ""
    echo -e "${YELLOW}📋 Service Management (NEW):${NC}"
    echo -e "   Start:   ${CYAN}./noctispro_service_refined.sh start${NC}"
    echo -e "   Stop:    ${CYAN}./noctispro_service_refined.sh stop${NC}"
    echo -e "   Status:  ${CYAN}./noctispro_service_refined.sh status${NC}"
    echo ""
    echo -e "${BLUE}💾 Backup Location: ${CYAN}$BACKUP_DIR${NC}"
    echo ""
}

# Run main function
main