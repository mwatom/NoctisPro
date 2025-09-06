#!/bin/bash

# =============================================================================
# NOCTIS PRO MASTERPIECE SYSTEM MONITOR
# Real-time monitoring and auto-recovery for all system components
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
STATIC_URL="mallard-shining-curiously.ngrok-free.app"
CHECK_INTERVAL=10
LOG_FILE="masterpiece_monitor.log"

echo -e "${PURPLE}🔍 NOCTIS PRO MASTERPIECE SYSTEM MONITOR${NC}"
echo -e "${CYAN}=======================================${NC}"

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to check Django server
check_django() {
    if curl -s http://localhost:8000 > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check ngrok tunnel
check_ngrok() {
    if curl -s "https://${STATIC_URL}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check system components
check_system_components() {
    local status_ok=true
    
    echo -e "${BLUE}🔍 Checking system components...${NC}"
    
    # Check Django apps
    local apps=("accounts" "admin_panel" "ai_analysis" "dicom_viewer" "reports" "worklist")
    for app in "${apps[@]}"; do
        if [ -d "$app" ]; then
            echo -e "${GREEN}  ✅ ${app}${NC}"
        else
            echo -e "${RED}  ❌ ${app}${NC}"
            status_ok=false
        fi
    done
    
    # Check DICOM viewer components
    if [ -f "templates/dicom_viewer/masterpiece_viewer.html" ]; then
        echo -e "${GREEN}  ✅ Masterpiece DICOM Viewer${NC}"
    else
        echo -e "${RED}  ❌ Masterpiece DICOM Viewer${NC}"
        status_ok=false
    fi
    
    if [ -f "static/js/masterpiece_3d_reconstruction.js" ]; then
        echo -e "${GREEN}  ✅ 3D Reconstruction Module${NC}"
    else
        echo -e "${YELLOW}  ⚠️  3D Reconstruction Module${NC}"
    fi
    
    # Check database
    if [ -f "db.sqlite3" ]; then
        echo -e "${GREEN}  ✅ Database${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Database${NC}"
    fi
    
    # Check static files
    if [ -d "staticfiles" ]; then
        echo -e "${GREEN}  ✅ Static Files${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Static Files${NC}"
    fi
    
    # Check media directory
    if [ -d "media" ]; then
        echo -e "${GREEN}  ✅ Media Directory${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Media Directory${NC}"
    fi
    
    return $status_ok
}

# Function to get system statistics
get_system_stats() {
    echo -e "${BLUE}📊 SYSTEM STATISTICS:${NC}"
    
    # Memory usage
    local mem_usage=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')
    echo -e "${GREEN}  💾 Memory Usage: ${mem_usage}${NC}"
    
    # Disk usage
    local disk_usage=$(df -h . | awk 'NR==2{print $5}')
    echo -e "${GREEN}  💽 Disk Usage: ${disk_usage}${NC}"
    
    # Process count
    local django_processes=$(pgrep -f "python.*manage.py" | wc -l)
    local ngrok_processes=$(pgrep -f "ngrok.*http" | wc -l)
    echo -e "${GREEN}  🔥 Django Processes: ${django_processes}${NC}"
    echo -e "${GREEN}  🌐 ngrok Processes: ${ngrok_processes}${NC}"
    
    # Database size
    if [ -f "db.sqlite3" ]; then
        local db_size=$(du -h db.sqlite3 | cut -f1)
        echo -e "${GREEN}  🗄️  Database Size: ${db_size}${NC}"
    fi
    
    # Check for DICOM files
    if [ -d "media/dicom" ]; then
        local dicom_count=$(find media/dicom -name "*.dcm" 2>/dev/null | wc -l)
        echo -e "${GREEN}  🖼️  DICOM Files: ${dicom_count}${NC}"
    fi
}

# Function to check service health
check_service_health() {
    local django_ok=false
    local ngrok_ok=false
    
    # Check Django
    if check_django; then
        echo -e "${GREEN}  ✅ Django Server: HEALTHY${NC}"
        django_ok=true
    else
        echo -e "${RED}  ❌ Django Server: DOWN${NC}"
        log_message "${RED}Django server is down${NC}"
    fi
    
    # Check ngrok
    if check_ngrok; then
        echo -e "${GREEN}  ✅ ngrok Tunnel: HEALTHY${NC}"
        ngrok_ok=true
    else
        echo -e "${RED}  ❌ ngrok Tunnel: DOWN${NC}"
        log_message "${RED}ngrok tunnel is down${NC}"
    fi
    
    # Overall status
    if $django_ok && $ngrok_ok; then
        echo -e "${GREEN}🎉 SYSTEM STATUS: ALL SERVICES HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}⚠️  SYSTEM STATUS: SERVICES DOWN${NC}"
        return 1
    fi
}

# Function to restart services if needed
restart_services() {
    echo -e "${YELLOW}🔄 Attempting to restart services...${NC}"
    
    # Kill existing processes
    pkill -f "python.*manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    
    sleep 3
    
    # Restart Django
    echo -e "${BLUE}🔥 Restarting Django...${NC}"
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    nohup python manage.py runserver 0.0.0.0:8000 > django.log 2>&1 &
    sleep 5
    
    # Restart ngrok
    echo -e "${BLUE}🌐 Restarting ngrok...${NC}"
    if command -v ngrok &> /dev/null; then
        nohup ngrok http --url=${STATIC_URL} 8000 > ngrok.log 2>&1 &
    else
        nohup ./ngrok http --url=${STATIC_URL} 8000 > ngrok.log 2>&1 &
    fi
    sleep 8
    
    echo -e "${GREEN}✅ Services restarted${NC}"
}

# Main monitoring loop
main_monitor() {
    log_message "${GREEN}Masterpiece monitor started${NC}"
    
    while true; do
        clear
        echo -e "${PURPLE}🔍 NOCTIS PRO MASTERPIECE SYSTEM MONITOR${NC}"
        echo -e "${CYAN}=======================================${NC}"
        echo -e "${BLUE}📅 $(date)${NC}"
        echo -e "${BLUE}🌐 Public URL: https://${STATIC_URL}${NC}"
        echo ""
        
        # Check system components
        check_system_components
        echo ""
        
        # Get system statistics
        get_system_stats
        echo ""
        
        # Check service health
        echo -e "${BLUE}🏥 SERVICE HEALTH CHECK:${NC}"
        if ! check_service_health; then
            echo ""
            echo -e "${YELLOW}🚨 SERVICES DOWN - ATTEMPTING AUTO-RECOVERY${NC}"
            restart_services
            sleep 10
            
            # Verify restart
            if check_service_health; then
                echo -e "${GREEN}✅ AUTO-RECOVERY SUCCESSFUL${NC}"
                log_message "${GREEN}Auto-recovery successful${NC}"
            else
                echo -e "${RED}❌ AUTO-RECOVERY FAILED${NC}"
                log_message "${RED}Auto-recovery failed${NC}"
            fi
        fi
        
        echo ""
        echo -e "${CYAN}💡 Press Ctrl+C to stop monitoring${NC}"
        echo -e "${CYAN}⏳ Next check in ${CHECK_INTERVAL} seconds...${NC}"
        
        sleep $CHECK_INTERVAL
    done
}

# Cleanup function
cleanup() {
    log_message "${YELLOW}Monitor stopped by user${NC}"
    echo -e "\n${YELLOW}🛑 Monitoring stopped${NC}"
    exit 0
}

# Set up signal handler
trap cleanup SIGINT SIGTERM

# Start monitoring
main_monitor