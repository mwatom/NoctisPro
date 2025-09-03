#!/bin/bash

# 🚀 Remove Old NoctisPro Service & Setup New Refined System
# Complete service replacement for Ubuntu server deployment

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
OLD_WORKSPACE="/workspace"
NEW_WORKSPACE="/workspace/noctis_pro_deployment"
SERVICE_NAME="noctispro-refined"
SERVICE_USER="ubuntu"
DJANGO_PORT="8000"
STATIC_URL="colt-charmed-lark.ngrok-free.app"

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  Ubuntu Server Service Setup${NC}"
    echo -e "${CYAN}   Remove Old → Install New Refined System${NC}"
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

# Function to remove old services
remove_old_services() {
    print_info "🛑 Removing ALL old NoctisPro services..."
    
    # Stop and disable old systemd services
    sudo systemctl stop noctispro 2>/dev/null || true
    sudo systemctl disable noctispro 2>/dev/null || true
    sudo systemctl stop noctispro.service 2>/dev/null || true
    sudo systemctl disable noctispro.service 2>/dev/null || true
    
    # Remove old service files
    sudo rm -f /etc/systemd/system/noctispro.service
    sudo rm -f /etc/systemd/system/noctispro-*.service
    sudo rm -f /lib/systemd/system/noctispro*.service
    
    # Remove old init.d scripts
    sudo rm -f /etc/init.d/noctispro
    sudo rm -f /etc/init.d/noctispro-*
    
    # Remove old cron jobs
    crontab -l 2>/dev/null | grep -v "noctispro" | crontab - 2>/dev/null || true
    sudo crontab -l 2>/dev/null | grep -v "noctispro" | sudo crontab - 2>/dev/null || true
    
    # Kill any running processes
    sudo pkill -f "noctispro" 2>/dev/null || true
    sudo pkill -f "manage.py runserver" 2>/dev/null || true
    sudo pkill -f "ngrok.*http" 2>/dev/null || true
    tmux kill-server 2>/dev/null || true
    
    # Remove old auto-start entries from bashrc/profile
    sed -i '/noctispro/d' ~/.bashrc 2>/dev/null || true
    sed -i '/noctispro/d' ~/.profile 2>/dev/null || true
    sudo sed -i '/noctispro/d' /etc/rc.local 2>/dev/null || true
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    print_success "All old NoctisPro services removed"
}

# Function to create new systemd service
create_new_service() {
    print_info "🆕 Creating new refined system service..."
    
    # Create service script
    cat > /tmp/noctispro-refined-service.sh << EOF
#!/bin/bash

# NoctisPro Refined System Service Script
set -euo pipefail

WORKSPACE_DIR="$NEW_WORKSPACE"
DJANGO_PORT="$DJANGO_PORT"
STATIC_URL="$STATIC_URL"
LOG_FILE="\$WORKSPACE_DIR/service.log"

# Function to start service
start_service() {
    echo "\$(date): Starting NoctisPro Refined Service..." >> \$LOG_FILE
    
    cd \$WORKSPACE_DIR
    
    # Kill any existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    tmux kill-session -t noctispro-refined 2>/dev/null || true
    sleep 2
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Start Django in tmux session
    tmux new-session -d -s noctispro-refined -c \$WORKSPACE_DIR
    tmux send-keys -t noctispro-refined "source venv/bin/activate" Enter
    tmux send-keys -t noctispro-refined "python manage.py runserver 0.0.0.0:\$DJANGO_PORT" Enter
    
    # Start ngrok if configured
    if /workspace/ngrok config check > /dev/null 2>&1; then
        sleep 5
        tmux new-window -t noctispro-refined -n ngrok
        tmux send-keys -t noctispro-refined:ngrok "/workspace/ngrok http --url=https://\$STATIC_URL \$DJANGO_PORT" Enter
        echo "\$(date): Ngrok tunnel started" >> \$LOG_FILE
    else
        echo "\$(date): Ngrok not configured - running locally only" >> \$LOG_FILE
    fi
    
    echo "\$(date): NoctisPro Refined Service started successfully" >> \$LOG_FILE
}

# Function to stop service
stop_service() {
    echo "\$(date): Stopping NoctisPro Refined Service..." >> \$LOG_FILE
    tmux kill-session -t noctispro-refined 2>/dev/null || true
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    echo "\$(date): NoctisPro Refined Service stopped" >> \$LOG_FILE
}

case "\${1:-start}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 3
        start_service
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF
    
    # Move and make executable
    sudo mv /tmp/noctispro-refined-service.sh /usr/local/bin/noctispro-refined-service.sh
    sudo chmod +x /usr/local/bin/noctispro-refined-service.sh
    
    print_success "Service script created: /usr/local/bin/noctispro-refined-service.sh"
}

