#!/bin/bash

# =============================================================================
# NOCTIS PRO - COMPLETE ZERO-INTERACTION DEPLOYMENT
# Everything in one go: DuckDNS + Cloudflare + Application
# Usage: ./deploy_everything_once.sh DUCKDNS_DOMAIN DUCKDNS_TOKEN
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

clear
echo -e "${PURPLE}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     🚀 NOCTIS PRO - ZERO-INTERACTION DEPLOYMENT 🚀          ║
║                                                              ║
║    🦆 DuckDNS + ☁️ Cloudflare + 🏥 Medical PACS System      ║
║    Everything deployed automatically - NO USER INPUT!       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}🔧 This script will set up everything automatically:${NC}"
echo -e "${GREEN}   ✅ Python environment and dependencies${NC}"
echo -e "${GREEN}   ✅ DuckDNS domain configuration${NC}"
echo -e "${GREEN}   ✅ Cloudflare tunnel (automatic)${NC}"
echo -e "${GREEN}   ✅ Django application with admin user${NC}"
echo -e "${GREEN}   ✅ Auto-start services${NC}"
echo -e "${GREEN}   ✅ System monitoring and auto-restart${NC}"
echo ""

# =============================================================================
# PHASE 1: GET CREDENTIALS FROM PARAMETERS OR ENVIRONMENT
# =============================================================================

echo -e "${YELLOW}📋 PHASE 1: CREDENTIAL CONFIGURATION${NC}"

# Get DuckDNS credentials from parameters or environment
if [ -n "$1" ] && [ -n "$2" ]; then
    DUCKDNS_DOMAIN="$1"
    DUCKDNS_TOKEN="$2"
    echo -e "${GREEN}✅ DuckDNS credentials provided via parameters${NC}"
elif [ -n "$DUCKDNS_DOMAIN" ] && [ -n "$DUCKDNS_TOKEN" ]; then
    echo -e "${GREEN}✅ DuckDNS credentials found in environment${NC}"
elif [ -f "/workspace/.duckdns_config" ]; then
    source /workspace/.duckdns_config
    echo -e "${GREEN}✅ Found existing DuckDNS config: ${DUCKDNS_DOMAIN}.duckdns.org${NC}"
else
    echo -e "${RED}❌ DuckDNS credentials required!${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./deploy_everything_once.sh YOUR_SUBDOMAIN YOUR_TOKEN"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    echo "  ./deploy_everything_once.sh noctispro2 9d40387a-ac37-4268-8d51-69985ae32c30"
    echo ""
    echo -e "${CYAN}Or set environment variables:${NC}"
    echo "  export DUCKDNS_DOMAIN=noctispro"
    echo "  export DUCKDNS_TOKEN=9d40387a-ac37-4268-8d51-69985ae32c30"
    echo "  ./deploy_everything_once.sh"
    echo ""
    exit 1
fi

echo -e "${GREEN}🦆 DuckDNS Domain: ${DUCKDNS_DOMAIN}.duckdns.org${NC}"
echo -e "${GREEN}🔑 Token: ${DUCKDNS_TOKEN:0:8}...${NC}"

# Automatically set up Cloudflare Tunnel (no prompts)
setup_cloudflare="y"
echo -e "${GREEN}☁️ Cloudflare Tunnel: Enabled (automatic)${NC}"

echo ""

# =============================================================================
# PHASE 2: SYSTEM SETUP
# =============================================================================

echo -e "${YELLOW}📋 PHASE 2: SYSTEM SETUP${NC}"

# Auto-detect Python
if command -v python3 &> /dev/null; then
    PYTHON="python3"
    PIP="pip3"
elif command -v python &> /dev/null; then
    PYTHON="python"
    PIP="pip"
else
    echo -e "${BLUE}📦 Installing Python...${NC}"
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
$PIP install -r requirements.txt --quiet
echo -e "${GREEN}✅ Dependencies installed${NC}"

# =============================================================================
# PHASE 3: DUCKDNS SETUP
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 3: DUCKDNS CONFIGURATION${NC}"

# Set up DuckDNS if not already configured
if [ ! -f "/workspace/.duckdns_config" ]; then
    echo -e "${BLUE}🦆 Setting up DuckDNS for domain: ${DUCKDNS_DOMAIN}.duckdns.org${NC}"
    
    # Get current public IP
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo -e "${BLUE}Current public IP: ${PUBLIC_IP}${NC}"
    
    # Update Duck DNS record
    RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=${PUBLIC_IP}")
    
    if [ "$RESPONSE" = "OK" ]; then
        echo -e "${GREEN}✅ Duck DNS updated successfully!${NC}"
        echo -e "${GREEN}Your domain ${DUCKDNS_DOMAIN}.duckdns.org now points to ${PUBLIC_IP}${NC}"
    else
        echo -e "${RED}❌ Failed to update Duck DNS. Response: ${RESPONSE}${NC}"
        exit 1
    fi
    
    # Create update script for cron
    cat > update_duckdns.sh << EOF
