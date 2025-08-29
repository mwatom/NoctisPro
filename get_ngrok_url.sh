#!/bin/bash

# Quick script to get the current ngrok URL

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Get ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null || echo "")

if [ ! -z "$NGROK_URL" ]; then
    echo ""
    print_success "🌐 Your NoctisPro Application URLs:"
    echo "  • Public URL: $NGROK_URL"
    echo "  • Admin Panel: $NGROK_URL/admin/"
    echo "  • Local URL: http://localhost:8000"
    echo "  • Ngrok Inspector: http://localhost:4040"
    echo ""
    echo "🔗 Quick Copy: $NGROK_URL"
    echo ""
else
    print_warning "⚠️  Ngrok tunnel not available."
    print_status "Make sure ngrok is running: ./status_production.sh"
    echo ""
fi