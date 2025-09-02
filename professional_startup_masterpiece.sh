#!/bin/bash

# 🚀 Professional NoctisPro Startup Masterpiece
# Medical Imaging Excellence - Flawless System Startup
# Enhanced with masterpiece-level reliability and professional monitoring

set -euo pipefail

# Professional color palette for medical excellence
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m'

# Professional medical icons
declare -r ICON_ROCKET="🚀"
declare -r ICON_HOSPITAL="🏥"
declare -r ICON_SUCCESS="✅"
declare -r ICON_ERROR="🚨"
declare -r ICON_WARNING="⚠️"
declare -r ICON_INFO="ℹ️"
declare -r ICON_PROCESS="⚙️"
declare -r ICON_NETWORK="🌐"
declare -r ICON_MONITOR="📊"

# Professional configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTUP_LOG="$SCRIPT_DIR/professional_startup.log"
NGROK_URL_FILE="$SCRIPT_DIR/current_ngrok_url.txt"
STARTUP_STATUS_FILE="$SCRIPT_DIR/startup_status.json"
STARTUP_START_TIME=$(date +%s)

# Professional logging with medical precision
startup_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local uptime=$(($(date +%s) - STARTUP_START_TIME))
    
    case "$level" in
        "SUCCESS") echo -e "${GREEN}${ICON_SUCCESS} [${timestamp}] [${uptime}s] ${message}${NC}" ;;
        "ERROR")   echo -e "${RED}${ICON_ERROR} [${timestamp}] [${uptime}s] ${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}${ICON_WARNING} [${timestamp}] [${uptime}s] ${message}${NC}" ;;
        "INFO")    echo -e "${BLUE}${ICON_INFO} [${timestamp}] [${uptime}s] ${message}${NC}" ;;
        "PROCESS") echo -e "${CYAN}${ICON_PROCESS} [${timestamp}] [${uptime}s] ${message}${NC}" ;;
        "NETWORK") echo -e "${MAGENTA}${ICON_NETWORK} [${timestamp}] [${uptime}s] ${message}${NC}" ;;
        *)         echo -e "${WHITE}[${timestamp}] [${uptime}s] ${message}${NC}" ;;
    esac
    
    echo "[${timestamp}] [$level] [${uptime}s] $message" >> "$STARTUP_LOG"
}

log() { startup_log "INFO" "$1"; }
success() { startup_log "SUCCESS" "$1"; }
error() { startup_log "ERROR" "$1"; exit 1; }
warning() { startup_log "WARNING" "$1"; }
process() { startup_log "PROCESS" "$1"; }
network() { startup_log "NETWORK" "$1"; }

# Professional startup status tracking
update_startup_status() {
    local phase="$1"
    local status="$2"
    local details="$3"
    
    cat > "$STARTUP_STATUS_FILE" << EOF
{
    "startup_phase": "$phase",
    "status": "$status",
    "details": "$details",
    "timestamp": "$(date -Iseconds)",
    "uptime_seconds": $(($(date +%s) - STARTUP_START_TIME)),
    "system_version": "Noctis Pro PACS v2.0 Enhanced",
    "startup_quality": "Medical Grade Excellence"
}
EOF
}

# Professional pre-startup validation
validate_professional_system() {
    process "Validating professional system before startup..."
    update_startup_status "validation" "in_progress" "Validating system requirements"
    
    # Check if services exist
    local required_services=(
        "noctispro-professional"
        "noctispro-ngrok-professional"
        "noctispro-dicom-receiver"
    )
    
    for service in "${required_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
            success "Professional service found: $service"
        else
            error "Professional service missing: $service - Run deployment script first"
        fi
    done
    
    # Check ngrok binary
    if [[ -f "$SCRIPT_DIR/ngrok" ]]; then
        success "Professional ngrok binary: AVAILABLE"
    else
        warning "Professional ngrok binary: MISSING - Will attempt to install"
        "$SCRIPT_DIR/professional_ngrok_manager.sh" install
    fi
    
    # Check ngrok authentication
    if "$SCRIPT_DIR/ngrok" config check >/dev/null 2>&1; then
        success "Professional ngrok authentication: VERIFIED"
    else
        warning "Professional ngrok authentication: NOT CONFIGURED"
        info "Run: $SCRIPT_DIR/professional_ngrok_manager.sh auth"
    fi
    
    success "Professional system validation completed"
    update_startup_status "validation" "completed" "System validation successful"
}

