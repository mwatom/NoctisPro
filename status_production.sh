#!/bin/bash

# NoctisPro Production Status Script

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

cd /workspace

echo "========================================"
echo "       NoctisPro Production Status"
echo "========================================"
echo ""

# Check Django service
DJANGO_RUNNING=false
if [ -f "django.pid" ]; then
    DJANGO_PID=$(cat django.pid)
    if kill -0 $DJANGO_PID 2>/dev/null; then
        print_success "✅ Django Service: RUNNING (PID: $DJANGO_PID)"
        DJANGO_RUNNING=true
    else
        print_error "❌ Django Service: STOPPED (stale PID file)"
        rm -f django.pid
    fi
else
    # Check by process name
    GUNICORN_PID=$(pgrep -f "gunicorn.*noctis_pro" | head -1)
    if [ ! -z "$GUNICORN_PID" ]; then
        print_success "✅ Django Service: RUNNING (PID: $GUNICORN_PID)"
        DJANGO_RUNNING=true
    else
        print_error "❌ Django Service: STOPPED"
    fi
fi

# Check Ngrok service
NGROK_RUNNING=false
if [ -f "ngrok.pid" ]; then
    NGROK_PID=$(cat ngrok.pid)
    if kill -0 $NGROK_PID 2>/dev/null; then
        print_success "✅ Ngrok Service: RUNNING (PID: $NGROK_PID)"
        NGROK_RUNNING=true
    else
        print_error "❌ Ngrok Service: STOPPED (stale PID file)"
        rm -f ngrok.pid
    fi
else
    # Check by process name
    NGROK_PID=$(pgrep -f "ngrok" | head -1)
    if [ ! -z "$NGROK_PID" ]; then
        print_success "✅ Ngrok Service: RUNNING (PID: $NGROK_PID)"
        NGROK_RUNNING=true
    else
        print_error "❌ Ngrok Service: STOPPED"
    fi
fi

# Check Redis
REDIS_RUNNING=false
if redis-cli ping >/dev/null 2>&1; then
    print_success "✅ Redis Service: RUNNING"
    REDIS_RUNNING=true
else
    print_error "❌ Redis Service: STOPPED"
fi

echo ""

# Test connectivity
if [ "$DJANGO_RUNNING" = true ]; then
    print_status "🌐 Testing connectivity..."
    if curl -s http://localhost:8000 >/dev/null 2>&1; then
        print_success "✅ Django is responding on port 8000"
    else
        print_warning "⚠️  Django not responding on port 8000"
    fi
fi

# Get ngrok URL if running
if [ "$NGROK_RUNNING" = true ]; then
    print_status "🔗 Getting ngrok URL..."
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null || echo "")
    
    if [ ! -z "$NGROK_URL" ]; then
        echo ""
        print_success "🌐 Application URLs:"
        echo "  • Public URL: $NGROK_URL"
        echo "  • Admin Panel: $NGROK_URL/admin/"
        echo "  • Local URL: http://localhost:8000"
        echo "  • Ngrok Inspector: http://localhost:4040"
    else
        print_warning "⚠️  Ngrok tunnel URL not available"
    fi
fi

# Show recent log files if they exist
echo ""
print_status "📂 Recent Log Activity:"
if [ -f "logs/gunicorn-error.log" ]; then
    DJANGO_ERRORS=$(tail -5 logs/gunicorn-error.log 2>/dev/null | wc -l)
    if [ $DJANGO_ERRORS -gt 0 ]; then
        print_warning "⚠️  Recent Django errors found in logs/gunicorn-error.log"
    else
        print_success "✅ No recent Django errors"
    fi
fi

if [ -f "logs/ngrok.log" ]; then
    print_success "✅ Ngrok logs available in logs/ngrok.log"
fi

echo ""
print_status "🔧 Management Commands:"
echo "  • Start: ./start_production.sh"
echo "  • Stop: ./stop_production.sh"
echo "  • Restart: ./stop_production.sh && ./start_production.sh"
echo "  • Logs: tail -f logs/*.log"
echo ""