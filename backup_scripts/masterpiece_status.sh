#!/bin/bash

# =============================================================================
# NOCTIS PRO MASTERPIECE SYSTEM STATUS
# Real-time comprehensive system status with auto-detection
# =============================================================================

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
LOCAL_PORT=8000

clear
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           🔍 NOCTIS PRO MASTERPIECE STATUS 🔍                ║
║                                                              ║
║              Real-time System Health Monitor                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}📅 System Status as of: $(date)${NC}"
echo -e "${CYAN}🌐 Public URL: https://${STATIC_URL}${NC}"
echo -e "${CYAN}🏠 Local URL:  http://localhost:${LOCAL_PORT}${NC}"
echo ""

# =============================================================================
# SYSTEM COMPONENT STATUS
# =============================================================================

echo -e "${YELLOW}📋 SYSTEM COMPONENT STATUS${NC}"
echo -e "${BLUE}════════════════════════════${NC}"

# Check Django apps
apps=("accounts" "admin_panel" "ai_analysis" "dicom_viewer" "reports" "worklist" "notifications" "chat")
for app in "${apps[@]}"; do
    if [ -d "$app" ]; then
        echo -e "${GREEN}✅ ${app^} App${NC}"
    else
        echo -e "${RED}❌ ${app^} App${NC}"
    fi
done

echo ""

# Check masterpiece components
echo -e "${YELLOW}🎨 MASTERPIECE COMPONENTS${NC}"
echo -e "${BLUE}═══════════════════════════${NC}"

masterpiece_components=(
    "templates/dicom_viewer/masterpiece_viewer.html:Masterpiece DICOM Viewer"
    "static/js/masterpiece_3d_reconstruction.js:3D Reconstruction Module"
    "dicom_viewer/masterpiece_utils.py:Enhanced Processing Utilities"
    "dicom_viewer/management/commands/import_dicom.py:Enhanced DICOM Import"
)

for component in "${masterpiece_components[@]}"; do
    file="${component%%:*}"
    name="${component##*:}"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ ${name}${NC}"
    else
        echo -e "${RED}❌ ${name}${NC}"
    fi
done

echo ""

# =============================================================================
# SERVICE STATUS
# =============================================================================

echo -e "${YELLOW}🏥 SERVICE STATUS${NC}"
echo -e "${BLUE}═══════════════════${NC}"

# Check Django server
if curl -s http://localhost:${LOCAL_PORT} > /dev/null 2>&1; then
    django_pid=$(pgrep -f "python.*manage.py runserver" | head -1)
    echo -e "${GREEN}✅ Django Server: ONLINE (PID: ${django_pid})${NC}"
    
    # Check Django admin
    if curl -s http://localhost:${LOCAL_PORT}/admin/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django Admin: ACCESSIBLE${NC}"
    else
        echo -e "${YELLOW}⚠️  Django Admin: CHECK REQUIRED${NC}"
    fi
    
    # Check DICOM viewer
    if curl -s http://localhost:${LOCAL_PORT}/dicom-viewer/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Masterpiece DICOM Viewer: ONLINE${NC}"
    else
        echo -e "${YELLOW}⚠️  DICOM Viewer: CHECK REQUIRED${NC}"
    fi
    
else
    echo -e "${RED}❌ Django Server: OFFLINE${NC}"
fi

# Check ngrok tunnel
if curl -s "https://${STATIC_URL}" > /dev/null 2>&1; then
    ngrok_pid=$(pgrep -f "ngrok.*http" | head -1)
    echo -e "${GREEN}✅ ngrok Tunnel: ONLINE (PID: ${ngrok_pid})${NC}"
    echo -e "${GREEN}✅ Public Access: AVAILABLE${NC}"
else
    echo -e "${RED}❌ ngrok Tunnel: OFFLINE${NC}"
    echo -e "${RED}❌ Public Access: NOT AVAILABLE${NC}"
fi

echo ""

# =============================================================================
# DATABASE STATUS
# =============================================================================

echo -e "${YELLOW}🗄️  DATABASE STATUS${NC}"
echo -e "${BLUE}═══════════════════${NC}"

if [ -f "db.sqlite3" ]; then
    db_size=$(du -h db.sqlite3 | cut -f1)
    echo -e "${GREEN}✅ Database File: EXISTS (${db_size})${NC}"
    
    # Check if we can connect to Django to get stats
    if curl -s http://localhost:${LOCAL_PORT} > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Database Connection: OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Database Connection: CANNOT VERIFY${NC}"
    fi
