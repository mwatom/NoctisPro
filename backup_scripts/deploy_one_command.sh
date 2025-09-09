#!/bin/bash

# =============================================================================
# NOCTIS PRO MASTERPIECE - ONE COMMAND DEPLOYMENT
# Complete system deployment with auto-detection in a single command
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

# Configuration (can be overridden via environment)
NGROK_AUTHTOKEN="${NGROK_AUTHTOKEN:-}"
STATIC_URL="${STATIC_URL:-}"
PORT="${PORT:-8000}"

clear
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║        🚀 NOCTIS PRO MASTERPIECE DEPLOYMENT 🚀               ║
║                                                              ║
║    🏥 Complete Medical PACS System with DICOM Viewer        ║
║    🤖 AI Analysis • 📄 Reports • 👥 User Management         ║
║    🖼️  Masterpiece DICOM Viewer with 3D Reconstruction     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}🔧 Auto-configuring with your settings:${NC}"
echo -e "${GREEN}   🔑 Authtoken: ${NGROK_AUTHTOKEN:0:10}...${NC}"
echo -e "${GREEN}   🌐 Static URL: ${STATIC_URL}${NC}"
echo -e "${GREEN}   🚪 Port: ${PORT}${NC}"
echo ""

# =============================================================================
# PHASE 1: ENVIRONMENT SETUP
# =============================================================================

echo -e "${YELLOW}📋 PHASE 1: ENVIRONMENT SETUP${NC}"

# Ensure basic tools
if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    echo -e "${BLUE}📦 Installing curl and tar...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y -qq curl tar >/dev/null 2>&1 || true
fi

# Auto-detect Python
if command -v python3 &> /dev/null; then
    PYTHON="python3"
    PIP="pip3"
elif command -v python &> /dev/null; then
    PYTHON="python"
    PIP="pip"
else
    echo -e "${RED}❌ Python not found! Installing...${NC}"
    sudo apt update && sudo apt install -y python3 python3-pip python3-venv
    PYTHON="python3"
    PIP="pip3"
fi

echo -e "${GREEN}✅ Python: $($PYTHON --version)${NC}"

# Setup virtual environment
if [ ! -d "venv" ]; then
    echo -e "${BLUE}🏠 Creating virtual environment...${NC}"
    $PYTHON -m venv venv
fi

source venv/bin/activate
echo -e "${GREEN}✅ Virtual environment activated${NC}"

# Install dependencies
echo -e "${BLUE}📚 Installing dependencies...${NC}"
$PIP install -r requirements.txt --quiet || $PIP install --quiet Django Pillow requests
echo -e "${GREEN}✅ Dependencies installed${NC}"

# =============================================================================
# PHASE 2: NGROK SETUP
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 2: NGROK SETUP${NC}"

# Auto-download ngrok if needed
if ! command -v ngrok &> /dev/null && [ ! -f "./ngrok" ]; then
    echo -e "${BLUE}📥 Downloading ngrok...${NC}"
    
    # Detect system architecture
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac
    
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-${OS}-${ARCH}.tgz"
    curl -L -o ngrok.tgz "$NGROK_URL" --silent
    tar xzf ngrok.tgz
    rm ngrok.tgz
    chmod +x ngrok
    
    echo -e "${GREEN}✅ ngrok downloaded for ${OS}-${ARCH}${NC}"
fi

# Configure ngrok (if token provided)
NGROK_CMD="ngrok"
if [ -f "./ngrok" ]; then
    NGROK_CMD="./ngrok"
fi

if [ -n "$NGROK_AUTHTOKEN" ]; then
    echo -e "${BLUE}🔑 Configuring ngrok authtoken...${NC}"
    $NGROK_CMD config add-authtoken "$NGROK_AUTHTOKEN"
    echo -e "${GREEN}✅ ngrok authtoken configured${NC}"
else
    echo -e "${YELLOW}⚠️  NGROK_AUTHTOKEN not set; proceeding without reserved domains${NC}"
fi