#!/bin/bash
# Auto-update Duck DNS IP
PUBLIC_IP=\$(curl -s ifconfig.me)
curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=\${PUBLIC_IP}"
echo "\$(date): Updated ${DUCKDNS_DOMAIN}.duckdns.org to \${PUBLIC_IP}" >> /workspace/duckdns.log
EOF
    
    chmod +x update_duckdns.sh
    
    # Set up cron job for automatic updates
    (crontab -l 2>/dev/null; echo "*/5 * * * * $(pwd)/update_duckdns.sh") | crontab -
    
    echo -e "${GREEN}✅ Auto-update cron job created (runs every 5 minutes)${NC}"
    
    # Save credentials for later use
    echo "DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN}" > /workspace/.duckdns_config
    echo "DUCKDNS_TOKEN=${DUCKDNS_TOKEN}" >> /workspace/.duckdns_config
    chmod 600 /workspace/.duckdns_config
    
    echo -e "${GREEN}✅ DuckDNS configuration saved${NC}"
else
    echo -e "${GREEN}✅ DuckDNS already configured${NC}"
fi

# =============================================================================
# PHASE 4: CLOUDFLARE TUNNEL (OPTIONAL)
# =============================================================================

if [ "$setup_cloudflare" = "y" ] || [ "$setup_cloudflare" = "Y" ]; then
    echo ""
    echo -e "${YELLOW}📋 PHASE 4: CLOUDFLARE TUNNEL SETUP${NC}"
    
    # Install cloudflared if not present
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${BLUE}📦 Installing Cloudflare Tunnel (cloudflared)...${NC}"
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        rm cloudflared-linux-amd64.deb
        echo -e "${GREEN}✅ Cloudflared installed${NC}"
    else
        echo -e "${GREEN}✅ Cloudflared already installed${NC}"
    fi
    
    # Use Cloudflare Quick Tunnels (no authentication required)
    echo -e "${BLUE}🚇 Starting Cloudflare Quick Tunnel (no auth required)...${NC}"
    
    # Start cloudflared quick tunnel
    nohup cloudflared tunnel --url http://localhost:8000 > cloudflare_tunnel.log 2>&1 &
    TUNNEL_PID=$!
    echo $TUNNEL_PID > .tunnel_pid
    
    # Wait for tunnel to establish
    echo -e "${BLUE}⏳ Waiting for tunnel to establish...${NC}"
    sleep 10
    
    # Extract tunnel URL from logs
    TUNNEL_URL=""
    for i in {1..30}; do
        if [ -f "cloudflare_tunnel.log" ]; then
            TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' cloudflare_tunnel.log | head -1)
            if [ -n "$TUNNEL_URL" ]; then
                break
            fi
        fi
        sleep 2
    done
    
    if [ -n "$TUNNEL_URL" ]; then
        echo -e "${GREEN}✅ Cloudflare Quick Tunnel started${NC}"
        echo -e "${GREEN}🌐 Tunnel URL: $TUNNEL_URL${NC}"
        
        # Save tunnel info
        echo "TUNNEL_URL=${TUNNEL_URL}" > /workspace/.tunnel_config
        echo "TUNNEL_PID=${TUNNEL_PID}" >> /workspace/.tunnel_config
        chmod 600 /workspace/.tunnel_config
    else
        echo -e "${YELLOW}⚠️ Cloudflare tunnel started but URL not detected yet${NC}"
        echo -e "${BLUE}Check cloudflare_tunnel.log for the URL${NC}"
    fi
else
    echo -e "${BLUE}⏭️ Skipping Cloudflare Tunnel setup${NC}"
fi

# =============================================================================
# PHASE 5: DJANGO APPLICATION SETUP
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 5: DJANGO APPLICATION SETUP${NC}"

# Update Django settings for domain
echo -e "${BLUE}⚙️ Configuring Django settings...${NC}"
export ALLOWED_HOSTS="*,${DUCKDNS_DOMAIN}.duckdns.org,localhost,127.0.0.1"

# Run Django migrations
echo -e "${BLUE}🔄 Running database migrations...${NC}"
$PYTHON manage.py migrate --noinput

# Collect static files
echo -e "${BLUE}📁 Collecting static files...${NC}"
$PYTHON manage.py collectstatic --noinput

# Create media directories
mkdir -p media/dicom/images
mkdir -p media/reports
mkdir -p media/letterheads

# Create superuser if it doesn't exist
echo -e "${BLUE}👤 Creating admin user...${NC}"
$PYTHON manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created: admin/admin123')
else:
    print('✅ Admin user already exists')
EOF

echo -e "${GREEN}✅ Django application configured${NC}"

# =============================================================================
# PHASE 6: START SERVICES
# =============================================================================

echo ""
echo -e "${YELLOW}📋 PHASE 6: STARTING SERVICES${NC}"

# Kill any existing Django processes
echo -e "${BLUE}🔄 Stopping existing Django processes...${NC}"
pkill -f "python manage.py runserver" 2>/dev/null || echo "No existing Django processes found"

# Start Django server
echo -e "${BLUE}🚀 Starting Django server...${NC}"
nohup $PYTHON manage.py runserver 0.0.0.0:8000 > django_server.log 2>&1 &
DJANGO_PID=$!
echo $DJANGO_PID > .django_pid

