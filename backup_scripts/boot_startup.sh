#!/bin/bash

# 🚀 NoctisPro PACS - Boot Startup Script
# Ensures reliable startup even if initial boot fails
# Place this in /etc/rc.local or create a @reboot cron job

set -euo pipefail

WORKSPACE_DIR="/workspace"
SERVICE_NAME="noctispro-pacs"
LOG_FILE="/var/log/noctispro-boot.log"
MAX_RETRIES=5
RETRY_DELAY=30

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

wait_for_network() {
    log_message "Waiting for network connectivity..."
    local count=0
    while ! ping -c 1 8.8.8.8 &> /dev/null; do
        count=$((count + 1))
        if [[ $count -gt 30 ]]; then
            log_message "Network timeout after 5 minutes"
            return 1
        fi
        sleep 10
    done
    log_message "Network connectivity established"
    return 0
}

start_service_with_retry() {
    local service_name="$1"
    local retry_count=0
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        log_message "Attempting to start $service_name (attempt $((retry_count + 1))/$MAX_RETRIES)"
        
        if systemctl start "$service_name"; then
            log_message "$service_name started successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_message "$service_name failed to start, retrying in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
    done
    
    log_message "Failed to start $service_name after $MAX_RETRIES attempts"
    return 1
}

main() {
    log_message "NoctisPro PACS boot startup initiated"
    
    # Wait for system to be fully ready
    sleep 30
    
    # Wait for network
    if ! wait_for_network; then
        log_message "Proceeding without network verification"
    fi
    
    # Check if workspace directory exists
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        log_message "ERROR: Workspace directory $WORKSPACE_DIR not found"
        exit 1
    fi
    
    # Change to workspace directory
    cd "$WORKSPACE_DIR"
    
    # Start main service with retries
    if start_service_with_retry "$SERVICE_NAME"; then
        log_message "Main service started successfully"
        
        # Wait a bit before starting ngrok
        sleep 15
        
        # Start ngrok service
        if start_service_with_retry "noctispro-ngrok"; then
            log_message "Ngrok service started successfully"
        else
            log_message "WARNING: Ngrok service failed to start"
        fi
    else
        log_message "CRITICAL: Failed to start main service"
        exit 1
    fi
    
    log_message "NoctisPro PACS boot startup completed successfully"
}

# Only run if called directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi