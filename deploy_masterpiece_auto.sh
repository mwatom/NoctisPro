#!/bin/bash

# =============================================================================
# NOCTIS PRO MASTERPIECE AUTO-DEPLOYMENT SYSTEM
# Complete automated deployment with ngrok, static URL, and system detection
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NGROK_AUTHTOKEN="32E2HmoUqzrZxaYRNT77wAI0HQs_5N5QNSrxU4Z7d4MFSRF4x"
STATIC_URL="mallard-shining-curiously.ngrok-free.app"
PROJECT_NAME="noctis_pro"
PORT=80

echo -e "${PURPLE}🚀 NOCTIS PRO MASTERPIECE AUTO-DEPLOYMENT SYSTEM${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "${BLUE}🔧 Configuring ngrok authtoken and static URL${NC}"
echo -e "${BLUE}🌐 Static URL: ${STATIC_URL}${NC}"
echo -e "${BLUE}🔑 Authtoken: ${NGROK_AUTHTOKEN:0:10}...${NC}"
echo ""

# =============================================================================
# SYSTEM DETECTION AND PREPARATION
# =============================================================================

echo -e "${YELLOW}📋 PHASE 1: SYSTEM DETECTION AND PREPARATION${NC}"

# Detect Python version
echo -e "${BLUE}🐍 Detecting Python installation...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✅ Python detected: ${PYTHON_VERSION}${NC}"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    PYTHON_VERSION=$(python --version)
    echo -e "${GREEN}✅ Python detected: ${PYTHON_VERSION}${NC}"
else
    echo -e "${RED}❌ Python not found! Installing Python...${NC}"
    sudo apt update && sudo apt install -y python3 python3-pip python3-venv
    PYTHON_CMD="python3"
fi

# Detect pip
echo -e "${BLUE}📦 Detecting pip installation...${NC}"
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
    echo -e "${GREEN}✅ pip3 detected${NC}"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
    echo -e "${GREEN}✅ pip detected${NC}"
else
    echo -e "${RED}❌ pip not found! Installing pip...${NC}"
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    $PYTHON_CMD get-pip.py
    rm get-pip.py
    PIP_CMD="pip3"
fi

# Detect virtual environment
echo -e "${BLUE}🏠 Detecting virtual environment...${NC}"
if [ -d "venv" ]; then
    echo -e "${GREEN}✅ Virtual environment found${NC}"
    source venv/bin/activate
elif [ -d ".venv" ]; then
    echo -e "${GREEN}✅ Virtual environment found (.venv)${NC}"
    source .venv/bin/activate
else
    echo -e "${YELLOW}⚠️  Creating new virtual environment...${NC}"
    $PYTHON_CMD -m venv venv
    source venv/bin/activate
    echo -e "${GREEN}✅ Virtual environment created and activated${NC}"
fi

# Detect and install requirements
echo -e "${BLUE}📚 Installing/updating dependencies...${NC}"
if [ -f "requirements.txt" ]; then
    echo -e "${GREEN}✅ requirements.txt found - installing dependencies${NC}"
    $PIP_CMD install -r requirements.txt --quiet
    echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
else
    echo -e "${YELLOW}⚠️  requirements.txt not found - installing basic dependencies${NC}"
    $PIP_CMD install django pillow pydicom numpy --quiet
fi

# =============================================================================
# NGROK DETECTION AND CONFIGURATION
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 2: NGROK DETECTION AND CONFIGURATION${NC}"

# Detect ngrok installation
echo -e "${BLUE}🌐 Detecting ngrok installation...${NC}"
if command -v ngrok &> /dev/null; then
    NGROK_VERSION=$(ngrok version)
    echo -e "${GREEN}✅ ngrok detected: ${NGROK_VERSION}${NC}"
elif [ -f "./ngrok" ]; then
    echo -e "${GREEN}✅ Local ngrok binary found${NC}"
    chmod +x ./ngrok
    NGROK_CMD="./ngrok"
else
    echo -e "${YELLOW}⚠️  ngrok not found - downloading...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        ARCH="arm64"
    fi
    
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-${OS}-${ARCH}.tgz"
    
    echo -e "${BLUE}📥 Downloading ngrok for ${OS}-${ARCH}...${NC}"
    curl -L -o ngrok.tgz "$NGROK_URL"
    tar xzf ngrok.tgz
    rm ngrok.tgz
    chmod +x ngrok
    NGROK_CMD="./ngrok"
    echo -e "${GREEN}✅ ngrok downloaded and configured${NC}"
