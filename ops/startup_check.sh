#!/usr/bin/env bash
set -euo pipefail

# Startup verification script for Noctis Pro
# This script checks if all required services are running properly

log() { echo "[$(date '+%F %T')] $*"; }
error() { echo "[$(date '+%F %T')] ERROR: $*" >&2; }
success() { echo "[$(date '+%F %T')] SUCCESS: $*"; }

# Load configuration
ENV_FILE=${ENV_FILE:-/etc/noctis/noctis.env}
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

APP_DIR=${APP_DIR:-/opt/noctis}
HOST=${HOST:-127.0.0.1}
PORT=${PORT:-8000}
WEBHOOK_PORT=${WEBHOOK_PORT:-9000}
DICOM_PORT=${DICOM_PORT:-11112}

# Services to check
SERVICES=(
    "redis-server"
    "noctis-web"
    "noctis-celery"
    "noctis-dicom"
    "noctis-webhook"
    "nginx"
)

# Function to check if a service is active
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        success "$service is active"
        return 0
    else
        error "$service is not active"
        return 1
    fi
}

# Function to check web service health
check_web_health() {
    local timeout=${1:-30}
    local max_attempts=$((timeout / 2))
    
    log "Checking web service health at http://${HOST}:${PORT}/"
    for i in $(seq 1 $max_attempts); do
        if curl -f -s --max-time 5 "http://${HOST}:${PORT}/" >/dev/null 2>&1; then
            success "Web service is responding"
            return 0
        fi
        sleep 2
    done
    error "Web service is not responding"
    return 1
}

# Function to check webhook service health
check_webhook_health() {
    log "Checking webhook service health at http://${HOST}:${WEBHOOK_PORT}/health"
    if curl -f -s --max-time 5 "http://${HOST}:${WEBHOOK_PORT}/health" >/dev/null 2>&1; then
        success "Webhook service is responding"
        return 0
    else
        error "Webhook service is not responding"
        return 1
    fi
}

# Function to check DICOM port
check_dicom_port() {
    log "Checking if DICOM port ${DICOM_PORT} is listening"
    if netstat -ln 2>/dev/null | grep -q ":${DICOM_PORT} .*LISTEN" || ss -ln 2>/dev/null | grep -q ":${DICOM_PORT} .*LISTEN"; then
        success "DICOM service is listening on port ${DICOM_PORT}"
        return 0
    else
        error "DICOM service is not listening on port ${DICOM_PORT}"
        return 1
    fi
}

# Function to restart a service
restart_service() {
    local service=$1
    log "Restarting $service"
    if systemctl restart "$service"; then
        success "$service restarted successfully"
        return 0
    else
        error "Failed to restart $service"
        return 1
    fi
}

# Main startup check
main() {
    log "Starting Noctis Pro system verification"
    
    local failed_services=()
    local failed_checks=()
    
    # Check all services
    for service in "${SERVICES[@]}"; do
        if ! check_service "$service"; then
            failed_services+=("$service")
        fi
    done
    
    # Wait a bit for services to fully initialize
    sleep 5
    
    # Check web service health
    if ! check_web_health 60; then
        failed_checks+=("web-health")
    fi
    
    # Check webhook health
    if ! check_webhook_health; then
        failed_checks+=("webhook-health")
    fi
    
    # Check DICOM port
    if ! check_dicom_port; then
        failed_checks+=("dicom-port")
    fi
    
    # Attempt to restart failed services
    if [ ${#failed_services[@]} -gt 0 ]; then
        log "Attempting to restart failed services: ${failed_services[*]}"
        for service in "${failed_services[@]}"; do
            restart_service "$service"
        done
        
        # Wait and re-check
        sleep 10
        failed_services=()
        for service in "${SERVICES[@]}"; do
            if ! check_service "$service"; then
                failed_services+=("$service")
            fi
        done
        
        # Re-check health after restart
        if [[ " ${failed_checks[*]} " =~ " web-health " ]]; then
            if check_web_health 30; then
                failed_checks=("${failed_checks[@]/web-health}")
            fi
        fi
        
        if [[ " ${failed_checks[*]} " =~ " webhook-health " ]]; then
            if check_webhook_health; then
                failed_checks=("${failed_checks[@]/webhook-health}")
            fi
        fi
        
        if [[ " ${failed_checks[*]} " =~ " dicom-port " ]]; then
            if check_dicom_port; then
                failed_checks=("${failed_checks[@]/dicom-port}")
            fi
        fi
    fi
    
    # Final status
    if [ ${#failed_services[@]} -eq 0 ] && [ ${#failed_checks[@]} -eq 0 ]; then
        success "All Noctis Pro services are running and healthy"
        
        # Display service status
        echo
        echo "=== Service Status ==="
        for service in "${SERVICES[@]}"; do
            echo "$service: $(systemctl is-active "$service")"
        done
        
        echo
        echo "=== Access URLs ==="
        echo "Web Interface: http://${HOST}:${PORT}/"
        echo "Admin Panel: http://${HOST}:${PORT}/admin-panel/"
        echo "Worklist: http://${HOST}:${PORT}/worklist/"
        echo "Webhook Health: http://${HOST}:${WEBHOOK_PORT}/health"
        echo "DICOM SCP: ${HOST}:${DICOM_PORT}"
        
        return 0
    else
        error "Some services or health checks failed"
        if [ ${#failed_services[@]} -gt 0 ]; then
            error "Failed services: ${failed_services[*]}"
        fi
        if [ ${#failed_checks[@]} -gt 0 ]; then
            error "Failed health checks: ${failed_checks[*]}"
        fi
        return 1
    fi
}

# Handle script arguments
case "${1:-check}" in
    "check")
        main
        ;;
    "restart-all")
        log "Restarting all Noctis Pro services"
        for service in "${SERVICES[@]}"; do
            if systemctl list-unit-files | grep -q "^${service}.service"; then
                restart_service "$service"
            fi
        done
        sleep 10
        main
        ;;
    "status")
        echo "=== Noctis Pro Service Status ==="
        for service in "${SERVICES[@]}"; do
            if systemctl list-unit-files | grep -q "^${service}.service"; then
                echo "$service: $(systemctl is-active "$service")"
            else
                echo "$service: not installed"
            fi
        done
        ;;
    *)
        echo "Usage: $0 {check|restart-all|status}"
        echo "  check      - Check if all services are running and healthy (default)"
        echo "  restart-all - Restart all services and then check"
        echo "  status     - Show status of all services"
        exit 1
        ;;
esac