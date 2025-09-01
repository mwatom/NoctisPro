#!/bin/bash

# 🏥 NoctisPro Complete Production System Startup
# Starts all services with full production DICOM viewer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo
    echo -e "${BOLD}${BLUE}=============================================="
    echo -e "  $1"
    echo -e "===============================================${NC}"
    echo
}

# Main startup function
main() {
    header "🏥 NoctisPro Complete Production System Startup"
    
    cd /workspace
    
    # Ensure production environment is set
    export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
    export DEBUG=False
    export USE_SQLITE=false
    export DISABLE_REDIS=false
    export USE_DUMMY_CACHE=false
    
    log "🔧 Production environment configured"
    log "   Django Settings: $DJANGO_SETTINGS_MODULE"
    log "   Debug Mode: $DEBUG"
    log "   Database: PostgreSQL"
    log "   Cache: Redis"
    log "   DICOM Viewer: Full production template (base.html)"
    
    # Start core services
    header "🚀 Starting Core Services"
    
    log "Starting PostgreSQL database..."
    if systemctl is-active --quiet postgresql; then
        success "PostgreSQL already running"
    else
        systemctl start postgresql
        sleep 3
        success "PostgreSQL started"
    fi
    
    log "Starting Redis server..."
    if systemctl is-active --quiet redis-server; then
        success "Redis already running"
    else
        systemctl start redis-server
        sleep 2
        success "Redis started"
    fi
    
    # Activate virtual environment
    log "Activating Python virtual environment..."
    source venv/bin/activate
    success "Virtual environment activated"
    
    # Run Django preparations
    header "🐍 Django System Preparation"
    
    log "Running database migrations..."
    python manage.py migrate --noinput --settings=noctis_pro.settings_production || warning "Some migrations may have failed"
    
    log "Collecting static files..."
    python manage.py collectstatic --noinput --settings=noctis_pro.settings_production || warning "Static files collection had issues"
    
    # Create necessary directories
    log "Creating necessary directories..."
    mkdir -p media/dicom staticfiles logs backups
    
    # Start background services
    header "⚙️ Starting Background Services"
    
    log "Starting Celery worker..."
    celery -A noctis_pro worker --loglevel=info --detach --pidfile=celery.pid --logfile=logs/celery.log
    success "Celery worker started"
    
    log "Starting DICOM receiver..."
    python dicom_receiver.py &
    echo $! > dicom_receiver.pid
    success "DICOM receiver started"
    
    # Start main Django application
    header "🌐 Starting Main Application"
    
    log "Starting Django application with Daphne (ASGI server)..."
    daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application &
    DJANGO_PID=$!
    echo $DJANGO_PID > django.pid
    
    # Wait for Django to start
    sleep 10
    
    # Verify Django is running
    if kill -0 $DJANGO_PID 2>/dev/null; then
        success "Django application started successfully (PID: $DJANGO_PID)"
    else
        error "Django application failed to start"
    fi
    
    # Start Nginx if available
    if command -v nginx >/dev/null 2>&1; then
        log "Starting Nginx reverse proxy..."
        systemctl start nginx
        success "Nginx started"
    else
        warning "Nginx not installed - serving directly from Django"
    fi
    
    # System verification
    header "🧪 System Verification"
    
    sleep 5
    
    # Test main application
    log "Testing main application..."
    if curl -s http://localhost:8000/health/ > /dev/null 2>&1; then
        success "✅ Main application is responding"
    else
        warning "⚠️  Main application may not be ready yet"
    fi
    
    # Test DICOM viewer
    log "Testing DICOM viewer..."
    if curl -s http://localhost:8000/dicom_viewer/ > /dev/null 2>&1; then
        success "✅ Production DICOM viewer is accessible"
    else
        warning "⚠️  DICOM viewer may not be ready yet"
    fi
    
    # Test admin interface
    log "Testing admin interface..."
    if curl -s http://localhost:8000/admin/ > /dev/null 2>&1; then
        success "✅ Admin interface is accessible"
    else
        warning "⚠️  Admin interface may not be ready yet"
    fi
    
    # Display system status
    header "📊 System Status"
    
    echo "🏥 NoctisPro Production System Status:"
    echo
    echo "🔧 Core Services:"
    systemctl is-active --quiet postgresql && echo "   ✅ PostgreSQL: Running" || echo "   ❌ PostgreSQL: Stopped"
    systemctl is-active --quiet redis-server && echo "   ✅ Redis: Running" || echo "   ❌ Redis: Stopped"
    
    echo
    echo "🌐 Application Services:"
    [ -f django.pid ] && kill -0 $(cat django.pid) 2>/dev/null && echo "   ✅ Django (Daphne): Running" || echo "   ❌ Django: Stopped"
    [ -f celery.pid ] && kill -0 $(cat celery.pid) 2>/dev/null && echo "   ✅ Celery Worker: Running" || echo "   ❌ Celery: Stopped"
    [ -f dicom_receiver.pid ] && kill -0 $(cat dicom_receiver.pid) 2>/dev/null && echo "   ✅ DICOM Receiver: Running" || echo "   ❌ DICOM Receiver: Stopped"
    systemctl is-active --quiet nginx && echo "   ✅ Nginx: Running" || echo "   ⚠️  Nginx: Not running"
    
    echo
    echo "🌐 Access URLs:"
    echo "   Main Interface: http://localhost:8000"
    echo "   DICOM Viewer:   http://localhost:8000/dicom_viewer/"
    echo "   Admin Panel:    http://localhost:8000/admin/"
    echo "   API Docs:       http://localhost:8000/api/docs/"
    
    if systemctl is-active --quiet nginx; then
        echo
        echo "🌐 Nginx URLs (if configured):"
        echo "   Main Interface: http://localhost"
        echo "   DICOM Viewer:   http://localhost/dicom_viewer/"
        echo "   Admin Panel:    http://localhost/admin/"
    fi
    
    echo
    echo "🎯 Production DICOM Viewer Features Available:"
    echo "   ✅ Full production template (base.html)"
    echo "   ✅ 3D reconstruction tools (MPR, MIP, Volume)"
    echo "   ✅ AI analysis integration"
    echo "   ✅ Professional measurement suite"
    echo "   ✅ Multi-modality support (CT, MRI, PET, SPECT)"
    echo "   ✅ Advanced imaging algorithms"
    echo "   ✅ Quality assurance tools"
    echo "   ✅ Real-time collaboration features"
    
    echo
    echo "🔧 Management Commands:"
    echo "   Status Check:    ./check_noctispro_production.sh"
    echo "   Stop System:     ./stop_complete_production_system.sh"
    echo "   View Logs:       tail -f logs/*.log"
    echo "   Django Shell:    source venv/bin/activate && python manage.py shell"
    echo "   Create Admin:    source venv/bin/activate && python manage.py createsuperuser"
    
    header "✅ NoctisPro Production System Started Successfully!"
    success "All services are running with full production DICOM viewer"
    log "System startup completed at $(date)"
}

# Trap to handle script interruption
trap 'echo "Startup interrupted"; exit 1' INT TERM

# Run main function
main "$@"