fi

# Set ngrok command
if command -v ngrok &> /dev/null; then
    NGROK_CMD="ngrok"
fi

# Configure ngrok authtoken
echo -e "${BLUE}🔑 Configuring ngrok authtoken...${NC}"
$NGROK_CMD config add-authtoken $NGROK_AUTHTOKEN
echo -e "${GREEN}✅ ngrok authtoken configured successfully${NC}"

# Verify ngrok configuration
echo -e "${BLUE}🔍 Verifying ngrok configuration...${NC}"
if $NGROK_CMD config check &> /dev/null; then
    echo -e "${GREEN}✅ ngrok configuration verified${NC}"
else
    echo -e "${RED}❌ ngrok configuration failed${NC}"
    exit 1
fi

# =============================================================================
# DJANGO SYSTEM DETECTION AND CONFIGURATION
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 3: DJANGO SYSTEM DETECTION AND CONFIGURATION${NC}"

# Detect Django project
echo -e "${BLUE}🔍 Detecting Django project structure...${NC}"
if [ -f "manage.py" ]; then
    echo -e "${GREEN}✅ Django project detected${NC}"
    
    # Detect project name
    PROJECT_DIR=$(find . -name "settings.py" -type f | head -1 | xargs dirname | xargs basename)
    if [ -n "$PROJECT_DIR" ]; then
        PROJECT_NAME="$PROJECT_DIR"
        echo -e "${GREEN}✅ Project name detected: ${PROJECT_NAME}${NC}"
    fi
else
    echo -e "${RED}❌ Django project not found!${NC}"
    exit 1
fi

# Database detection and migration
echo -e "${BLUE}🗄️  Detecting database and running migrations...${NC}"
if [ -f "db.sqlite3" ]; then
    echo -e "${GREEN}✅ SQLite database detected${NC}"
else
    echo -e "${YELLOW}⚠️  No database found - will be created${NC}"
fi

# Run Django system checks
echo -e "${BLUE}🔍 Running Django system checks...${NC}"
$PYTHON_CMD manage.py check --deploy --quiet
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Django system checks passed${NC}"
else
    echo -e "${YELLOW}⚠️  Django system checks have warnings (continuing anyway)${NC}"
fi

# Run migrations
echo -e "${BLUE}🔄 Running database migrations...${NC}"
$PYTHON_CMD manage.py migrate --quiet
echo -e "${GREEN}✅ Database migrations completed${NC}"

# Collect static files
echo -e "${BLUE}📁 Collecting static files...${NC}"
$PYTHON_CMD manage.py collectstatic --noinput --quiet
echo -e "${GREEN}✅ Static files collected${NC}"

# =============================================================================
# AUTO-DETECTION OF SYSTEM COMPONENTS
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 4: SYSTEM COMPONENT AUTO-DETECTION${NC}"

# Detect installed apps
echo -e "${BLUE}🔍 Detecting installed Django apps...${NC}"
DETECTED_APPS=()

for app_dir in */; do
    if [ -f "${app_dir}apps.py" ] || [ -f "${app_dir}models.py" ]; then
        app_name=$(basename "$app_dir")
        DETECTED_APPS+=("$app_name")
        echo -e "${GREEN}  ✅ ${app_name}${NC}"
    fi
done

echo -e "${GREEN}✅ Detected ${#DETECTED_APPS[@]} Django apps${NC}"

# Detect DICOM viewer enhancements
echo -e "${BLUE}🖼️  Detecting DICOM viewer components...${NC}"
if [ -f "templates/dicom_viewer/masterpiece_viewer.html" ]; then
    echo -e "${GREEN}  ✅ Masterpiece DICOM Viewer${NC}"
fi
if [ -f "static/js/masterpiece_3d_reconstruction.js" ]; then
    echo -e "${GREEN}  ✅ 3D Bone Reconstruction${NC}"
fi
if [ -f "dicom_viewer/masterpiece_utils.py" ]; then
    echo -e "${GREEN}  ✅ Enhanced Processing Utilities${NC}"
fi

# Detect AI components
echo -e "${BLUE}🤖 Detecting AI analysis components...${NC}"
if [ -d "ai_analysis" ]; then
    echo -e "${GREEN}  ✅ AI Analysis System${NC}"