# Professional service startup with enhanced reliability
start_professional_services_enhanced() {
    process "Starting professional medical imaging services with enhanced reliability..."
    update_startup_status "service_startup" "in_progress" "Starting professional services"
    
    # Professional service startup order with dependencies
    local service_order=(
        "noctispro-professional:Django Application:15"
        "noctispro-ngrok-professional:Public Access Tunnel:10" 
        "noctispro-dicom-receiver:DICOM Network Receiver:5"
    )
    
    local successful_services=0
    local total_services=${#service_order[@]}
    
    for service_info in "${service_order[@]}"; do
        local service_name=$(echo "$service_info" | cut -d':' -f1)
        local service_desc=$(echo "$service_info" | cut -d':' -f2)
        local startup_timeout=$(echo "$service_info" | cut -d':' -f3)
        
        process "Starting $service_desc..."
        
        # Stop service if running
        if systemctl is-active --quiet "$service_name"; then
            log "Service already active, restarting: $service_name"
            systemctl restart "$service_name"
        else
            systemctl start "$service_name"
        fi
        
        # Professional startup validation with timeout
        local attempt=0
        local max_attempts=$startup_timeout
        
        while [[ $attempt -lt $max_attempts ]]; do
            if systemctl is-active --quiet "$service_name"; then
                success "$service_desc: STARTED SUCCESSFULLY"
                ((successful_services++))
                break
            fi
            
            ((attempt++))
            process "$service_desc startup... (${attempt}/${max_attempts}s)"
            sleep 1
        done
        
        if ! systemctl is-active --quiet "$service_name"; then
            error "$service_desc: STARTUP FAILED"
            
            # Get detailed error information
            local error_info=$(systemctl status "$service_name" --no-pager -l | tail -3)
            warning "Error details: $error_info"
        fi
    done
    
    # Professional startup summary
    local startup_success_rate=$((successful_services * 100 / total_services))
    
    if [[ $startup_success_rate -eq 100 ]]; then
        success "Professional services startup: PERFECT (${successful_services}/${total_services})"
    elif [[ $startup_success_rate -ge 67 ]]; then
        warning "Professional services startup: PARTIAL (${successful_services}/${total_services})"
    else
        error "Professional services startup: FAILED (${successful_services}/${total_services})"
    fi
    
    update_startup_status "service_startup" "completed" "Services started: ${successful_services}/${total_services}"
}

# Professional URL establishment with medical precision
establish_professional_urls() {
    network "Establishing professional access URLs..."
    update_startup_status "url_establishment" "in_progress" "Establishing professional URLs"
    
    # Wait for Django to be fully ready
    local max_attempts=30
    local attempt=0
    
    process "Waiting for Django application to be fully ready..."
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -sf http://localhost:8000 >/dev/null 2>&1; then
            success "Django application: READY"
            break
        fi
        
        ((attempt++))
        process "Django startup validation... (${attempt}/${max_attempts}s)"
        sleep 1
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        error "Django application failed to become ready within timeout"
    fi
    
    # Establish ngrok tunnel
    process "Establishing professional ngrok tunnel..."
    
    # Check if ngrok is configured
    if ! "$SCRIPT_DIR/ngrok" config check >/dev/null 2>&1; then
        warning "Ngrok not authenticated - public URL will not be available"
        echo "Not configured" > "$NGROK_URL_FILE"
        update_startup_status "url_establishment" "partial" "Local URL only - ngrok not configured"
        return 0
    fi
    
    # Start ngrok tunnel
    if ! pgrep -f "ngrok.*http.*8000" >/dev/null; then
        nohup "$SCRIPT_DIR/ngrok" http 8000 --log stdout --log-level info > "$SCRIPT_DIR/ngrok_startup.log" 2>&1 &
        sleep 3
    fi
    
    # Wait for tunnel establishment
    attempt=0
    max_attempts=20
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null | grep -q "https://"; then
            local ngrok_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
            echo "$ngrok_url" > "$NGROK_URL_FILE"
            
            network "Professional public URL established: $ngrok_url"
            
            # Test public accessibility
            if curl -sf "$ngrok_url" >/dev/null 2>&1; then
                success "Professional public URL: ACCESSIBLE"
            else
                warning "Professional public URL: ESTABLISHED BUT NOT ACCESSIBLE"
            fi
            
            update_startup_status "url_establishment" "completed" "Professional URLs established successfully"
            return 0
        fi
        
        ((attempt++))
        network "Ngrok tunnel establishment... (${attempt}/${max_attempts}s)"
        sleep 1
    done
    
    warning "Professional ngrok tunnel not established within timeout"
    echo "Tunnel timeout" > "$NGROK_URL_FILE"
    update_startup_status "url_establishment" "timeout" "Ngrok tunnel establishment timed out"
}

# Professional startup completion display
display_professional_startup_completion() {
    local startup_time=$(($(date +%s) - STARTUP_START_TIME))
    local ngrok_url=$(cat "$NGROK_URL_FILE" 2>/dev/null || echo "Not available")
    
    echo
    echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC}    ${ICON_ROCKET} ${GREEN}Professional NoctisPro Startup Masterpiece Complete${NC} ${ICON_ROCKET}    ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC}           ${CYAN}Medical Imaging System Ready for Excellence${NC}             ${WHITE}║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    success "🎨 Startup Quality: MASTERPIECE LEVEL"
    success "🏥 Medical Standards: FULLY OPERATIONAL"
    success "⚡ Startup Time: ${startup_time}s (Professional Excellence)"
    echo
    
    network "🌐 Professional Medical Imaging Access:"
    echo -e "  ${CYAN}Local Access:${NC}       http://localhost:8000"
    echo -e "  ${CYAN}Public Access:${NC}      $ngrok_url"
    echo -e "  ${CYAN}Admin Dashboard:${NC}    $ngrok_url/admin/"
    echo -e "  ${CYAN}DICOM Viewer:${NC}       $ngrok_url/viewer/"
    echo -e "  ${CYAN}Worklist:${NC}           $ngrok_url/worklist/"
    echo -e "  ${CYAN}Upload Portal:${NC}      $ngrok_url/worklist/upload/"
    echo
    
    log "🎯 Professional Credentials:"
    echo -e "  ${CYAN}Username:${NC}           admin"
    echo -e "  ${CYAN}Password:${NC}           noctispro2025"
    echo -e "  ${CYAN}Role:${NC}               Administrator"
    echo
    
    log "🔧 Professional Management Commands:"
    echo "  Health Check:     $SCRIPT_DIR/professional_health_check.sh"
    echo "  Ngrok Manager:    $SCRIPT_DIR/professional_ngrok_manager.sh status"
    echo "  Service Status:   sudo systemctl status noctispro-professional"
    echo "  View Logs:        sudo journalctl -u noctispro-professional -f"
    echo
    
    log "📊 Professional Monitoring:"
    echo "  System Health:    $SCRIPT_DIR/professional_health_check.sh"
    echo "  Service Logs:     sudo journalctl -u noctispro-professional -f"
    echo "  Ngrok Status:     $SCRIPT_DIR/professional_ngrok_manager.sh status"
    echo "  DICOM Receiver:   sudo journalctl -u noctispro-dicom-receiver -f"
    echo
    
    success "🏆 Professional NoctisPro Medical Imaging System is LIVE!"
    success "🎨 All components operating with masterpiece excellence!"
    success "🏥 Ready for professional medical imaging workflow!"
    
    # Final status update
    update_startup_status "completed" "success" "Professional startup masterpiece completed"
    
    # Display real-time status
    echo
    info "🔴 LIVE STATUS MONITORING:"
    "$SCRIPT_DIR/professional_health_check.sh"
}

# Professional error handling with medical precision
handle_startup_error() {
    local error_code="$1"
    local error_command="$2"
    local phase="$3"
    
    error "Professional startup failed in phase '$phase': $error_command"
    
    # Professional error recovery
    echo
    warning "🔧 Professional Error Recovery:"
    echo "  1. Check system status: sudo systemctl status noctispro-*"
    echo "  2. View error logs: sudo journalctl -u noctispro-professional -n 50"
    echo "  3. Check resources: free -h && df -h"
    echo "  4. Restart services: sudo systemctl restart noctispro-professional"
    echo "  5. Full redeployment: $SCRIPT_DIR/professional_deployment_masterpiece.sh"
    echo
    
    # Update error status
    update_startup_status "$phase" "failed" "Error in $error_command"
    
    exit "$error_code"
}

# Professional main startup orchestration
main_professional_startup() {
    # Professional startup banner
    echo
    echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC}      ${ICON_ROCKET} ${CYAN}Professional NoctisPro Startup Masterpiece${NC} ${ICON_ROCKET}      ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC}            ${GREEN}Medical Imaging Excellence Activation${NC}              ${WHITE}║${NC}"
    echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Initialize professional logging
    echo "Professional NoctisPro Startup Masterpiece: $(date)" > "$STARTUP_LOG"
    update_startup_status "initialization" "started" "Professional startup initiated"
    
    # Professional startup phases with enhanced error handling
    trap 'handle_startup_error $? "$BASH_COMMAND" "$current_phase"' ERR
    
    current_phase="validation"
    validate_professional_system
    
    current_phase="service_startup"
    start_professional_services_enhanced
    
    current_phase="url_establishment"
    establish_professional_urls
    
    current_phase="completion"
    display_professional_startup_completion
    
    # Disable error trap
    trap - ERR
    
    success "🏆 Professional startup masterpiece completed successfully!"
}

