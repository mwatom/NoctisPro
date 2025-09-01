#!/bin/bash

# 🏥 NoctisPro Complete Production System Shutdown
# Gracefully stops all services

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

header() {
    echo
    echo -e "${BOLD}${BLUE}=============================================="
    echo -e "  $1"
    echo -e "===============================================${NC}"
    echo
}

main() {
    header "🛑 NoctisPro Complete Production System Shutdown"
    
    cd /workspace
    
    # Stop Django application
    log "Stopping Django application..."
    if [ -f django.pid ]; then
        DJANGO_PID=$(cat django.pid)
        if kill -0 $DJANGO_PID 2>/dev/null; then
            kill -TERM $DJANGO_PID
            sleep 5
            if kill -0 $DJANGO_PID 2>/dev/null; then
                kill -KILL $DJANGO_PID
                warning "Django process force killed"
            else
                success "Django stopped gracefully"
            fi
        fi
        rm -f django.pid
    else
        warning "Django PID file not found"
    fi
    
    # Stop DICOM receiver
    log "Stopping DICOM receiver..."
    if [ -f dicom_receiver.pid ]; then
        DICOM_PID=$(cat dicom_receiver.pid)
        if kill -0 $DICOM_PID 2>/dev/null; then
            kill -TERM $DICOM_PID
            sleep 3
            if kill -0 $DICOM_PID 2>/dev/null; then
                kill -KILL $DICOM_PID
                warning "DICOM receiver force killed"
            else
                success "DICOM receiver stopped gracefully"
            fi
        fi
        rm -f dicom_receiver.pid
    else
        warning "DICOM receiver PID file not found"
    fi
    
    # Stop Celery worker
    log "Stopping Celery worker..."
    if [ -f celery.pid ]; then
        CELERY_PID=$(cat celery.pid)
        if kill -0 $CELERY_PID 2>/dev/null; then
            kill -TERM $CELERY_PID
            sleep 5
            if kill -0 $CELERY_PID 2>/dev/null; then
                kill -KILL $CELERY_PID
                warning "Celery worker force killed"
            else
                success "Celery worker stopped gracefully"
            fi
        fi
        rm -f celery.pid
    else
        warning "Celery PID file not found"
    fi
    
    # Stop any remaining processes
    log "Cleaning up remaining processes..."
    pkill -f "daphne.*noctis_pro" 2>/dev/null || true
    pkill -f "celery.*noctis_pro" 2>/dev/null || true
    pkill -f "dicom_receiver.py" 2>/dev/null || true
    
    success "All NoctisPro processes stopped"
    
    echo
    log "🔧 Core services (PostgreSQL, Redis, Nginx) are still running"
    log "   Use 'systemctl stop postgresql redis-server nginx' to stop them"
    
    header "✅ NoctisPro Production System Shutdown Complete"
    log "System shutdown completed at $(date)"
}

# Run main function
main "$@"