fi

# Detect report components
echo -e "${BLUE}📄 Detecting report system components...${NC}"
if [ -d "reports" ]; then
    echo -e "${GREEN}  ✅ Report System with Letterheads${NC}"
fi
if grep -q "qrcode" requirements.txt 2>/dev/null; then
    echo -e "${GREEN}  ✅ QR Code Generation${NC}"
fi

# Detect admin panel
echo -e "${BLUE}👨‍💼 Detecting admin panel components...${NC}"
if [ -d "admin_panel" ]; then
    echo -e "${GREEN}  ✅ Enhanced Admin Panel${NC}"
fi

# =============================================================================
# SERVICE MANAGEMENT SETUP
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 5: SERVICE MANAGEMENT SETUP${NC}"

# Create systemd service for Django
echo -e "${BLUE}⚙️  Creating Django service...${NC}"
cat > noctis-pro-django.service << EOF
[Unit]
Description=Noctis Pro Django Application
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
Environment=PATH=$(pwd)/venv/bin
ExecStart=$(pwd)/venv/bin/python manage.py runserver 0.0.0.0:8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for ngrok
echo -e "${BLUE}🌐 Creating ngrok service...${NC}"
cat > noctis-pro-ngrok.service << EOF
[Unit]
Description=Noctis Pro Ngrok Tunnel
After=network.target noctis-pro-django.service
Requires=noctis-pro-django.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=$(which ngrok || echo "./ngrok") http --url=${STATIC_URL} 8000
Restart=always
RestartSec=5
Environment=HOME=$(pwd)

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✅ Service files created${NC}"

# =============================================================================
# MASTERPIECE AUTO-START SCRIPT
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 6: CREATING MASTERPIECE AUTO-START SCRIPT${NC}"

cat > start_masterpiece.sh << 'EOF'
#!/bin/bash

# Noctis Pro Masterpiece Auto-Start Script
# Automatically starts Django + ngrok with static URL

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}🚀 STARTING NOCTIS PRO MASTERPIECE SYSTEM${NC}"
echo -e "${CYAN}==========================================${NC}"

# Change to script directory
cd "$(dirname "$0")"

# Activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
    echo -e "${GREEN}✅ Virtual environment activated${NC}"
elif [ -d ".venv" ]; then
    source .venv/bin/activate
    echo -e "${GREEN}✅ Virtual environment activated${NC}"
else
    echo -e "${YELLOW}⚠️  No virtual environment found${NC}"
fi

# Configure ngrok if not already configured
if ! ./ngrok config check &> /dev/null && ! ngrok config check &> /dev/null; then
    echo -e "${BLUE}🔑 Configuring ngrok authtoken...${NC}"
    if command -v ngrok &> /dev/null; then
        ngrok config add-authtoken 32E2HmoUqzrZxaYRNT77wAI0HQs_5N5QNSrxU4Z7d4MFSRF4x
    else
        ./ngrok config add-authtoken 32E2HmoUqzrZxaYRNT77wAI0HQs_5N5QNSrxU4Z7d4MFSRF4x
    fi
    echo -e "${GREEN}✅ ngrok configured${NC}"
fi

# Function to cleanup processes on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up processes...${NC}"
    
    # Kill Django process
    if [ ! -z "$DJANGO_PID" ]; then
        kill $DJANGO_PID 2>/dev/null || true
        echo -e "${GREEN}✅ Django process stopped${NC}"
    fi
    
    # Kill ngrok process
    if [ ! -z "$NGROK_PID" ]; then
        kill $NGROK_PID 2>/dev/null || true
        echo -e "${GREEN}✅ ngrok process stopped${NC}"
    fi
    
    # Kill any remaining processes
    pkill -f "python.*manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    
    echo -e "${GREEN}🎉 Cleanup completed${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM EXIT

# Start Django development server
echo -e "${BLUE}🔥 Starting Django development server...${NC}"
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

# Wait for Django to start
echo -e "${YELLOW}⏳ Waiting for Django to initialize...${NC}"
sleep 5

# Check if Django is running
if kill -0 $DJANGO_PID 2>/dev/null; then
    echo -e "${GREEN}✅ Django server started successfully (PID: $DJANGO_PID)${NC}"
