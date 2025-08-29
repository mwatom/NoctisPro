#!/bin/bash

# NoctisPro Service Management Script
# Usage: ./manage_noctispro.sh [start|stop|restart|status|logs|url]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_status() {
    echo "========================================"
    echo "         NoctisPro Service Status"
    echo "========================================"
    echo ""
    
    DJANGO_STATUS=$(sudo systemctl is-active noctispro-production-current.service 2>/dev/null || echo "inactive")
    NGROK_STATUS=$(sudo systemctl is-active noctispro-ngrok-current.service 2>/dev/null || echo "inactive")
    
    if [ "$DJANGO_STATUS" = "active" ]; then
        print_success "✅ Django Service: RUNNING"
    else
        print_error "❌ Django Service: STOPPED"
    fi
    
    if [ "$NGROK_STATUS" = "active" ]; then
        print_success "✅ Ngrok Service: RUNNING"
    else
        print_error "❌ Ngrok Service: STOPPED"
    fi
    
    echo ""
}

get_ngrok_url() {
    print_status "Getting ngrok tunnel URL..."
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null || echo "")
    
    if [ ! -z "$NGROK_URL" ]; then
        echo ""
        print_success "🌐 Your application URLs:"
        echo "  • Public URL: $NGROK_URL"
        echo "  • Admin Panel: $NGROK_URL/admin/"
        echo "  • Local URL: http://localhost:8000"
        echo ""
    else
        print_warning "⚠️  Ngrok tunnel not available. Service may be starting up."
    fi
}

case "${1:-status}" in
    start)
        print_status "Starting NoctisPro services..."
        sudo systemctl start noctispro-production-current.service
        sudo systemctl start noctispro-ngrok-current.service
        sleep 10
        show_status
        get_ngrok_url
        ;;
    stop)
        print_status "Stopping NoctisPro services..."
        sudo systemctl stop noctispro-ngrok-current.service
        sudo systemctl stop noctispro-production-current.service
        print_success "✅ Services stopped"
        ;;
    restart)
        print_status "Restarting NoctisPro services..."
        sudo systemctl restart noctispro-production-current.service
        sudo systemctl restart noctispro-ngrok-current.service
        sleep 15
        show_status
        get_ngrok_url
        ;;
    status)
        show_status
        ;;
    logs)
        if [ "$2" = "ngrok" ]; then
            print_status "Showing ngrok logs (Ctrl+C to exit)..."
            sudo journalctl -u noctispro-ngrok-current.service -f
        else
            print_status "Showing Django logs (Ctrl+C to exit)..."
            sudo journalctl -u noctispro-production-current.service -f
        fi
        ;;
    url)
        get_ngrok_url
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [ngrok]|url}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all NoctisPro services"
        echo "  stop     - Stop all NoctisPro services"
        echo "  restart  - Restart all NoctisPro services"
        echo "  status   - Show current service status"
        echo "  logs     - Show Django application logs"
        echo "  logs ngrok - Show ngrok tunnel logs"
        echo "  url      - Display current ngrok URL"
        exit 1
        ;;
esac