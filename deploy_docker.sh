#!/bin/bash

# =============================================================================
# NoctisPro PACS - Simple Docker Deployment
# One-command Docker deployment with auto-configuration
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"; }
error() { echo -e "${RED}[ERROR] ❌ $1${NC}" >&2; }
warn() { echo -e "${YELLOW}[WARNING] ⚠️  $1${NC}"; }
info() { echo -e "${BLUE}[INFO] ℹ️  $1${NC}"; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect domain
detect_domain() {
    local domain=""
    
    # Try to get public IP
    for service in "ifconfig.me" "ipecho.net/plain" "icanhazip.com"; do
        if domain=$(timeout 5 curl -s "$service" 2>/dev/null); then
            if [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                domain="noctispro-$domain.nip.io"
                break
            fi
        fi
    done
    
    # Fallback to localhost
    if [ -z "$domain" ]; then
        domain="localhost"
    fi
    
    echo "$domain"
}

main() {
    echo
    log "🚀 NoctisPro PACS - Docker Deployment"
    echo "===================================="
    echo
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Please install Docker and try again."
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose is not installed. Please install Docker Compose and try again."
        exit 1
    fi
    
    # Auto-detect domain
    DOMAIN=$(detect_domain)
    info "Using domain: $DOMAIN"
    
    # Fix potential 500 errors
    log "Fixing potential 500 errors..."
    python3 fix_500_errors.py
    
    # Generate secret key
    SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    export SECRET_KEY
    
    # Stop existing containers
    info "Stopping existing containers..."
    docker-compose -f docker-compose.optimized.yml down --remove-orphans 2>/dev/null || true
    
    # Build and start services
    log "Building Docker images..."
    docker-compose -f docker-compose.optimized.yml build --no-cache
    
    log "Starting services..."
    docker-compose -f docker-compose.optimized.yml up -d
    
    # Wait for services
    info "Waiting for services to start..."
    sleep 30
    
    # Health check
    log "Performing health check..."
    
    # Check web service
    if timeout 30 bash -c 'until curl -f -s http://localhost:8000/admin/login/ >/dev/null; do sleep 2; done'; then
        log "✅ Web service is healthy"
    else
        warn "⚠️  Web service may still be starting"
    fi
    
    # Check DICOM service
    if timeout 10 bash -c '</dev/tcp/localhost/11112' 2>/dev/null; then
        log "✅ DICOM service is healthy"
    else
        warn "⚠️  DICOM service may still be starting"
    fi
    
    echo
    log "🎉 NoctisPro PACS Docker deployment completed!"
    echo
    info "📊 Access Information:"
    echo "   Web Interface:   http://localhost:8000"
    echo "   Admin Panel:     http://localhost:8000/admin/"
    echo "   Default Login:   admin / admin123"
    echo "   DICOM AE Title:  NOCTIS_SCP"
    echo "   DICOM Port:      localhost:11112"
    echo
    info "🔧 Management Commands:"
    echo "   View Status:     docker-compose -f docker-compose.optimized.yml ps"
    echo "   View Logs:       docker-compose -f docker-compose.optimized.yml logs -f"
    echo "   Stop Services:   docker-compose -f docker-compose.optimized.yml down"
    echo "   Restart:         docker-compose -f docker-compose.optimized.yml restart"
    echo
    if [ "$DOMAIN" != "localhost" ]; then
        info "🌐 External Access:"
        echo "   Your PACS will be available at: http://$DOMAIN"
        echo "   Make sure ports 80, 8000, and 11112 are accessible"
    fi
    echo
    log "✅ Deployment successful! Your PACS system is ready to use."
}

main "$@"