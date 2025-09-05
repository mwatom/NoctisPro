#!/bin/bash
# Health monitoring for NoctisPro PACS

SERVICE_NAME="noctispro-pacs"
DJANGO_URL="http://localhost:8000"
LOG_FILE="/var/log/noctispro-health.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_service() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        return 0
    else
        return 1
    fi
}

check_http() {
    if curl -s --connect-timeout 10 "$DJANGO_URL" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

main() {
    if ! check_service; then
        log_message "ERROR: Service $SERVICE_NAME is not running, attempting restart"
        systemctl restart "$SERVICE_NAME"
        sleep 10
    fi
    
    if ! check_http; then
        log_message "WARNING: HTTP check failed for $DJANGO_URL"
        systemctl restart "$SERVICE_NAME"
    else
        log_message "INFO: Health check passed"
    fi
}

main "$@"
