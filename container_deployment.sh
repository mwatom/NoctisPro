#!/bin/bash

# 🏥 NoctisPro Container-Compatible Deployment Script
# For environments without Docker/systemd

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

# Setup virtual environment
setup_virtual_environment() {
    log "🐍 Setting up Python virtual environment..."
    
    cd /workspace
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        info "Virtual environment created"
    else
        info "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    info "Virtual environment ready"
}

# Install dependencies
install_dependencies() {
    log "📦 Installing Python dependencies..."
    
    cd /workspace
    source venv/bin/activate
    
    # Install basic dependencies first
    pip install Django pillow python-dotenv
    
    # Try to install all requirements, but continue if some fail
    if pip install -r requirements.txt; then
        info "All dependencies installed successfully"
    else
        warning "Some dependencies failed to install, installing essential ones manually..."
        
        # Install essential packages one by one
        essential_packages=(
            "django"
            "pillow"
            "python-dotenv"
            "django-widget-tweaks"
            "gunicorn"
            "whitenoise"
            "psycopg2-binary"
            "dj-database-url"
            "redis"
            "django-redis"
            "djangorestframework"
            "django-cors-headers"
            "requests"
            "django-health-check"
        )
        
        for package in "${essential_packages[@]}"; do
            pip install "$package" || warning "Failed to install $package, continuing..."
        done
    fi
    
    info "Dependencies installation completed"
}

# Setup SQLite database (fallback)
setup_sqlite_database() {
    log "🗃️ Setting up SQLite database..."
    
    cd /workspace
    source venv/bin/activate
    
    # Copy environment configuration
    cp .env.production .env.container
    
    # Update for SQLite
    cat > .env.container << EOF
# Container deployment configuration
DEBUG=False
SECRET_KEY=noctis-container-secret-$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=*,localhost,127.0.0.1

# SQLite Database
DB_ENGINE=django.db.backends.sqlite3
DB_NAME=db.sqlite3

# Security Settings (relaxed for container)
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False

# Admin Configuration
ADMIN_EMAIL=admin@noctispro.local
ADMIN_PASSWORD=admin123456

# Session Configuration
SESSION_TIMEOUT_MINUTES=60
SESSION_WARNING_MINUTES=10
EOF
    
    # Load environment
    export $(cat .env.container | grep -v '^#' | xargs)
    
    # Run Django commands
    python manage.py migrate --noinput || warning "Migration failed, continuing..."
    python manage.py collectstatic --noinput || warning "Static files collection failed, continuing..."
    
    # Create superuser if needed
    python manage.py shell << EOF || warning "Superuser creation failed"
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser(
        username='admin',
        email='admin@noctispro.local',
        password='admin123456'
    )
    print('Admin user created: admin/admin123456')
else:
    print('Admin user already exists')
EOF
    
    info "SQLite database configured"
}

# Start Django development server
start_django_server() {
    log "🚀 Starting Django development server..."
    
    cd /workspace
    source venv/bin/activate
    export $(cat .env.container | grep -v '^#' | xargs)
    
    # Start server in background
    nohup python manage.py runserver 0.0.0.0:8000 > django_server.log 2>&1 &
    DJANGO_PID=$!
    echo $DJANGO_PID > django_server.pid
    
    # Wait a moment for server to start
    sleep 5
    
    # Check if server is running
    if kill -0 $DJANGO_PID 2>/dev/null; then
        info "Django server started (PID: $DJANGO_PID)"
        info "Server running at: http://localhost:8000"
        info "Log file: django_server.log"
    else
        error "Failed to start Django server"
    fi
}

# Setup ngrok (if available)
setup_ngrok() {
    log "🌐 Setting up ngrok tunnel..."
    
    # Check if ngrok is available
    if command -v ngrok >/dev/null 2>&1; then
        # Start ngrok in background
        nohup ngrok http 8000 > ngrok.log 2>&1 &
        NGROK_PID=$!
        echo $NGROK_PID > ngrok.pid
        
        # Wait for ngrok to start
        sleep 10
        
        # Get ngrok URL
        if curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*"' | head -1; then
            info "Ngrok tunnel established"
            info "Check ngrok.log for tunnel URL"
        else
            warning "Ngrok tunnel may not be working properly"
        fi
    else
        warning "Ngrok not available, skipping tunnel setup"
    fi
}

# Health check
health_check() {
    log "🏥 Running health check..."
    
    sleep 5
    
    # Test local server
    if curl -s http://localhost:8000/ >/dev/null 2>&1; then
        info "✅ Local server responding"
    else
        warning "⚠️ Local server not responding"
    fi
    
    # Check log file
    if [ -f "django_server.log" ]; then
        info "Recent server logs:"
        tail -10 django_server.log | while read line; do
            echo "  $line"
        done
    fi
}

# Display status
display_status() {
    log "📊 Deployment Status"
    echo
    echo "🌐 Access URLs:"
    echo "  Local:     http://localhost:8000"
    echo "  Admin:     http://localhost:8000/admin"
    echo "  Health:    http://localhost:8000/health/"
    echo
    echo "🔑 Admin Credentials:"
    echo "  Username:  admin"
    echo "  Password:  admin123456"
    echo
    echo "📁 Important Files:"
    echo "  Logs:      /workspace/django_server.log"
    echo "  Database:  /workspace/db.sqlite3"
    echo "  Config:    /workspace/.env.container"
    echo
    echo "🔧 Management Commands:"
    echo "  Start:     cd /workspace && source venv/bin/activate && python manage.py runserver 0.0.0.0:8000"
    echo "  Stop:      kill \$(cat /workspace/django_server.pid 2>/dev/null) 2>/dev/null"
    echo "  Logs:      tail -f /workspace/django_server.log"
    echo
    
    if [ -f "django_server.pid" ]; then
        PID=$(cat django_server.pid)
        if kill -0 $PID 2>/dev/null; then
            echo "✅ Django server is running (PID: $PID)"
        else
            echo "❌ Django server is not running"
        fi
    else
        echo "❓ Django server status unknown"
    fi
    
    if [ -f "ngrok.pid" ]; then
        NGROK_PID=$(cat ngrok.pid)
        if kill -0 $NGROK_PID 2>/dev/null; then
            echo "✅ Ngrok tunnel is running (PID: $NGROK_PID)"
        else
            echo "❌ Ngrok tunnel is not running"
        fi
    fi
}

# Main deployment function
main() {
    echo
    echo "🏥 NoctisPro Container Deployment"
    echo "================================="
    echo
    
    setup_virtual_environment
    install_dependencies
    setup_sqlite_database
    start_django_server
    setup_ngrok
    health_check
    display_status
    
    log "✅ Container deployment completed!"
    echo
    echo "🎉 NoctisPro is now running!"
    echo "   Visit http://localhost:8000 to access the application"
    echo "   Admin panel: http://localhost:8000/admin (admin/admin123456)"
}

# Cleanup function for stopping services
cleanup() {
    log "🛑 Stopping services..."
    
    # Stop Django server
    if [ -f "django_server.pid" ]; then
        PID=$(cat django_server.pid)
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            info "Django server stopped"
        fi
        rm -f django_server.pid
    fi
    
    # Stop ngrok
    if [ -f "ngrok.pid" ]; then
        NGROK_PID=$(cat ngrok.pid)
        if kill -0 $NGROK_PID 2>/dev/null; then
            kill $NGROK_PID
            info "Ngrok tunnel stopped"
        fi
        rm -f ngrok.pid
    fi
}

# Handle script arguments
case "${1:-}" in
    "start"|"")
        main
        ;;
    "stop")
        cleanup
        ;;
    "status")
        display_status
        ;;
    "restart")
        cleanup
        sleep 2
        main
        ;;
    *)
        echo "Usage: $0 [start|stop|status|restart]"
        echo "  start    - Start the application (default)"
        echo "  stop     - Stop all services"
        echo "  status   - Show current status"
        echo "  restart  - Restart all services"
        exit 1
        ;;
esac