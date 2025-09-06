#!/bin/bash

# 🚀 NoctisPro PACS - Complete Installation Script
# Works in any environment (with or without systemd)
# Handles all dependencies and deployment scenarios

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DJANGO_PORT="8000"
NGROK_STATIC_URL="mallard-shining-curiously.ngrok-free.app"

print_header() {
    clear
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  NoctisPro PACS - Complete Installation${NC}"
    echo -e "${CYAN}   Universal Deployment Solution${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]] && command -v apt-get &> /dev/null; then
        print_info "Root access needed for system packages. Restarting with sudo..."
        exec sudo "$0" "$@"
    fi
}

install_system_dependencies() {
    print_info "Installing system dependencies..."
    
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        apt-get update -qq || print_warning "Package update failed, continuing with cached packages"
        
        # Essential packages
        apt-get install -y python3-pip python3-dev build-essential curl || print_warning "Some essential packages failed to install"
        
        # Optional packages for better functionality
        apt-get install -y libcups2-dev libssl-dev libffi-dev libjpeg-dev libpng-dev pkg-config python3-venv git 2>/dev/null || print_warning "Some optional packages failed to install"
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        yum install -y python3-pip python3-devel gcc gcc-c++ make curl || print_warning "Some packages failed to install"
        
    elif command -v apk &> /dev/null; then
        # Alpine
        apk add --no-cache python3-dev py3-pip build-base curl || print_warning "Some packages failed to install"
    else
        print_warning "Unknown package manager, skipping system dependencies"
    fi
    
    print_success "System dependencies installation completed"
}

install_python_dependencies() {
    print_info "Installing Python dependencies..."
    cd "$WORKSPACE_DIR"
    
    # Try full requirements first, fallback to minimal
    if [[ -f "requirements.txt" ]]; then
        print_info "Attempting to install full requirements..."
        if pip3 install -r requirements.txt --quiet --break-system-packages 2>/dev/null; then
            print_success "Full Python dependencies installed"
        elif [[ -f "requirements.minimal.txt" ]]; then
            print_warning "Full requirements failed, trying minimal requirements..."
            pip3 install -r requirements.minimal.txt --quiet --break-system-packages
            print_success "Minimal Python dependencies installed"
        else
            print_error "Failed to install Python dependencies"
            return 1
        fi
    elif [[ -f "requirements.minimal.txt" ]]; then
        print_info "Installing minimal requirements..."
        pip3 install -r requirements.minimal.txt --quiet --break-system-packages
        print_success "Minimal Python dependencies installed"
    else
        print_warning "No requirements files found, skipping Python dependencies"
    fi
}

setup_django() {
    print_info "Setting up Django application..."
    cd "$WORKSPACE_DIR"
    
    # Check if manage.py exists
    if [[ ! -f "manage.py" ]]; then
        print_error "Django manage.py not found in $WORKSPACE_DIR"
        return 1
    fi
    
    # Collect static files
    print_info "Collecting static files..."
    python3 manage.py collectstatic --noinput --clear || true
    
    # Run migrations
    print_info "Running database migrations..."
    python3 manage.py migrate --noinput || true
    
    print_success "Django setup completed"
}

detect_init_system() {
    if [[ -d /run/systemd/system ]] && command -v systemctl &> /dev/null; then
        echo "systemd"
    elif command -v service &> /dev/null; then
        echo "sysvinit"
    else
        echo "none"
    fi
}

deploy_with_systemd() {
    print_info "Deploying with systemd..."
    
    # Use the existing reliable deployment script
    if [[ -f "deploy_reliable_service.sh" ]]; then
        ./deploy_reliable_service.sh deploy
    else
        print_error "deploy_reliable_service.sh not found"
        return 1
    fi
}

deploy_simple() {
    print_info "Deploying with simple process management..."
    
    # Use the simple deployment script
    if [[ -f "deploy_simple.sh" ]]; then
        ./deploy_simple.sh deploy
    else
        print_error "deploy_simple.sh not found"
        return 1
    fi
}