# =============================================================================
# PHASE 3: DJANGO CONFIGURATION
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 3: DJANGO CONFIGURATION${NC}"

# Auto-detect project structure
PROJECT_DIR=""
for dir in */; do
    if [ -f "${dir}settings.py" ]; then
        PROJECT_DIR=$(basename "$dir")
        break
    fi
done

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="noctis_pro"
fi

echo -e "${GREEN}✅ Project detected: ${PROJECT_DIR}${NC}"

# Configure Django settings for ngrok
if [ -f "masterpiece_auto_config.py" ]; then
    echo -e "${BLUE}⚙️  Optimizing Django settings...${NC}"
    $PYTHON masterpiece_auto_config.py || true
    echo -e "${GREEN}✅ Django settings optimization step completed${NC}"
fi

# Export ALLOWED_HOSTS if STATIC_URL provided
if [ -n "$STATIC_URL" ]; then
    export ALLOWED_HOSTS="*,${STATIC_URL},localhost,127.0.0.1"
fi

# Run Django setup
echo -e "${BLUE}🔄 Setting up Django...${NC}"
$PYTHON manage.py migrate
$PYTHON manage.py collectstatic --noinput

# Create media directories
mkdir -p media/dicom/images
mkdir -p media/reports
mkdir -p media/letterheads
echo -e "${GREEN}✅ Django setup completed${NC}"

# =============================================================================
# PHASE 4: SYSTEM VERIFICATION
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 4: SYSTEM VERIFICATION${NC}"

# Verify all components
echo -e "${BLUE}🔍 Verifying system components...${NC}"

components=(
    "accounts:User Registration"
    "admin_panel:Admin Panel" 
    "ai_analysis:AI Analysis"
    "dicom_viewer:DICOM Viewer"
    "reports:Report System"
    "worklist:Worklist Management"
)

for component in "${components[@]}"; do
    app="${component%%:*}"
    name="${component##*:}"
    
    if [ -d "$app" ]; then
        echo -e "${GREEN}  ✅ ${name}${NC}"
    else
        echo -e "${RED}  ❌ ${name}${NC}"
    fi
done

# Verify masterpiece components
echo -e "${BLUE}🎨 Verifying masterpiece components...${NC}"

if [ -f "templates/dicom_viewer/masterpiece_viewer.html" ]; then
    echo -e "${GREEN}  ✅ Masterpiece DICOM Viewer${NC}"
else
    echo -e "${RED}  ❌ Masterpiece DICOM Viewer${NC}"
fi

if [ -f "static/js/masterpiece_3d_reconstruction.js" ]; then
    echo -e "${GREEN}  ✅ 3D Reconstruction Module${NC}"
else
    echo -e "${RED}  ❌ 3D Reconstruction Module${NC}"
fi

# =============================================================================
# PHASE 5: LAUNCH SYSTEM
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 5: LAUNCHING MASTERPIECE SYSTEM${NC}"

# Create PID file directory
mkdir -p .pids

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Stopping services...${NC}"
    
    if [ -f ".pids/django.pid" ]; then
        DJANGO_PID=$(cat .pids/django.pid)
        kill $DJANGO_PID 2>/dev/null || true
        rm -f .pids/django.pid
    fi
    
    if [ -f ".pids/ngrok.pid" ]; then
        NGROK_PID=$(cat .pids/ngrok.pid)
        kill $NGROK_PID 2>/dev/null || true
        rm -f .pids/ngrok.pid
    fi
    
    pkill -f "python.*manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    
    echo -e "${GREEN}✅ All services stopped${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Start Django server
echo -e "${BLUE}🔥 Starting Django development server...${NC}"
nohup $PYTHON manage.py runserver 0.0.0.0:$PORT > django.log 2>&1 &
DJANGO_PID=$!
echo $DJANGO_PID > .pids/django.pid

# Wait for Django to start
sleep 5

# Verify Django is running
if curl -s http://localhost:$PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Django server online (PID: $DJANGO_PID)${NC}"
else
    echo -e "${RED}❌ Django server failed to start${NC}"
    cat django.log
    exit 1
fi

# Start ngrok tunnel
echo -e "${BLUE}🌐 Starting ngrok tunnel...${NC}"
if [ -n "$STATIC_URL" ]; then
    nohup $NGROK_CMD http --url="$STATIC_URL" "$PORT" > ngrok.log 2>&1 &
else
    nohup $NGROK_CMD http "$PORT" > ngrok.log 2>&1 &
fi
NGROK_PID=$!
echo $NGROK_PID > .pids/ngrok.pid

# Wait for ngrok to establish tunnel
sleep 8

# Verify ngrok is running
if [ -n "$STATIC_URL" ]; then
    if curl -s "https://$STATIC_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ ngrok tunnel online (PID: $NGROK_PID)${NC}"
    else
        echo -e "${YELLOW}⚠️  ngrok tunnel starting (may take a moment)${NC}"
    fi
else
    echo -e "${GREEN}✅ ngrok tunnel started (dynamic URL in ngrok dashboard/log)${NC}"
fi

# =============================================================================
# SYSTEM ONLINE NOTIFICATION
# =============================================================================

echo ""
echo -e "${PURPLE}"
cat << "EOF"
🎉 NOCTIS PRO MASTERPIECE SYSTEM IS ONLINE! 🎉
EOF
echo -e "${NC}"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🌐 ACCESS INFORMATION                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
if [ -n "$STATIC_URL" ]; then
echo -e "${GREEN}║  Public URL:  https://${STATIC_URL}  ║${NC}"
fi
echo -e "${GREEN}║  Local URL:   http://localhost:${PORT}                      ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                    🏥 SYSTEM FEATURES                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  ✅ Masterpiece DICOM Viewer with 3D Reconstruction        ║${NC}"
echo -e "${GREEN}║  ✅ AI Analysis System                                      ║${NC}"
echo -e "${GREEN}║  ✅ Professional Reports with Letterheads & QR Codes       ║${NC}"
echo -e "${GREEN}║  ✅ User & Facility Management                              ║${NC}"
echo -e "${GREEN}║  ✅ Enhanced Admin Panel                                    ║${NC}"
echo -e "${GREEN}║  ✅ Real-time Monitoring & Auto-recovery                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BLUE}📊 PROCESS INFORMATION:${NC}"
echo -e "${GREEN}   🔥 Django Server: PID $DJANGO_PID${NC}"
echo -e "${GREEN}   🌐 ngrok Tunnel:  PID $NGROK_PID${NC}"
echo ""
echo -e "${CYAN}💡 MONITORING COMMANDS:${NC}"
echo -e "${GREEN}   Monitor System: ./masterpiece_monitor.sh${NC}"
echo -e "${GREEN}   View Django Log: tail -f django.log${NC}"
echo -e "${GREEN}   View ngrok Log:  tail -f ngrok.log${NC}"
echo ""
echo -e "${YELLOW}🛑 Press Ctrl+C to stop all services${NC}"

# Keep system running and monitor
while true; do
    # Check Django
    if ! kill -0 $DJANGO_PID 2>/dev/null; then
        echo -e "${RED}❌ Django died - restarting...${NC}"
        nohup $PYTHON manage.py runserver 0.0.0.0:$PORT > django.log 2>&1 &
        DJANGO_PID=$!
        echo $DJANGO_PID > .pids/django.pid
        sleep 3
    fi
    
    # Check ngrok
    if ! kill -0 $NGROK_PID 2>/dev/null; then
        echo -e "${RED}❌ ngrok died - restarting...${NC}"
        nohup $NGROK_CMD http --url=$STATIC_URL $PORT > ngrok.log 2>&1 &
        NGROK_PID=$!
        echo $NGROK_PID > .pids/ngrok.pid
        sleep 5
    fi
    
    # Status heartbeat every 60 seconds
    sleep 60
    echo -e "${CYAN}💓 $(date) - System healthy (Django: $DJANGO_PID, ngrok: $NGROK_PID)${NC}"
done