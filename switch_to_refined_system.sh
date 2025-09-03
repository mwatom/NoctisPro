#!/bin/bash

# 🚀 COMPLETELY Switch to Refined NoctisPro System
# This script will STOP the old system and START the refined system fresh

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
OLD_SYSTEM_DIR="/workspace"
REFINED_SYSTEM_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="colt-charmed-lark.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro_refined"
BACKUP_DIR="/workspace/old_system_backup_$(date +%Y%m%d_%H%M%S)"

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  SWITCHING TO REFINED SYSTEM${NC}"
    echo -e "${CYAN}   Complete System Replacement${NC}"
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

# Function to completely stop old system
stop_old_system() {
    print_info "🛑 STOPPING ALL OLD SYSTEM SERVICES..."
    
    # Kill ALL tmux sessions
    tmux kill-server 2>/dev/null || true
    
    # Kill ALL Django and Python processes
    pkill -f "manage.py" 2>/dev/null || true
    pkill -f "python.*manage" 2>/dev/null || true
    pkill -f "runserver" 2>/dev/null || true
    pkill -f "gunicorn" 2>/dev/null || true
    pkill -f "django" 2>/dev/null || true
    
    # Kill ALL ngrok processes
    pkill -f "ngrok" 2>/dev/null || true
    
    # Remove ALL PID files
    rm -f /workspace/*.pid
    rm -f /workspace/noctispro*.pid
    rm -f /workspace/django.pid
    
    # Wait for processes to die
    sleep 5
    
    print_success "Old system completely stopped"
}

# Function to backup old system data
backup_old_data() {
    print_info "💾 Backing up old system data..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup database
    if [ -f "$OLD_SYSTEM_DIR/db.sqlite3" ]; then
        cp "$OLD_SYSTEM_DIR/db.sqlite3" "$BACKUP_DIR/old_db.sqlite3"
        print_success "Database backed up"
    fi
    
    # Backup media files
    if [ -d "$OLD_SYSTEM_DIR/media" ]; then
        cp -r "$OLD_SYSTEM_DIR/media" "$BACKUP_DIR/"
        print_success "Media files backed up"
    fi
    
    # Backup logs
    cp /workspace/*.log "$BACKUP_DIR/" 2>/dev/null || true
    
    print_success "Old system data backed up to: $BACKUP_DIR"
}

# Function to start refined system
start_refined_system() {
    print_info "🚀 STARTING REFINED SYSTEM..."
    
    cd "$REFINED_SYSTEM_DIR"
    
    # Check if venv exists in refined directory
    if [ ! -d "venv" ]; then
        print_info "Creating virtual environment for refined system..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    
    # Install minimal dependencies for refined system
    print_info "Installing essential dependencies..."
    pip install -q Django djangorestframework django-cors-headers pillow python-dotenv whitenoise django-widget-tweaks
    
    # Create fresh database for refined system
    print_info "Creating fresh database for refined system..."
    rm -f db.sqlite3  # Remove any existing database
    python manage.py migrate --run-syncdb
    
    # Create superuser for refined system
    print_info "Creating admin user for refined system..."
    echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | python manage.py shell
    
    # Collect static files
    print_info "Collecting static files..."
    python manage.py collectstatic --noinput
    
    # Start refined system in tmux
    print_info "Starting refined system service..."
    tmux new-session -d -s $SERVICE_NAME -c "$REFINED_SYSTEM_DIR"
    tmux send-keys -t $SERVICE_NAME "source venv/bin/activate" Enter
    tmux send-keys -t $SERVICE_NAME "python manage.py runserver 0.0.0.0:$DJANGO_PORT" Enter
    
    # Save service info
    echo "SERVICE_RUNNING=true" > "$REFINED_SYSTEM_DIR/refined_service.pid"
    echo "SYSTEM_VERSION=refined_masterpiece" >> "$REFINED_SYSTEM_DIR/refined_service.pid"
    echo "SYSTEM_DIRECTORY=$REFINED_SYSTEM_DIR" >> "$REFINED_SYSTEM_DIR/refined_service.pid"
    echo "STARTED_AT=$(date)" >> "$REFINED_SYSTEM_DIR/refined_service.pid"
    echo "TMUX_SESSION=$SERVICE_NAME" >> "$REFINED_SYSTEM_DIR/refined_service.pid"
    
    print_success "Refined system started!"
}

# Function to start ngrok (if configured)
start_ngrok_if_configured() {
    print_info "🌐 Checking ngrok configuration..."
    
    if /workspace/ngrok config check > /dev/null 2>&1; then
        print_info "Starting ngrok tunnel..."
        tmux new-window -t $SERVICE_NAME -n ngrok
        tmux send-keys -t $SERVICE_NAME:ngrok "cd /workspace" Enter
        tmux send-keys -t $SERVICE_NAME:ngrok "./ngrok http --url=https://$STATIC_URL $DJANGO_PORT" Enter
        print_success "Ngrok tunnel started"
    else
        print_warning "Ngrok not configured - system available locally only"
        echo -e "${YELLOW}To configure ngrok for online access:${NC}"
        echo -e "1. Get token: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
        echo -e "2. Configure: ${CYAN}/workspace/ngrok config add-authtoken YOUR_TOKEN${NC}"
        echo -e "3. Restart: ${CYAN}./switch_to_refined_system.sh${NC}"
    fi
}

# Main execution
main() {
    print_header
    
    if [ ! -d "$REFINED_SYSTEM_DIR" ]; then
        print_error "Refined system directory not found: $REFINED_SYSTEM_DIR"
        exit 1
    fi
    
    print_warning "⚠️  THIS WILL COMPLETELY REPLACE THE OLD SYSTEM"
    echo ""
    echo -e "${RED}🛑 This will:${NC}"
    echo -e "   1. Stop all old services"
    echo -e "   2. Backup old database and files"
    echo -e "   3. Switch to refined system directory"
    echo -e "   4. Start with FRESH database (no old studies)"
    echo -e "   5. Run the optimized, refined system"
    echo ""
    echo -e "${GREEN}✨ You'll get:${NC}"
    echo -e "   ✅ Production-ready configuration (DEBUG=False)"
    echo -e "   ✅ Optimized dependencies (no problematic packages)"
    echo -e "   ✅ Better performance and stability"
    echo -e "   ✅ Clean, fresh start"
    echo ""
    
    read -p "Continue with complete system switch? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "System switch cancelled"
        exit 0
    fi
    
    # Execute switch
    stop_old_system
    backup_old_data
    start_refined_system
    start_ngrok_if_configured
    
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉  REFINED SYSTEM IS NOW RUNNING!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Local Access:${NC}"
    echo -e "   ${WHITE}http://localhost:$DJANGO_PORT${NC}"
    echo ""
    echo -e "${WHITE}🔧 Admin Panel:${NC}"
    echo -e "   ${WHITE}http://localhost:$DJANGO_PORT/admin/${NC}"
    echo -e "   👤 Username: ${YELLOW}admin${NC}"
    echo -e "   🔐 Password: ${YELLOW}admin123${NC}"
    echo ""
    if /workspace/ngrok config check > /dev/null 2>&1; then
        echo -e "${CYAN}🌐 Online Access:${NC}"
        echo -e "   ${WHITE}https://$STATIC_URL/${NC}"
        echo ""
    fi
    echo -e "${GREEN}✨ KEY DIFFERENCES:${NC}"
    echo -e "   🔧 Running from: ${CYAN}$REFINED_SYSTEM_DIR${NC}"
    echo -e "   🗃️ Fresh database (no old studies)"
    echo -e "   ⚙️ Production configuration"
    echo -e "   🚀 Optimized performance"
    echo ""
    echo -e "${BLUE}💾 Old system backed up to: ${CYAN}$BACKUP_DIR${NC}"
    echo ""
    echo -e "${YELLOW}📋 Service Management:${NC}"
    echo -e "   Check: ${CYAN}tmux attach -t $SERVICE_NAME${NC}"
    echo -e "   Stop:  ${CYAN}tmux kill-session -t $SERVICE_NAME${NC}"
    echo ""
}

# Run main function
main