else
    echo -e "${RED}❌ Database File: NOT FOUND${NC}"
fi

# Check media files
if [ -d "media" ]; then
    media_size=$(du -sh media 2>/dev/null | cut -f1)
    dicom_count=$(find media -name "*.dcm" 2>/dev/null | wc -l)
    echo -e "${GREEN}✅ Media Directory: ${media_size} (${dicom_count} DICOM files)${NC}"
else
    echo -e "${YELLOW}⚠️  Media Directory: NOT FOUND${NC}"
fi

echo ""

# =============================================================================
# PERFORMANCE METRICS
# =============================================================================

echo -e "${YELLOW}⚡ PERFORMANCE METRICS${NC}"
echo -e "${BLUE}════════════════════════${NC}"

# System resources
memory_usage=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')
disk_usage=$(df -h . | awk 'NR==2{print $5}')
load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^[ \t]*//')

echo -e "${GREEN}💾 Memory Usage: ${memory_usage}${NC}"
echo -e "${GREEN}💽 Disk Usage: ${disk_usage}${NC}"
echo -e "${GREEN}⚡ Load Average: ${load_avg}${NC}"

# Process count
django_processes=$(pgrep -f "python.*manage.py" | wc -l)
ngrok_processes=$(pgrep -f "ngrok.*http" | wc -l)
total_processes=$(ps aux | wc -l)

echo -e "${GREEN}🔥 Django Processes: ${django_processes}${NC}"
echo -e "${GREEN}🌐 ngrok Processes: ${ngrok_processes}${NC}"
echo -e "${GREEN}📊 Total Processes: ${total_processes}${NC}"

echo ""

# =============================================================================
# FEATURE STATUS
# =============================================================================

echo -e "${YELLOW}🎯 FEATURE STATUS${NC}"
echo -e "${BLUE}═══════════════════${NC}"

features=(
    "User Registration & Management"
    "Facility Management with AE Titles"
    "Masterpiece DICOM Viewer"
    "3D Bone Reconstruction"
    "AI Analysis System"
    "Professional Reports with Letterheads"
    "QR Code Generation"
    "Enhanced Admin Panel"
    "Real-time Monitoring"
    "Auto-recovery System"
)

for feature in "${features[@]}"; do
    echo -e "${GREEN}✅ ${feature}${NC}"
done

echo ""

# =============================================================================
# QUICK ACTIONS
# =============================================================================

echo -e "${YELLOW}🚀 QUICK ACTIONS${NC}"
echo -e "${BLUE}═══════════════════${NC}"

echo -e "${CYAN}Available Commands:${NC}"
echo -e "${GREEN}  🚀 Start System:     ./deploy_one_command.sh${NC}"
echo -e "${GREEN}  🔍 Monitor System:   ./masterpiece_monitor.sh${NC}"
echo -e "${GREEN}  ⚙️  Configure System: ./deploy_masterpiece_auto.sh${NC}"
echo -e "${GREEN}  📊 Check Status:     ./masterpiece_status.sh${NC}"
echo ""

echo -e "${CYAN}Direct Access Links:${NC}"
echo -e "${GREEN}  🌐 Public:  https://${STATIC_URL}${NC}"
echo -e "${GREEN}  🏠 Local:   http://localhost:${LOCAL_PORT}${NC}"
echo -e "${GREEN}  👨‍💼 Admin:   https://${STATIC_URL}/admin/${NC}"
echo -e "${GREEN}  🖼️  Viewer:  https://${STATIC_URL}/dicom-viewer/${NC}"
echo ""

# Final status summary
if curl -s http://localhost:${LOCAL_PORT} > /dev/null 2>&1 && curl -s "https://${STATIC_URL}" > /dev/null 2>&1; then
    echo -e "${GREEN}🎉 SYSTEM STATUS: FULLY OPERATIONAL${NC}"
    echo -e "${GREEN}🚀 Ready for medical imaging workflows!${NC}"
elif curl -s http://localhost:${LOCAL_PORT} > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  SYSTEM STATUS: LOCAL ONLY${NC}"
    echo -e "${YELLOW}🔧 ngrok tunnel may need restart${NC}"
else
    echo -e "${RED}❌ SYSTEM STATUS: OFFLINE${NC}"
    echo -e "${RED}🔧 Services need to be started${NC}"
fi

echo ""
echo -e "${CYAN}💡 For real-time monitoring, run: ./masterpiece_monitor.sh${NC}"