# Function to create systemd service
create_systemd_service() {
    print_info "⚙️ Creating systemd service for refined system..."
    
    sudo tee /etc/systemd/system/noctispro-refined.service > /dev/null << EOF
[Unit]
Description=NoctisPro Refined Medical Imaging System
After=network.target
Wants=network.target

[Service]
Type=forking
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$NEW_WORKSPACE
Environment=PATH=/usr/bin:/usr/local/bin
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
ExecStart=/usr/local/bin/noctispro-refined-service.sh start
ExecStop=/usr/local/bin/noctispro-refined-service.sh stop
ExecReload=/usr/local/bin/noctispro-refined-service.sh restart
Restart=always
RestartSec=10
StandardOutput=append:$NEW_WORKSPACE/service.log
StandardError=append:$NEW_WORKSPACE/service.log

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable noctispro-refined.service
    
    print_success "Systemd service created and enabled: noctispro-refined.service"
}

# Function to setup dependencies
setup_dependencies() {
    print_info "📦 Setting up dependencies for refined system..."
    
    cd $NEW_WORKSPACE
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_info "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    
    # Install essential dependencies
    print_info "Installing refined system dependencies..."
    pip install -q Django djangorestframework django-cors-headers pillow python-dotenv whitenoise django-widget-tweaks
    pip install -q pydicom pynetdicom numpy matplotlib opencv-python
    
    # Run migrations
    print_info "Setting up database..."
    python manage.py migrate --run-syncdb > /dev/null 2>&1
    
    # Create superuser
    print_info "Creating admin user..."
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').delete(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | python manage.py shell
    
    # Collect static files
    print_info "Collecting static files..."
    python manage.py collectstatic --noinput > /dev/null 2>&1
    
    print_success "Dependencies and database setup complete"
}

# Function to create management commands
create_management_commands() {
    print_info "📋 Creating service management commands..."
    
    # Create easy management script
    cat > $NEW_WORKSPACE/manage_service.sh << 'EOF'
#!/bin/bash

# Easy NoctisPro Refined Service Management

case "${1:-status}" in
    start)
        echo "🚀 Starting NoctisPro Refined Service..."
        sudo systemctl start noctispro-refined
        sleep 3
        sudo systemctl status noctispro-refined --no-pager
        ;;
    stop)
        echo "🛑 Stopping NoctisPro Refined Service..."
        sudo systemctl stop noctispro-refined
        echo "✅ Service stopped"
        ;;
    restart)
        echo "🔄 Restarting NoctisPro Refined Service..."
        sudo systemctl restart noctispro-refined
        sleep 3
        sudo systemctl status noctispro-refined --no-pager
        ;;
    status)
        echo "📊 NoctisPro Refined Service Status:"
        sudo systemctl status noctispro-refined --no-pager
        echo ""
        echo "🔗 If running, access at:"
        echo "   Local: http://localhost:8000/"
        echo "   Admin: http://localhost:8000/admin/ (admin/admin123)"
        if /workspace/ngrok config check > /dev/null 2>&1; then
            echo "   Online: https://colt-charmed-lark.ngrok-free.app/"
        else
            echo "   Online: Configure ngrok for internet access"
        fi
        ;;
    logs)
        echo "📜 Service Logs:"
        tail -f $NEW_WORKSPACE/service.log
        ;;
    enable)
        echo "⚙️ Enabling auto-start on boot..."
        sudo systemctl enable noctispro-refined
        echo "✅ Service will auto-start on boot"
        ;;
    disable)
        echo "⚙️ Disabling auto-start on boot..."
        sudo systemctl disable noctispro-refined
        echo "✅ Service will not auto-start on boot"
        ;;
    *)
        echo "NoctisPro Refined Service Management"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the refined service"
        echo "  stop     - Stop the refined service"
        echo "  restart  - Restart the refined service"
        echo "  status   - Show service status and access URLs"
        echo "  logs     - Show real-time service logs"
        echo "  enable   - Enable auto-start on boot"
        echo "  disable  - Disable auto-start on boot"
        ;;
esac
EOF
    
    chmod +x $NEW_WORKSPACE/manage_service.sh
    
    print_success "Management script created: $NEW_WORKSPACE/manage_service.sh"
}

# Function to test the new service
test_new_service() {
    print_info "🧪 Testing new refined service..."
    
    # Start the service
    sudo systemctl start noctispro-refined
    sleep 10
    
    # Check if it's running
    if sudo systemctl is-active --quiet noctispro-refined; then
        print_success "✅ Refined service is running successfully!"
        
        # Test HTTP response
        if curl -s http://localhost:8000/ > /dev/null 2>&1; then
            print_success "✅ HTTP server is responding"
        else
            print_warning "⚠️ HTTP server not responding yet (may need more time)"
        fi
        
        # Show status
        echo ""
        echo -e "${CYAN}📊 Service Status:${NC}"
        sudo systemctl status noctispro-refined --no-pager
        
    else
        print_error "❌ Service failed to start"
        echo ""
        echo -e "${RED}🔍 Check logs:${NC}"
        sudo journalctl -u noctispro-refined --no-pager -n 20
        return 1
    fi
}

# Main execution
main() {
    print_header
    
    print_warning "This script will:"
    echo "1. 🛑 Remove ALL old NoctisPro services and auto-start configurations"
    echo "2. 🆕 Create new systemd service for refined system"
    echo "3. ⚙️ Configure auto-start on boot"
    echo "4. 🧪 Test the new service"
    echo "5. 📋 Provide management commands"
    echo ""
    
    if [ ! -d "$NEW_WORKSPACE" ]; then
        print_error "Refined system directory not found: $NEW_WORKSPACE"
        print_info "Make sure you've cloned the refined system first!"
        exit 1
    fi
    
    read -p "Continue with service setup? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Service setup cancelled"
        exit 0
    fi
    
    # Execute setup steps
    remove_old_services
    setup_dependencies
    create_new_service
    create_systemd_service
    create_management_commands
    test_new_service
    
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉  NEW REFINED SERVICE SETUP COMPLETE!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Your refined NoctisPro system is now running:${NC}"
    echo ""
    echo -e "${WHITE}📋 Local Access:${NC}"
    echo -e "   Main: ${CYAN}http://localhost:$DJANGO_PORT/${NC}"
    echo -e "   Admin: ${CYAN}http://localhost:$DJANGO_PORT/admin/${NC}"
    echo -e "   DICOM Viewer: ${CYAN}http://localhost:$DJANGO_PORT/dicom-viewer/${NC}"
    echo ""
    echo -e "${WHITE}👤 Login Credentials:${NC}"
    echo -e "   Username: ${YELLOW}admin${NC}"
    echo -e "   Password: ${YELLOW}admin123${NC}"
    echo ""
    echo -e "${WHITE}🔧 Service Management:${NC}"
    echo -e "   Quick Status: ${CYAN}$NEW_WORKSPACE/manage_service.sh status${NC}"
    echo -e "   Start: ${CYAN}$NEW_WORKSPACE/manage_service.sh start${NC}"
    echo -e "   Stop: ${CYAN}$NEW_WORKSPACE/manage_service.sh stop${NC}"
    echo -e "   Restart: ${CYAN}$NEW_WORKSPACE/manage_service.sh restart${NC}"
    echo -e "   View Logs: ${CYAN}$NEW_WORKSPACE/manage_service.sh logs${NC}"
    echo ""
    echo -e "${WHITE}⚙️ System Service:${NC}"
    echo -e "   Service Name: ${YELLOW}noctispro-refined${NC}"
    echo -e "   Auto-Start: ${GREEN}✅ Enabled${NC}"
    echo -e "   Check Status: ${CYAN}sudo systemctl status noctispro-refined${NC}"
    echo ""
    echo -e "${GREEN}🎯 Key Improvements:${NC}"
    echo -e "   ✅ Production configuration (DEBUG=False)"
    echo -e "   ✅ Optimized dependencies (no Redis issues)"
    echo -e "   ✅ Proper systemd integration"
    echo -e "   ✅ Auto-restart on failure"
    echo -e "   ✅ Clean service management"
    echo ""
    echo -e "${YELLOW}🌐 For Online Access:${NC}"
    echo -e "   1. Get ngrok token: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo -e "   2. Configure: ${CYAN}/workspace/ngrok config add-authtoken YOUR_TOKEN${NC}"
    echo -e "   3. Restart service: ${CYAN}$NEW_WORKSPACE/manage_service.sh restart${NC}"
    echo ""
    echo -e "${GREEN}🎊 Your refined masterpiece system will now auto-start on every boot!${NC}"
}

# Run main function
main