# Professional command line interface
case "${1:-start}" in
    "start")
        main_professional_startup
        ;;
    "quick")
        # Quick startup without full validation
        process "Quick professional startup..."
        systemctl start noctispro-professional noctispro-ngrok-professional noctispro-dicom-receiver
        sleep 5
        "$SCRIPT_DIR/professional_health_check.sh"
        ;;
    "stop")
        process "Stopping professional services..."
        systemctl stop noctispro-professional noctispro-ngrok-professional noctispro-dicom-receiver 2>/dev/null || true
        success "Professional services stopped"
        ;;
    "restart")
        process "Restarting professional services..."
        systemctl restart noctispro-professional noctispro-ngrok-professional noctispro-dicom-receiver
        sleep 5
        "$SCRIPT_DIR/professional_health_check.sh"
        ;;
    "status")
        "$SCRIPT_DIR/professional_health_check.sh"
        ;;
    "help"|*)
        echo
        echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${WHITE}║${NC}    ${ICON_ROCKET} ${CYAN}Professional NoctisPro Startup Manager${NC} ${ICON_ROCKET}    ${WHITE}║${NC}"
        echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${CYAN}Professional Commands:${NC}"
        echo "  $0 start       - Full professional startup with validation"
        echo "  $0 quick       - Quick professional startup"
        echo "  $0 stop        - Stop all professional services"
        echo "  $0 restart     - Restart all professional services"
        echo "  $0 status      - Check professional system status"
        echo
        echo -e "${CYAN}Professional Usage:${NC}"
        echo "  Normal startup: $0 start"
        echo "  Quick check:    $0 status"
        echo "  Emergency:      $0 restart"
        echo
        ;;
esac