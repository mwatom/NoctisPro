#!/bin/bash

# 🏥 Professional NoctisPro Health Check System
# Medical Imaging Excellence - Comprehensive System Monitoring
# Enhanced with masterpiece-level diagnostics and professional reporting

set -euo pipefail

# Professional color palette
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m'

# Professional medical icons
declare -r ICON_HEALTH="🏥"
declare -r ICON_SUCCESS="✅"
declare -r ICON_ERROR="🚨"
declare -r ICON_WARNING="⚠️"
declare -r ICON_INFO="ℹ️"
declare -r ICON_MONITOR="📊"
declare -r ICON_NETWORK="🌐"
declare -r ICON_DATABASE="🗄️"
declare -r ICON_SERVICE="⚙️"

# Professional configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_LOG="$SCRIPT_DIR/professional_health.log"
NGROK_URL_FILE="$SCRIPT_DIR/current_ngrok_url.txt"
HEALTH_REPORT="$SCRIPT_DIR/health_report.json"

# Professional logging with medical precision
health_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    case "$level" in
        "SUCCESS") echo -e "${GREEN}${ICON_SUCCESS} [${timestamp}] ${message}${NC}" ;;
        "ERROR")   echo -e "${RED}${ICON_ERROR} [${timestamp}] ${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}${ICON_WARNING} [${timestamp}] ${message}${NC}" ;;
        "INFO")    echo -e "${BLUE}${ICON_INFO} [${timestamp}] ${message}${NC}" ;;
        "MONITOR") echo -e "${CYAN}${ICON_MONITOR} [${timestamp}] ${message}${NC}" ;;
        "NETWORK") echo -e "${MAGENTA}${ICON_NETWORK} [${timestamp}] ${message}${NC}" ;;
        *)         echo -e "${WHITE}[${timestamp}] ${message}${NC}" ;;
    esac
    
    # Log to file
    echo "[${timestamp}] [$level] $message" >> "$HEALTH_LOG"
}

success() { health_log "SUCCESS" "$1"; }
error() { health_log "ERROR" "$1"; }
warning() { health_log "WARNING" "$1"; }
info() { health_log "INFO" "$1"; }
monitor() { health_log "MONITOR" "$1"; }
network() { health_log "NETWORK" "$1"; }

# Professional health check functions
check_system_resources() {
    monitor "Checking professional system resources..."
    
    # Memory check
    local memory_info=$(free -m)
    local memory_used=$(echo "$memory_info" | awk 'NR==2{printf "%.1f", $3/$2*100}')
    local memory_available=$(echo "$memory_info" | awk 'NR==2{print $7}')
    
    if (( $(echo "$memory_used < 80" | bc -l) )); then
        success "Memory usage: ${memory_used}% (Available: ${memory_available}MB)"
    else
        warning "High memory usage: ${memory_used}% (Available: ${memory_available}MB)"
    fi
    
    # Disk space check
    local disk_info=$(df -h /)
    local disk_used=$(echo "$disk_info" | awk 'NR==2{print $5}' | sed 's/%//')
    local disk_available=$(echo "$disk_info" | awk 'NR==2{print $4}')
    
    if [[ $disk_used -lt 80 ]]; then
        success "Disk usage: ${disk_used}% (Available: ${disk_available})"
    else
        warning "High disk usage: ${disk_used}% (Available: ${disk_available})"
    fi
    
    # CPU load check
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local cpu_percentage=$(echo "scale=1; $cpu_load / $cpu_cores * 100" | bc)
    
    if (( $(echo "$cpu_percentage < 70" | bc -l) )); then
        success "CPU load: ${cpu_percentage}% (Load: ${cpu_load}/${cpu_cores} cores)"
    else
        warning "High CPU load: ${cpu_percentage}% (Load: ${cpu_load}/${cpu_cores} cores)"
    fi
}

check_professional_services() {
    monitor "Checking professional medical imaging services..."
    
    local services=(
        "noctispro-professional:Django Application"
        "noctispro-ngrok-professional:Public Access Tunnel"
        "noctispro-dicom-receiver:DICOM Network Receiver"
    )
    
    local active_services=0
    local total_services=${#services[@]}
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo "$service_info" | cut -d':' -f1)
        local service_desc=$(echo "$service_info" | cut -d':' -f2)
        
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            success "$service_desc: ACTIVE"
            ((active_services++))
        else
            error "$service_desc: INACTIVE"
            
            # Get service status details
            local status_info=$(systemctl status "$service_name" --no-pager -l 2>/dev/null | head -3 | tail -1 || echo "Status unavailable")
            warning "  Status: $status_info"
        fi
    done
    
    local service_health=$((active_services * 100 / total_services))
    
    if [[ $service_health -eq 100 ]]; then
        success "Professional services health: EXCELLENT (${active_services}/${total_services} active)"
    elif [[ $service_health -ge 67 ]]; then
        warning "Professional services health: GOOD (${active_services}/${total_services} active)"
    else
        error "Professional services health: CRITICAL (${active_services}/${total_services} active)"
    fi
}