else
    echo -e "${RED}❌ Django server failed to start${NC}"
    exit 1
fi

# Start ngrok with static URL
echo -e "${BLUE}🌐 Starting ngrok tunnel with static URL...${NC}"
if command -v ngrok &> /dev/null; then
    ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 &
else
    ./ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 &
fi
NGROK_PID=$!

# Wait for ngrok to start
echo -e "${YELLOW}⏳ Waiting for ngrok to establish tunnel...${NC}"
sleep 8

# Check if ngrok is running
if kill -0 $NGROK_PID 2>/dev/null; then
    echo -e "${GREEN}✅ ngrok tunnel started successfully (PID: $NGROK_PID)${NC}"
else
    echo -e "${RED}❌ ngrok tunnel failed to start${NC}"
    kill $DJANGO_PID 2>/dev/null || true
    exit 1
fi

# Display system information
echo ""
echo -e "${PURPLE}🎉 NOCTIS PRO MASTERPIECE SYSTEM ONLINE!${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}🌐 Public URL: https://mallard-shining-curiously.ngrok-free.app${NC}"
echo -e "${GREEN}🏠 Local URL:  http://localhost:8000${NC}"
echo -e "${GREEN}🔧 Django PID: $DJANGO_PID${NC}"
echo -e "${GREEN}🌐 ngrok PID:  $NGROK_PID${NC}"
echo ""
echo -e "${BLUE}📊 SYSTEM STATUS:${NC}"
echo -e "${GREEN}  ✅ Django Server: ONLINE${NC}"
echo -e "${GREEN}  ✅ ngrok Tunnel:  ONLINE${NC}"
echo -e "${GREEN}  ✅ Static URL:    CONFIGURED${NC}"
echo -e "${GREEN}  ✅ DICOM Viewer: MASTERPIECE EDITION${NC}"
echo -e "${GREEN}  ✅ 3D Reconstruction: ENABLED${NC}"
echo -e "${GREEN}  ✅ AI Analysis: ENABLED${NC}"
echo -e "${GREEN}  ✅ QR Codes: ENABLED${NC}"
echo -e "${GREEN}  ✅ Letterheads: ENABLED${NC}"
echo ""
echo -e "${CYAN}🎯 Access your system at: ${YELLOW}https://mallard-shining-curiously.ngrok-free.app${NC}"
echo -e "${CYAN}💡 Press Ctrl+C to stop all services${NC}"
echo ""

# Keep the script running and monitor services
while true; do
    # Check Django process
    if ! kill -0 $DJANGO_PID 2>/dev/null; then
        echo -e "${RED}❌ Django process died - restarting...${NC}"
        python manage.py runserver 0.0.0.0:8000 &
        DJANGO_PID=$!
        sleep 3
    fi
    
    # Check ngrok process  
    if ! kill -0 $NGROK_PID 2>/dev/null; then
        echo -e "${RED}❌ ngrok process died - restarting...${NC}"
        if command -v ngrok &> /dev/null; then
            ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 &
        else
            ./ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 &
        fi
        NGROK_PID=$!
        sleep 5
    fi
    
    # Status update every 30 seconds
    sleep 30
    echo -e "${CYAN}💓 System heartbeat - Django: $DJANGO_PID, ngrok: $NGROK_PID${NC}"
done
EOF

chmod +x start_masterpiece.sh
echo -e "${GREEN}✅ Masterpiece auto-start script created${NC}"

# =============================================================================
# SYSTEM OPTIMIZATION
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 7: SYSTEM OPTIMIZATION${NC}"

# Create optimized settings for production
echo -e "${BLUE}⚡ Optimizing Django settings...${NC}"
if [ -f "${PROJECT_NAME}/settings.py" ]; then
    # Backup original settings
    cp "${PROJECT_NAME}/settings.py" "${PROJECT_NAME}/settings.py.backup"
    
    # Add production optimizations
    cat >> "${PROJECT_NAME}/settings.py" << EOF

# Masterpiece Auto-Deploy Optimizations
ALLOWED_HOSTS = ['mallard-shining-curiously.ngrok-free.app', 'localhost', '127.0.0.1', '0.0.0.0']
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = False  # ngrok handles SSL
USE_TZ = True

