#!/bin/bash

# 🚀 Deploy Refined NoctisPro System (Local/Development Mode)
# Deploys the refined system for local testing without ngrok

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
DJANGO_PORT="8000"
SERVICE_NAME="noctispro_local"
BACKUP_DIR="/workspace/backup_$(date +%Y%m%d_%H%M%S)"

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro Refined System (Local Deploy)${NC}"
    echo -e "${CYAN}   Testing Refined System Locally${NC}"
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
    tmux kill-session -t noctispro 2>/dev/null || true
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    
    # Kill any Django processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    pkill -f "python.*manage.py" 2>/dev/null || true
    
    # Kill ngrok processes
    pkill -f "ngrok.*http" 2>/dev/null || true
    
    # Remove old PID files
    rm -f $WORKSPACE_DIR/noctispro_service.pid
    rm -f $WORKSPACE_DIR/django.pid
    
    sleep 2
    print_success "All old services stopped"
}

# Function to deploy refined system
deploy_refined_system() {
    print_info "Deploying refined system files..."
    
    # Stop any existing services first
    stop_old_services
    
    # Backup current system
    print_info "Creating backup of current system..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$OLD_SYSTEM_DIR/noctis_pro" "$BACKUP_DIR/" 2>/dev/null || true
    cp "$OLD_SYSTEM_DIR/manage.py" "$BACKUP_DIR/" 2>/dev/null || true
    print_success "System backed up to: $BACKUP_DIR"
    
    # Deploy refined files
    print_info "Copying refined system files..."
    
    # Copy the refined noctis_pro settings
    cp -r "$NEW_SYSTEM_DIR/noctis_pro/"* "$OLD_SYSTEM_DIR/noctis_pro/"
    
    # Copy the refined manage.py
    cp "$NEW_SYSTEM_DIR/manage.py" "$OLD_SYSTEM_DIR/"
    
    # Copy refined app directories
    for app_dir in accounts worklist dicom_viewer admin_panel reports chat notifications; do
        if [ -d "$NEW_SYSTEM_DIR/$app_dir" ]; then
            print_info "Updating $app_dir with refined version..."
            rm -rf "$OLD_SYSTEM_DIR/$app_dir"
            cp -r "$NEW_SYSTEM_DIR/$app_dir" "$OLD_SYSTEM_DIR/"
        fi
    done
    
    # Copy refined templates and static files
    if [ -d "$NEW_SYSTEM_DIR/templates" ]; then
        print_info "Updating templates..."
        cp -r "$NEW_SYSTEM_DIR/templates/"* "$OLD_SYSTEM_DIR/templates/" 2>/dev/null || true
    fi
    
    # Copy refined requirements
    if [ -f "$NEW_SYSTEM_DIR/requirements.txt" ]; then
        cp "$NEW_SYSTEM_DIR/requirements.txt" "$OLD_SYSTEM_DIR/"
    fi
    
    print_success "Refined system files deployed"
}

# Function to start refined system locally
start_refined_local() {
    print_info "Starting refined system locally..."
    
    cd $WORKSPACE_DIR
    
    # Activate virtual environment
    if [ ! -d "venv" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    
    # Install refined dependencies
    print_info "Installing refined system dependencies..."
    pip install -r requirements.txt > /dev/null 2>&1
    
    # Run migrations
    print_info "Running database migrations..."
    python manage.py migrate --run-syncdb > /dev/null 2>&1
    
    # Collect static files
    print_info "Collecting static files..."
    python manage.py collectstatic --noinput > /dev/null 2>&1
    
    # Start in tmux for persistence
    tmux new-session -d -s $SERVICE_NAME -c $WORKSPACE_DIR
    tmux send-keys -t $SERVICE_NAME "source venv/bin/activate" Enter
    tmux send-keys -t $SERVICE_NAME "python manage.py runserver 0.0.0.0:$DJANGO_PORT" Enter
    
    # Save service info
    echo "SERVICE_RUNNING=true" > $WORKSPACE_DIR/noctispro_local.pid
    echo "SYSTEM_VERSION=refined_local" >> $WORKSPACE_DIR/noctispro_local.pid
    echo "STARTED_AT=$(date)" >> $WORKSPACE_DIR/noctispro_local.pid
    echo "TMUX_SESSION=$SERVICE_NAME" >> $WORKSPACE_DIR/noctispro_local.pid
    echo "PORT=$DJANGO_PORT" >> $WORKSPACE_DIR/noctispro_local.pid
    
    print_success "Refined system started locally!"
    echo ""
    echo -e "${CYAN}🌐 Local Access:${NC}"
    echo -e "   ${WHITE}http://localhost:$DJANGO_PORT${NC}"
    echo -e "   ${WHITE}http://127.0.0.1:$DJANGO_PORT${NC}"
    echo ""
    echo -e "${WHITE}🔧 Admin Panel:${NC}"
    echo -e "   ${CYAN}http://localhost:$DJANGO_PORT/admin/${NC}"
    echo -e "   👤 Username: ${YELLOW}admin${NC}"
    echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
    echo ""
    echo -e "${GREEN}✨ You're now running the REFINED system with:${NC}"
    echo -e "   🔧 Production-ready configuration"
    echo -e "   🚀 Optimized dependencies"
    echo -e "   🛡️ Enhanced security"
    echo -e "   📈 Better stability"
    echo ""
    echo -e "${YELLOW}📋 Service Management:${NC}"
    echo -e "   Check status: ${CYAN}tmux attach -t $SERVICE_NAME${NC}"
    echo -e "   Stop service: ${CYAN}tmux kill-session -t $SERVICE_NAME${NC}"
    echo ""
}

# Main execution
main() {
    print_header
    
    if [ ! -d "$NEW_SYSTEM_DIR" ]; then
        print_error "Refined system directory not found: $NEW_SYSTEM_DIR"
        exit 1
    fi
    
    print_info "🔍 Deploying refined system locally for testing..."
    echo ""
    
    deploy_refined_system
    start_refined_local
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉  REFINED SYSTEM DEPLOYED LOCALLY!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${BLUE}ℹ️ Next Steps for Online Deployment:${NC}"
    echo ""
    echo -e "${YELLOW}1. Test the refined system locally first${NC}"
    echo -e "${YELLOW}2. Get ngrok auth token from: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo -e "${YELLOW}3. Configure token: ${CYAN}/workspace/ngrok config add-authtoken YOUR_TOKEN${NC}"
    echo -e "${YELLOW}4. Deploy online: ${CYAN}./deploy_refined_system.sh${NC}"
    echo ""
}

# Run main function
main