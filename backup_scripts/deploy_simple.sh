#!/bin/bash

# 🚀 NoctisPro PACS - Simple Deployment (No Systemd Required)
# Direct service startup for environments without systemd

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
    echo -e "${CYAN}🚀  NoctisPro PACS - Simple Deployment${NC}"
    echo -e "${CYAN}   Direct Service Startup${NC}"
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

check_dependencies() {
    print_info "Checking dependencies..."
    cd "$WORKSPACE_DIR"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not found"
        exit 1
    fi
    
    # Check Django
    if [[ ! -f "manage.py" ]]; then
        print_error "Django manage.py not found in $WORKSPACE_DIR"
        exit 1
    fi
    
    # Check ngrok
    if [[ ! -f "ngrok" ]]; then
        print_warning "ngrok binary not found, tunnel will not be available"
    fi
    
    print_success "Dependencies check passed"
}

setup_django() {
    print_info "Setting up Django application..."
    cd "$WORKSPACE_DIR"
    
    # Collect static files
    print_info "Collecting static files..."
    python3 manage.py collectstatic --noinput --clear || true
    
    # Run migrations
    print_info "Running database migrations..."
    python3 manage.py migrate --noinput || true
    
    print_success "Django setup completed"
}

start_django() {
    print_info "Starting Django application..."
    cd "$WORKSPACE_DIR"
    
    # Kill any existing Django processes
    pkill -f "python3.*manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*noctis_pro.wsgi" 2>/dev/null || true
    
    # Start Django with gunicorn if available, otherwise use runserver
    if command -v gunicorn &> /dev/null; then
        print_info "Starting with Gunicorn..."
        nohup python3 -m gunicorn noctis_pro.wsgi:application \
            --bind 0.0.0.0:$DJANGO_PORT \
            --workers 3 \
            --timeout 120 \
            --access-logfile $WORKSPACE_DIR/gunicorn_access.log \
            --error-logfile $WORKSPACE_DIR/gunicorn_error.log \
            --daemon
        sleep 3
    else
        print_info "Starting with Django development server..."
        nohup python3 manage.py runserver 0.0.0.0:$DJANGO_PORT > django.log 2>&1 &
        sleep 3
    fi
    
    # Check if Django is running
    if curl -s http://localhost:$DJANGO_PORT >/dev/null 2>&1; then
        print_success "Django is running on port $DJANGO_PORT"
    else
        print_warning "Django may not be running properly, check logs"
    fi
}

start_ngrok() {
    if [[ -f "ngrok" ]]; then
        print_info "Starting ngrok tunnel..."
        
        # Kill existing ngrok processes
        pkill -f "ngrok" 2>/dev/null || true
        sleep 2
        
        # Start ngrok
        nohup ./ngrok http $DJANGO_PORT --domain=$NGROK_STATIC_URL --log=stdout > ngrok.log 2>&1 &
        sleep 5
        
        print_success "Ngrok tunnel started"
        print_info "Public URL: https://$NGROK_STATIC_URL"
    else
        print_warning "Ngrok not found, skipping tunnel setup"
    fi
}

show_status() {
    echo ""
    echo -e "${CYAN}🎉 NoctisPro PACS Status${NC}"
    echo "=================================="
    
    # Check Django
    if curl -s http://localhost:$DJANGO_PORT >/dev/null 2>&1; then
        print_success "Django: Running on http://localhost:$DJANGO_PORT"
    else
        print_error "Django: Not responding"
    fi
    
    # Check ngrok
    if pgrep -f "ngrok" >/dev/null 2>&1; then
        print_success "Ngrok: Running"
        print_info "Public URL: https://$NGROK_STATIC_URL"
    else
        print_warning "Ngrok: Not running"
    fi
    
    echo ""
    echo -e "${YELLOW}Management Commands:${NC}"
    echo "• Check status: $0 status"
    echo "• View Django logs: tail -f django.log (or gunicorn_*.log)"
    echo "• View ngrok logs: tail -f ngrok.log"
    echo "• Stop services: $0 stop"
    echo "• Restart services: $0 restart"
    echo ""
}

stop_services() {
    print_info "Stopping services..."
    
    # Stop Django
    pkill -f "python3.*manage.py runserver" 2>/dev/null || true
    pkill -f "gunicorn.*noctis_pro.wsgi" 2>/dev/null || true
    
    # Stop ngrok
    pkill -f "ngrok" 2>/dev/null || true
    
    print_success "Services stopped"
}

main() {
    case "${1:-deploy}" in
        "deploy")
            print_header
            check_dependencies
            setup_django
            start_django
            start_ngrok
            show_status
            ;;
        "start")
            start_django
            start_ngrok
            show_status
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_django
            start_ngrok
            show_status
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 {deploy|start|stop|restart|status}"
            exit 1
            ;;
    esac
}

main "$@"