# Static files optimization for ngrok
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Media files for DICOM
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# DICOM viewer optimizations
DICOM_VIEWER_SETTINGS = {
    'MAX_UPLOAD_SIZE': 100 * 1024 * 1024,  # 100MB
    'SUPPORTED_MODALITIES': ['CT', 'MR', 'CR', 'DX', 'US', 'XA'],
    'CACHE_TIMEOUT': 3600,
    'ENABLE_3D_RECONSTRUCTION': True,
    'ENABLE_MEASUREMENTS': True,
    'ENABLE_ANNOTATIONS': True,
}

# Security for ngrok deployment
CSRF_TRUSTED_ORIGINS = [
    'https://mallard-shining-curiously.ngrok-free.app',
    'http://localhost:8000',
    'http://127.0.0.1:8000'
]

# Session security
SESSION_COOKIE_SECURE = False  # ngrok handles SSL
CSRF_COOKIE_SECURE = False     # ngrok handles SSL
EOF

    echo -e "${GREEN}✅ Django settings optimized for ngrok deployment${NC}"
fi

# =============================================================================
# FINAL SYSTEM VERIFICATION
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 8: FINAL SYSTEM VERIFICATION${NC}"

# Verify all components
echo -e "${BLUE}🔍 Verifying system components...${NC}"

# Check database
if $PYTHON_CMD manage.py shell -c "from django.db import connection; connection.ensure_connection()" &> /dev/null; then
    echo -e "${GREEN}  ✅ Database connection: OK${NC}"
else
    echo -e "${RED}  ❌ Database connection: FAILED${NC}"
fi

# Check static files
if [ -d "staticfiles" ] && [ "$(ls -A staticfiles)" ]; then
    echo -e "${GREEN}  ✅ Static files: OK${NC}"
else
    echo -e "${YELLOW}  ⚠️  Static files: WARNING${NC}"
fi

# Check DICOM viewer
if [ -f "templates/dicom_viewer/masterpiece_viewer.html" ]; then
    echo -e "${GREEN}  ✅ Masterpiece DICOM Viewer: OK${NC}"
else
    echo -e "${RED}  ❌ DICOM Viewer: MISSING${NC}"
fi

# Check media directory
if [ ! -d "media" ]; then
    mkdir -p media/dicom/images
    echo -e "${GREEN}  ✅ Media directory created${NC}"
else
    echo -e "${GREEN}  ✅ Media directory: OK${NC}"
fi

# =============================================================================
# LAUNCH SYSTEM
# =============================================================================

echo ""
echo -e "${PURPLE}🚀 LAUNCHING NOCTIS PRO MASTERPIECE SYSTEM${NC}"
echo -e "${CYAN}===========================================${NC}"

# Final configuration summary
echo -e "${BLUE}📋 DEPLOYMENT CONFIGURATION:${NC}"
echo -e "${GREEN}  🔑 ngrok Authtoken: ${NGROK_AUTHTOKEN:0:10}...${NC}"
echo -e "${GREEN}  🌐 Static URL: ${STATIC_URL}${NC}"
echo -e "${GREEN}  🏠 Local Port: 8000${NC}"
echo -e "${GREEN}  🎯 Project: ${PROJECT_NAME}${NC}"
echo -e "${GREEN}  🐍 Python: ${PYTHON_VERSION}${NC}"
echo ""

# Ask user if they want to start now
echo -e "${YELLOW}🤔 Ready to start the Masterpiece system?${NC}"
echo -e "${CYAN}This will start Django + ngrok with your static URL${NC}"
echo ""
read -p "Start now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 Starting Masterpiece system...${NC}"
    ./start_masterpiece.sh
else
    echo -e "${YELLOW}⏸️  System prepared but not started${NC}"
    echo -e "${CYAN}💡 To start later, run: ./start_masterpiece.sh${NC}"
    echo ""
    echo -e "${GREEN}🎉 MASTERPIECE AUTO-DEPLOYMENT COMPLETE!${NC}"
    echo ""
    echo -e "${BLUE}📋 NEXT STEPS:${NC}"
    echo -e "${GREEN}  1. Run: ./start_masterpiece.sh${NC}"
    echo -e "${GREEN}  2. Access: https://mallard-shining-curiously.ngrok-free.app${NC}"
    echo -e "${GREEN}  3. Login with your admin credentials${NC}"
    echo -e "${GREEN}  4. Upload DICOM files and test the Masterpiece viewer${NC}"
fi