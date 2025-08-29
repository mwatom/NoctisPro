#!/bin/bash

# NoctisPro Improved Production Status Script

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

echo "========================================"
echo "    NoctisPro Production Status (Improved)"
echo "========================================"
echo ""

# Check Daphne
if [ -f "daphne.pid" ]; then
    DAPHNE_PID=$(cat daphne.pid)
    if kill -0 "$DAPHNE_PID" 2>/dev/null; then
        print_success "✅ Daphne Service: RUNNING (PID: $DAPHNE_PID)"
    else
        print_error "❌ Daphne Service: STOPPED (stale PID file)"
        rm -f daphne.pid
    fi
else
    if pgrep -f "daphne.*noctis_pro" > /dev/null; then
        DAPHNE_PID=$(pgrep -f "daphne.*noctis_pro")
        print_warning "⚠️  Daphne Service: RUNNING but no PID file (PID: $DAPHNE_PID)"
    else
        print_error "❌ Daphne Service: STOPPED"
    fi
fi

# Check Ngrok
if [ -f "ngrok.pid" ]; then
    NGROK_PID=$(cat ngrok.pid)
    if kill -0 "$NGROK_PID" 2>/dev/null; then
        print_success "✅ Ngrok Service: RUNNING (PID: $NGROK_PID)"
    else
        print_error "❌ Ngrok Service: STOPPED (stale PID file)"
        rm -f ngrok.pid
    fi
else
    if pgrep ngrok > /dev/null; then
        NGROK_PID=$(pgrep ngrok)
        print_warning "⚠️  Ngrok Service: RUNNING but no PID file (PID: $NGROK_PID)"
    else
        print_error "❌ Ngrok Service: STOPPED"
    fi
fi

# Check Redis
if pgrep redis-server > /dev/null; then
    print_success "✅ Redis Service: RUNNING"
else
    print_error "❌ Redis Service: STOPPED"
fi

echo ""
print_status "🌐 Testing connectivity..."

# Test local Django
DAPHNE_PORT=${DAPHNE_PORT:-8000}
if curl -s http://localhost:$DAPHNE_PORT >/dev/null 2>&1; then
    print_success "✅ Django is responding on port $DAPHNE_PORT"
else
    print_error "❌ Django is not responding on port $DAPHNE_PORT"
fi

# Check ngrok URL
if [ -f "current_ngrok_url.txt" ]; then
    NGROK_URL=$(cat current_ngrok_url.txt)
    print_success "🌐 Public URL: $NGROK_URL"
    echo "  • Admin: $NGROK_URL/admin/"
else
    # Try to get from API
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null || echo "")
    if [ ! -z "$NGROK_URL" ]; then
        print_success "🌐 Public URL: $NGROK_URL"
        echo "$NGROK_URL" > current_ngrok_url.txt
    else
        print_warning "⚠️  Ngrok URL not available"
    fi
fi

echo ""
print_status "📂 Recent Log Activity:"

# Check for errors in logs
LOGS_DIR="logs"
if [ -d "$LOGS_DIR" ]; then
    if [ -f "$LOGS_DIR/daphne.log" ]; then
        ERROR_COUNT=$(grep -i error "$LOGS_DIR/daphne.log" | tail -10 | wc -l)
        if [ $ERROR_COUNT -gt 0 ]; then
            print_warning "⚠️  Recent Django errors found in $LOGS_DIR/daphne.log"
        else
            print_success "✅ No recent errors in Django logs"
        fi
    fi
    
    if [ -f "$LOGS_DIR/ngrok.log" ]; then
        print_success "✅ Ngrok logs available in $LOGS_DIR/ngrok.log"
    fi
else
    print_warning "⚠️  Logs directory not found"
fi

# Environment info
if [ -f ".env.production" ]; then
    print_success "✅ Environment file: .env.production"
else
    print_warning "⚠️  No environment file found"
fi

echo ""
print_status "🔧 Management Commands:"
echo "  • Start: ./start_production_improved.sh"
echo "  • Stop: ./stop_production_improved.sh"
echo "  • Restart: ./stop_production_improved.sh && ./start_production_improved.sh"
echo "  • Logs: tail -f logs/*.log"
echo "  • URL: cat current_ngrok_url.txt"
echo ""