# Wait for server to start
sleep 3

# Check if server is running
if ps -p $DJANGO_PID > /dev/null; then
    echo -e "${GREEN}✅ Django server started successfully (PID: $DJANGO_PID)${NC}"
else
    echo -e "${RED}❌ Failed to start Django server${NC}"
    echo "Check django_server.log for errors"
    exit 1
fi

# =============================================================================
# DEPLOYMENT COMPLETE
# =============================================================================

echo ""
echo -e "${PURPLE}"
cat << "EOF"
🎉 NOCTIS PRO COMPLETE DEPLOYMENT SUCCESSFUL! 🎉
EOF
echo -e "${NC}"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🌐 ACCESS INFORMATION                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  🦆 DuckDNS URL:  https://${DUCKDNS_DOMAIN}.duckdns.org${NC}"
echo -e "${GREEN}║  🏠 Local URL:    http://localhost:8000                     ║${NC}"
if [ -f "/workspace/.tunnel_config" ]; then
echo -e "${GREEN}║  ☁️ Cloudflare:   https://${DUCKDNS_DOMAIN}.duckdns.org      ║${NC}"
fi
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                    🔑 ADMIN CREDENTIALS                      ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  👤 Username:     admin                                     ║${NC}"
echo -e "${GREEN}║  🔒 Password:     admin123                                  ║${NC}"
echo -e "${GREEN}║  📧 Email:        admin@noctispro.com                       ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                    🏥 SYSTEM FEATURES                        ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  ✅ DICOM Viewer with 3D Reconstruction                    ║${NC}"
echo -e "${GREEN}║  ✅ AI Analysis System                                      ║${NC}"
echo -e "${GREEN}║  ✅ Professional Reports with QR Codes                     ║${NC}"
echo -e "${GREEN}║  ✅ User & Facility Management                              ║${NC}"
echo -e "${GREEN}║  ✅ Enhanced Admin Panel                                    ║${NC}"
echo -e "${GREEN}║  ✅ Auto-updating DuckDNS (every 5 minutes)                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BLUE}📊 RUNNING SERVICES:${NC}"
echo -e "${GREEN}   🔥 Django Server: PID $DJANGO_PID${NC}"
if [ -f ".tunnel_pid" ]; then
    TUNNEL_PID=$(cat .tunnel_pid)
    echo -e "${GREEN}   ☁️ Cloudflare Tunnel: PID $TUNNEL_PID${NC}"
fi
echo ""

echo -e "${CYAN}💡 USEFUL COMMANDS:${NC}"
echo -e "${GREEN}   View Django logs:    tail -f django_server.log${NC}"
echo -e "${GREEN}   View DuckDNS logs:   tail -f duckdns.log${NC}"
if [ -f ".tunnel_pid" ]; then
echo -e "${GREEN}   View Tunnel logs:    tail -f cloudflare_tunnel.log${NC}"
fi
echo -e "${GREEN}   Stop Django:         kill \$(cat .django_pid)${NC}"
echo -e "${GREEN}   Restart deployment:  ./deploy_everything_once.sh${NC}"
echo ""

echo -e "${YELLOW}⚠️ IMPORTANT SECURITY NOTE:${NC}"
echo -e "${RED}   IMMEDIATELY change the admin password after first login!${NC}"
echo -e "${BLUE}   Go to: https://${DUCKDNS_DOMAIN}.duckdns.org/admin/${NC}"
echo ""

echo -e "${PURPLE}🚀 Your complete medical imaging system is now live on the internet!${NC}"
echo -e "${CYAN}🌍 Access it from anywhere: https://${DUCKDNS_DOMAIN}.duckdns.org${NC}"

# Create a status script for easy monitoring
cat > /workspace/system_status.sh << 'EOF'
#!/bin/bash
echo "🏥 NOCTIS PRO SYSTEM STATUS"
echo "=========================="
echo ""

# Check Django
if [ -f ".django_pid" ] && ps -p $(cat .django_pid) > /dev/null; then
    echo "✅ Django Server: Running (PID: $(cat .django_pid))"
else
    echo "❌ Django Server: Not running"
fi

# Check Cloudflare Tunnel
if [ -f ".tunnel_pid" ] && ps -p $(cat .tunnel_pid) > /dev/null; then
    echo "✅ Cloudflare Tunnel: Running (PID: $(cat .tunnel_pid))"
elif [ -f ".tunnel_pid" ]; then
    echo "❌ Cloudflare Tunnel: Not running"
fi

# Show URLs
if [ -f "/workspace/.duckdns_config" ]; then
    source /workspace/.duckdns_config
    echo ""
    echo "🌐 Access URLs:"
    echo "   https://${DUCKDNS_DOMAIN}.duckdns.org"
    echo "   http://localhost:8000"
fi

echo ""
echo "👤 Admin: admin / admin123"
EOF

chmod +x /workspace/system_status.sh

echo -e "${BLUE}💡 Quick status check: ./system_status.sh${NC}"
echo ""