check_network_connectivity() {
    network "Checking professional network connectivity..."
    
    # Local HTTP check
    if curl -sf http://localhost:8000 >/dev/null 2>&1; then
        success "Local HTTP endpoint: RESPONSIVE"
        
        # Get response time
        local response_time=$(curl -w "%{time_total}" -s -o /dev/null http://localhost:8000)
        if (( $(echo "$response_time < 1.0" | bc -l) )); then
            success "Local response time: ${response_time}s (EXCELLENT)"
        else
            warning "Local response time: ${response_time}s (SLOW)"
        fi
    else
        error "Local HTTP endpoint: NOT RESPONSIVE"
    fi
    
    # Ngrok public URL check
    if [[ -f "$NGROK_URL_FILE" ]]; then
        local ngrok_url=$(cat "$NGROK_URL_FILE")
        if [[ "$ngrok_url" =~ ^https?:// ]]; then
            network "Testing public URL: $ngrok_url"
            
            if curl -sf "$ngrok_url" >/dev/null 2>&1; then
                success "Public URL: ACCESSIBLE"
                
                # Get public response time
                local public_response_time=$(curl -w "%{time_total}" -s -o /dev/null "$ngrok_url")
                if (( $(echo "$public_response_time < 3.0" | bc -l) )); then
                    success "Public response time: ${public_response_time}s (EXCELLENT)"
                else
                    warning "Public response time: ${public_response_time}s (SLOW)"
                fi
            else
                error "Public URL: NOT ACCESSIBLE"
            fi
        else
            warning "Public URL: INVALID FORMAT"
        fi
    else
        warning "Public URL: NOT CONFIGURED"
    fi
    
    # DICOM port check (11112)
    if netstat -ln | grep -q ":11112 "; then
        success "DICOM receiver port 11112: LISTENING"
    else
        warning "DICOM receiver port 11112: NOT LISTENING"
    fi
}

check_database_connectivity() {
    monitor "Checking professional database connectivity..."
    
    cd "$SCRIPT_DIR/noctis_pro_deployment" || error "Deployment directory not found"
    
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
        
        # Database connection check
        if python manage.py check --database default >/dev/null 2>&1; then
            success "Database connectivity: EXCELLENT"
            
            # Get database statistics
            local db_stats=$(python manage.py shell -c "
from worklist.models import Study, Patient, DicomImage
from django.contrib.auth import get_user_model
User = get_user_model()
print(f'Users: {User.objects.count()}')
print(f'Patients: {Patient.objects.count()}')
print(f'Studies: {Study.objects.count()}')
print(f'Images: {DicomImage.objects.count()}')
" 2>/dev/null)
            
            if [[ -n "$db_stats" ]]; then
                success "Database statistics:"
                echo "$db_stats" | while read line; do
                    success "  $line"
                done
            fi
        else
            error "Database connectivity: FAILED"
        fi
        
        # Migration check
        if python manage.py showmigrations --plan | grep -q "\[ \]"; then
            warning "Pending database migrations detected"
        else
            success "Database migrations: UP TO DATE"
        fi
    else
        error "Python virtual environment not found"
    fi
}

check_professional_performance() {
    monitor "Checking professional system performance..."
    
    # System uptime
    local uptime_info=$(uptime -p)
    success "System uptime: $uptime_info"
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    success "Load average:$load_avg"
    
    # Process count
    local noctispro_processes=$(pgrep -f "noctispro\|gunicorn\|ngrok" | wc -l)
    success "NoctisPro processes: $noctispro_processes active"
    
    # Port usage
    local ports_in_use=$(netstat -tuln | grep -E ":(8000|4040|11112) " | wc -l)
    success "Professional ports active: $ports_in_use/3"
    
    # Log file sizes
    if [[ -f "$HEALTH_LOG" ]]; then
        local log_size=$(du -h "$HEALTH_LOG" | cut -f1)
        success "Health log size: $log_size"
    fi
}

generate_professional_report() {
    monitor "Generating professional health report..."
    
    local timestamp=$(date -Iseconds)
    local uptime=$(uptime -p)
    local ngrok_url=$(cat "$NGROK_URL_FILE" 2>/dev/null || echo "Not available")
    
    # Professional JSON health report
    cat > "$HEALTH_REPORT" << EOF
{
    "health_check_timestamp": "$timestamp",
    "system_version": "Noctis Pro PACS v2.0 Enhanced",
    "deployment_quality": "Medical Grade Excellence",
    "system_uptime": "$uptime",
    "services": {
        "django": "$(systemctl is-active noctispro-professional 2>/dev/null || echo 'inactive')",
        "ngrok": "$(systemctl is-active noctispro-ngrok-professional 2>/dev/null || echo 'inactive')",
        "dicom_receiver": "$(systemctl is-active noctispro-dicom-receiver 2>/dev/null || echo 'inactive')"
    },
    "connectivity": {
        "local_url": "http://localhost:8000",
        "public_url": "$ngrok_url",
        "dicom_port": "11112"
    },
    "resources": {
        "memory_usage_percent": "$(free | awk 'NR==2{printf "%.1f", $3/$2*100}')",
        "disk_usage_percent": "$(df / | awk 'NR==2{print $5}' | sed 's/%//')",
        "cpu_load": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')"
    },
    "health_score": "$(calculate_health_score)",
    "last_check": "$timestamp"
}
EOF
    
    success "Professional health report generated: $HEALTH_REPORT"
}

calculate_health_score() {
    local score=0
    local max_score=100
    
    # Service checks (40 points)
    systemctl is-active --quiet noctispro-professional 2>/dev/null && ((score+=15))
    systemctl is-active --quiet noctispro-ngrok-professional 2>/dev/null && ((score+=15))
    systemctl is-active --quiet noctispro-dicom-receiver 2>/dev/null && ((score+=10))
    
    # Connectivity checks (30 points)
    curl -sf http://localhost:8000 >/dev/null 2>&1 && ((score+=15))
    [[ -f "$NGROK_URL_FILE" ]] && grep -q "https://" "$NGROK_URL_FILE" && ((score+=15))
    
    # Resource checks (30 points)
    local memory_used=$(free | awk 'NR==2{printf "%.0f", $3/$2*100}')
    [[ $memory_used -lt 80 ]] && ((score+=10))
    
    local disk_used=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
    [[ $disk_used -lt 80 ]] && ((score+=10))
    
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    (( $(echo "$load_avg < $cpu_cores" | bc -l) )) && ((score+=10))
    
    echo $score
}

# Professional main health check
main_professional_health_check() {
    # Professional health check banner
    echo
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC}    ${ICON_HEALTH} ${CYAN}Professional NoctisPro Health Check System${NC} ${ICON_HEALTH}    ${WHITE}║${NC}"
    echo -e "${WHITE}║${NC}           ${GREEN}Medical Imaging System Diagnostics${NC}               ${WHITE}║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Initialize health check logging
    echo "Professional NoctisPro Health Check Started: $(date)" > "$HEALTH_LOG"
    
    # Professional health check phases
    check_system_resources
    echo
    
    check_professional_services  
    echo
    
    check_network_connectivity
    echo
    
    check_database_connectivity
    echo
    
    check_professional_performance
    echo
    
    generate_professional_report
    echo
    
    # Professional health summary
    local health_score=$(calculate_health_score)
    
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC}                ${ICON_MONITOR} ${CYAN}Professional Health Summary${NC} ${ICON_MONITOR}                ${WHITE}║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    if [[ $health_score -ge 90 ]]; then
        success "🏆 System Health: EXCELLENT ($health_score/100) - Medical Grade Excellence"
    elif [[ $health_score -ge 75 ]]; then
        warning "✅ System Health: GOOD ($health_score/100) - Professional Standards Met"
    elif [[ $health_score -ge 60 ]]; then
        warning "⚠️ System Health: ACCEPTABLE ($health_score/100) - Some Issues Detected"
    else
        error "🚨 System Health: CRITICAL ($health_score/100) - Immediate Attention Required"
    fi
    
    # Display access information
    echo
    network "🌐 Professional Access URLs:"
    echo -e "  ${CYAN}Local Access:${NC}     http://localhost:8000"
    
    if [[ -f "$NGROK_URL_FILE" ]]; then
        local ngrok_url=$(cat "$NGROK_URL_FILE")
        echo -e "  ${CYAN}Public Access:${NC}    $ngrok_url"
        echo -e "  ${CYAN}Admin Panel:${NC}      $ngrok_url/admin/"
        echo -e "  ${CYAN}DICOM Viewer:${NC}     $ngrok_url/viewer/"
    else
        warning "  Public Access:    NOT CONFIGURED"
    fi
    
    echo
    info "📊 Professional Reports:"
    echo "  Health Log:       $HEALTH_LOG"
    echo "  Health Report:    $HEALTH_REPORT"
    echo "  Deployment Log:   $SCRIPT_DIR/professional_deployment.log"
    
    echo
    success "🏥 Professional health check completed with medical precision!"
}

# Execute professional health check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_professional_health_check "$@"
fi