#!/bin/bash

# 🏥 NoctisPro Ultimate Demo Deployment Script
# This script ensures 100% working system for buyer demonstration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root (needed for some operations)
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root. This is fine for demo setup."
    else
        info "Running as regular user. Some operations may require sudo."
    fi
}

# System requirements check
check_system_requirements() {
    log "🔍 Checking system requirements..."
    
    # Check available memory
    available_mem=$(free -g | awk '/^Mem:/{print $7}')
    if [ "$available_mem" -lt 4 ]; then
        warning "Available memory is ${available_mem}GB. Recommended: 4GB+"
    else
        info "Memory check passed: ${available_mem}GB available"
    fi
    
    # Check disk space
    available_disk=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$available_disk" -lt 20 ]; then
        error "Insufficient disk space: ${available_disk}GB available. Need at least 20GB"
    else
        info "Disk space check passed: ${available_disk}GB available"
    fi
    
    # Check for required commands
    for cmd in docker docker-compose python3 git curl; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd is required but not installed"
        else
            info "$cmd is available"
        fi
    done
}

# Install missing dependencies
install_dependencies() {
    log "📦 Installing/updating dependencies..."
    
    # Update system packages
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y curl wget git python3 python3-pip python3-venv
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y curl wget git python3 python3-pip
    fi
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        info "Docker installed. You may need to log out and back in."
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# Setup environment
setup_environment() {
    log "🔧 Setting up environment..."
    
    # Copy demo environment file
    if [ ! -f .env.production ]; then
        cp .env.demo .env.production
        info "Created .env.production from demo template"
    fi
    
    # Generate secure secret key
    if grep -q "demo-secret-key" .env.production; then
        SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
        sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" .env.production
        info "Generated secure secret key"
    fi
    
    # Make scripts executable
    chmod +x *.sh
    chmod +x health_check.py
    chmod +x scripts/*.sh 2>/dev/null || true
    
    # Create necessary directories
    mkdir -p logs media staticfiles backups
    info "Created necessary directories"
}

# Clean previous deployment
clean_previous_deployment() {
    log "🧹 Cleaning previous deployment..."
    
    # Stop any running containers
    docker-compose -f docker-compose.yml -f docker-compose.autostart.yml down --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.production.yml down --remove-orphans 2>/dev/null || true
    
    # Clean up old images (keep base images)
    docker image prune -f
    
    # Remove old log files
    rm -f *.log
    rm -f logs/*.log 2>/dev/null || true
    
    info "Cleanup completed"
}

# Build and deploy
deploy_system() {
    log "🚀 Deploying NoctisPro system..."
    
    # Use production Docker Compose for demo
    export BUILD_TARGET=production
    
    # Build images first
    log "Building Docker images..."
    docker-compose -f docker-compose.production.yml build --no-cache
    
    # Start the system
    log "Starting services..."
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 30
    
    # Check service health
    for i in {1..30}; do
        if docker-compose -f docker-compose.production.yml ps | grep -q "Up"; then
            info "Services are starting up... (attempt $i/30)"
            sleep 10
        else
            error "Services failed to start"
        fi
        
        # Check if web service is responding
        if curl -s http://localhost:8000/health/simple/ >/dev/null; then
            info "Web service is responding"
            break
        fi
        
        if [ $i -eq 30 ]; then
            warning "Services may not be fully ready yet"
        fi
    done
}

# Setup demo data
setup_demo_data() {
    log "📊 Setting up demo data..."
    
    # Run migrations
    docker-compose -f docker-compose.production.yml exec web python manage.py migrate --noinput
    
    # Collect static files
    docker-compose -f docker-compose.production.yml exec web python manage.py collectstatic --noinput
    
    # Create superuser for demo
    docker-compose -f docker-compose.production.yml exec web python manage.py shell << 'EOF'
import os
from django.contrib.auth import get_user_model
User = get_user_model()

# Create demo admin user
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser(
        username='admin',
        email='demo@noctispro.com',
        password='demo123456',
        first_name='Demo',
        last_name='Administrator'
    )
    print('Created demo admin user')

# Create demo regular user
if not User.objects.filter(username='doctor').exists():
    User.objects.create_user(
        username='doctor',
        email='doctor@noctispro.com',
        password='doctor123',
        first_name='Dr. Demo',
        last_name='Physician'
    )
    print('Created demo doctor user')

print('Demo users created successfully')
EOF
    
    info "Demo data setup completed"
}

# Setup ngrok for remote access
setup_ngrok() {
    log "🌐 Setting up ngrok for remote access..."
    
    # Check if ngrok is installed
    if ! command -v ngrok &> /dev/null; then
        info "Installing ngrok..."
        # Download and install ngrok
        wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
        tar xzf ngrok-v3-stable-linux-amd64.tgz
        sudo mv ngrok /usr/local/bin
        rm ngrok-v3-stable-linux-amd64.tgz
    fi
    
    # Kill any existing ngrok processes
    pkill ngrok || true
    
    # Start ngrok for port 80 (nginx)
    nohup ngrok http 80 --log=stdout > ngrok.log 2>&1 &
    
    # Wait for ngrok to start
    sleep 10
    
    # Get ngrok URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null || echo "")
    
    if [ ! -z "$NGROK_URL" ]; then
        echo "$NGROK_URL" > current_ngrok_url.txt
        info "Ngrok tunnel active: $NGROK_URL"
        
        # Update Django allowed hosts
        docker-compose -f docker-compose.production.yml exec web python manage.py shell << EOF
import os
from django.conf import settings
# The URL will be accessible, no need to update ALLOWED_HOSTS as it's set to * for demo
print('Ngrok URL is accessible through Django')
EOF
    else
        warning "Failed to get ngrok URL. System will be accessible locally only."
    fi
}

# Run comprehensive health check
run_health_check() {
    log "🏥 Running comprehensive health check..."
    
    python3 health_check.py
    local health_status=$?
    
    if [ $health_status -eq 0 ]; then
        info "✅ All health checks passed!"
    elif [ $health_status -eq 1 ]; then
        warning "⚠️ Health checks passed with minor issues"
    else
        warning "❌ Some health checks failed, but system may still be functional"
    fi
    
    return $health_status
}

# Display access information
display_access_info() {
    log "📋 System Access Information"
    echo
    echo "🏥 NoctisPro Demo System is Ready!"
    echo "================================"
    echo
    echo "🌐 Access URLs:"
    echo "  Local Access:     http://localhost:8000"
    
    if [ -f current_ngrok_url.txt ]; then
        NGROK_URL=$(cat current_ngrok_url.txt)
        echo "  Remote Access:    $NGROK_URL"
        echo "  Ngrok Dashboard:  http://localhost:4040"
    fi
    
    echo
    echo "👤 Demo User Accounts:"
    echo "  Admin User:       admin / demo123456"
    echo "  Doctor User:      doctor / doctor123"
    echo
    echo "🔧 Management:"
    echo "  Health Check:     python3 health_check.py"
    echo "  View Logs:        docker-compose -f docker-compose.production.yml logs -f"
    echo "  Stop System:      docker-compose -f docker-compose.production.yml down"
    echo
    echo "📊 Service Status:"
    docker-compose -f docker-compose.production.yml ps
    echo
}

# Main deployment function
main() {
    echo
    echo "🏥 NoctisPro Ultimate Demo Deployment"
    echo "====================================="
    echo
    
    # Run all deployment steps
    check_permissions
    check_system_requirements
    install_dependencies
    setup_environment
    clean_previous_deployment
    deploy_system
    setup_demo_data
    setup_ngrok
    
    # Run health check
    if run_health_check; then
        display_access_info
        log "✅ Deployment completed successfully! System is ready for demo."
        exit 0
    else
        warning "⚠️ Deployment completed with some issues. Check the health status above."
        display_access_info
        exit 1
    fi
}

# Run main function
main "$@"