setup_ngrok_auth() {
    print_info "Checking ngrok configuration..."
    
    if [[ -f "ngrok" ]]; then
        # Check if ngrok is authenticated
        if ./ngrok config check 2>/dev/null; then
            print_success "Ngrok is properly configured"
            return 0
        else
            print_warning "Ngrok requires authentication"
            echo ""
            echo -e "${YELLOW}To enable public access via ngrok:${NC}"
            echo "1. Sign up at: https://dashboard.ngrok.com/signup"
            echo "2. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken"
            echo "3. Run: ./ngrok config add-authtoken YOUR_TOKEN_HERE"
            echo "4. Restart the deployment"
            echo ""
            return 1
        fi
    else
        print_warning "Ngrok binary not found, public tunnel will not be available"
        return 1
    fi
}

show_final_status() {
    echo ""
    echo -e "${CYAN}🎉 NoctisPro PACS Installation Complete!${NC}"
    echo "=================================================="
    
    # Check Django
    if curl -s http://localhost:$DJANGO_PORT >/dev/null 2>&1; then
        print_success "Django: Running on http://localhost:$DJANGO_PORT"
    else
        print_warning "Django: May not be responding (check logs)"
    fi
    
    # Check ngrok
    if pgrep -f "ngrok" >/dev/null 2>&1; then
        print_success "Ngrok: Running"
        print_info "Public URL: https://$NGROK_STATIC_URL"
    else
        print_warning "Ngrok: Not running (authentication may be required)"
    fi
    
    echo ""
    echo -e "${YELLOW}Management Commands:${NC}"
    
    local init_system=$(detect_init_system)
    if [[ "$init_system" == "systemd" ]]; then
        echo "• Check status: ./deploy_reliable_service.sh status"
        echo "• View logs: ./deploy_reliable_service.sh logs"
        echo "• Restart: ./deploy_reliable_service.sh restart"
    else
        echo "• Check status: ./deploy_simple.sh status"
        echo "• View logs: tail -f django.log gunicorn_*.log"
        echo "• Restart: ./deploy_simple.sh restart"
        echo "• Stop: ./deploy_simple.sh stop"
    fi
    
    echo ""
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "• Local: http://localhost:$DJANGO_PORT"
    if pgrep -f "ngrok" >/dev/null 2>&1; then
        echo "• Public: https://$NGROK_STATIC_URL"
    else
        echo "• Public: Configure ngrok authentication for public access"
    fi
    echo ""
}

main() {
    print_header
    
    print_info "Step 1: Installing system dependencies..."
    check_root
    install_system_dependencies
    
    print_info "Step 2: Installing Python dependencies..."
    install_python_dependencies
    
    print_info "Step 3: Setting up Django application..."
    setup_django
    
    print_info "Step 4: Deploying services..."
    local init_system=$(detect_init_system)
    print_info "Detected init system: $init_system"
    
    case "$init_system" in
        "systemd")
            if deploy_with_systemd; then
                print_success "Systemd deployment completed"
            else
                print_warning "Systemd deployment failed, falling back to simple deployment"
                deploy_simple
            fi
            ;;
        *)
            deploy_simple
            ;;
    esac
    
    print_info "Step 5: Configuring public access..."
    setup_ngrok_auth || true  # Don't fail if ngrok setup fails
    
    show_final_status
}

# Handle different command line arguments
case "${1:-install}" in
    "install"|"deploy")
        main
        ;;
    "status")
        local init_system=$(detect_init_system)
        if [[ "$init_system" == "systemd" ]] && [[ -f "deploy_reliable_service.sh" ]]; then
            ./deploy_reliable_service.sh status
        elif [[ -f "deploy_simple.sh" ]]; then
            ./deploy_simple.sh status
        else
            show_final_status
        fi
        ;;
    *)
        echo "Usage: $0 {install|deploy|status}"
        echo ""
        echo "Commands:"
        echo "  install/deploy  - Complete installation and deployment"
        echo "  status          - Show current system status"
        exit 1
        ;;
esac