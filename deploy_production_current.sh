#!/bin/bash

# NoctisPro Production Deployment Script
# This script sets up NoctisPro to run as a production service

set -e

echo "🚀 Starting NoctisPro Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if running as root for service installation
if [[ $EUID -eq 0 ]]; then
    print_error "Don't run this script as root! Run as regular user with sudo access."
    exit 1
fi

# Set working directory
cd /workspace

print_status "Checking system requirements..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    print_error "Virtual environment not found! Please run the initial setup first."
    exit 1
fi

# Create logs directory
print_status "Creating logs directory..."
mkdir -p /workspace/logs

# Create static files directory
print_status "Creating static files directory..."
mkdir -p /workspace/staticfiles

# Activate virtual environment and collect static files
print_status "Collecting static files..."
source venv/bin/activate
export USE_POSTGRESQL=true
export DEBUG=false
python manage.py collectstatic --noinput || true

# Install/update systemd service files
print_status "Installing systemd service files..."

# Copy service files to systemd directory
sudo cp noctispro-production-current.service /etc/systemd/system/
sudo cp noctispro-ngrok-current.service /etc/systemd/system/

# Set proper permissions
sudo chmod 644 /etc/systemd/system/noctispro-production-current.service
sudo chmod 644 /etc/systemd/system/noctispro-ngrok-current.service

# Reload systemd daemon
print_status "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable services to start on boot
print_status "Enabling services for auto-start..."
sudo systemctl enable noctispro-production-current.service
sudo systemctl enable noctispro-ngrok-current.service

# Stop any existing services
print_status "Stopping any existing services..."
sudo systemctl stop noctispro-production-current.service 2>/dev/null || true
sudo systemctl stop noctispro-ngrok-current.service 2>/dev/null || true

# Stop any running development servers
print_status "Stopping development servers..."
pkill -f "python.*runserver" || true
pkill -f "ngrok" || true

# Start Redis if not running
print_status "Starting Redis server..."
redis-server --daemonize yes 2>/dev/null || true

# Start the production services
print_status "Starting NoctisPro production service..."
sudo systemctl start noctispro-production-current.service

# Wait a moment for Django to start
sleep 10

# Start ngrok tunnel
print_status "Starting ngrok tunnel service..."
sudo systemctl start noctispro-ngrok-current.service

# Wait for services to start
sleep 15

# Check service status
print_status "Checking service status..."

if sudo systemctl is-active --quiet noctispro-production-current.service; then
    print_success "✅ Django service is running"
else
    print_error "❌ Django service failed to start"
    sudo systemctl status noctispro-production-current.service --no-pager
fi

if sudo systemctl is-active --quiet noctispro-ngrok-current.service; then
    print_success "✅ Ngrok service is running"
else
    print_error "❌ Ngrok service failed to start"
    sudo systemctl status noctispro-ngrok-current.service --no-pager
fi

# Get ngrok URL
print_status "Getting ngrok tunnel URL..."
sleep 5

NGROK_URL=""
for i in {1..10}; do
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')" 2>/dev/null || echo "")
    if [ ! -z "$NGROK_URL" ]; then
        break
    fi
    print_status "Waiting for ngrok tunnel... (attempt $i/10)"
    sleep 5
done

echo ""
echo "========================================"
print_success "🎉 NoctisPro Production Deployment Complete!"
echo "========================================"
echo ""
print_success "📊 Service Status:"
echo "  • Django App: $(sudo systemctl is-active noctispro-production-current.service)"
echo "  • Ngrok Tunnel: $(sudo systemctl is-active noctispro-ngrok-current.service)"
echo ""

if [ ! -z "$NGROK_URL" ]; then
    print_success "🌐 Your application is accessible at:"
    echo "  • Public URL: $NGROK_URL"
    echo "  • Admin Panel: $NGROK_URL/admin/"
    echo "  • Local URL: http://localhost:8000"
else
    print_warning "⚠️  Ngrok URL not available yet. Check logs: sudo journalctl -u noctispro-ngrok-current.service -f"
fi

echo ""
print_success "🔧 Useful Commands:"
echo "  • Check Django logs: sudo journalctl -u noctispro-production-current.service -f"
echo "  • Check ngrok logs: sudo journalctl -u noctispro-ngrok-current.service -f"
echo "  • Restart Django: sudo systemctl restart noctispro-production-current.service"
echo "  • Restart ngrok: sudo systemctl restart noctispro-ngrok-current.service"
echo "  • Stop all services: sudo systemctl stop noctispro-*-current.service"
echo ""

print_success "✅ Services are now configured to start automatically on server boot!"
echo ""