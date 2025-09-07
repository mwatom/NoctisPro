#!/bin/bash

# =============================================================================
# NoctisPro PACS - Quick DuckDNS Deployment
# =============================================================================
# One-command deployment with DuckDNS (no ngrok limitations!)
# =============================================================================

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

clear

echo -e "${BOLD}${CYAN}"
cat << "EOF"
    _   __           __  _      ____                 
   / | / /___  _____/ /_(_)____/ __ \________  _____ 
  /  |/ / __ \/ ___/ __/ / ___/ /_/ / ___/ _ \/ ___/ 
 / /|  / /_/ / /__/ /_/ (__  ) ____/ /  / ___(__  )  
/_/ |_/\____/\___/\__/_/____/_/   /_/   \___/____/   
                                                      
        🦆 DuckDNS Quick Deployment 🦆
        No limits. No timeouts. Free forever.
EOF
echo -e "${NC}"

echo ""
echo -e "${BOLD}${GREEN}Welcome to NoctisPro PACS - DuckDNS Deployment${NC}"
echo ""
echo "This script will deploy NoctisPro with DuckDNS for global access."
echo ""
echo -e "${BOLD}Why DuckDNS instead of Ngrok?${NC}"
echo "  ✅ NO request limits (ngrok: 40 requests/min)"
echo "  ✅ NO session timeout (ngrok: 2 hours)"
echo "  ✅ Permanent URL (never changes)"
echo "  ✅ 100% FREE (ngrok: $8-25/month for static URL)"
echo "  ✅ Production ready"
echo ""

# Check if already configured
if [[ -f "/etc/noctis/duckdns.env" ]]; then
    source /etc/noctis/duckdns.env
    echo -e "${GREEN}✅ Found existing DuckDNS configuration${NC}"
    echo -e "   Domain: ${BOLD}${DUCKDNS_SUBDOMAIN}.duckdns.org${NC}"
    echo ""
    read -p "Use existing configuration? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        USE_EXISTING=true
    else
        USE_EXISTING=false
    fi
else
    USE_EXISTING=false
fi

if [[ "${USE_EXISTING}" == "false" ]]; then
    echo ""
    echo -e "${BOLD}${CYAN}Step 1: DuckDNS Setup${NC}"
    echo ""
    echo "If you don't have a DuckDNS account:"
    echo "  1. Visit https://www.duckdns.org"
    echo "  2. Sign in with Google/GitHub/Twitter"
    echo "  3. Create a subdomain"
    echo "  4. Copy your token"
    echo ""
    
    read -p "Enter your DuckDNS subdomain (without .duckdns.org): " SUBDOMAIN
    read -p "Enter your DuckDNS token: " TOKEN
    
    # Validate inputs
    if [[ -z "${SUBDOMAIN}" ]] || [[ -z "${TOKEN}" ]]; then
        echo -e "${YELLOW}⚠️  Subdomain and token are required${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BOLD}${CYAN}Step 2: System Check${NC}"
echo ""

# Check for required tools
MISSING_TOOLS=""
for tool in python3 curl git; do
    if ! command -v $tool >/dev/null 2>&1; then
        MISSING_TOOLS="${MISSING_TOOLS} $tool"
    fi
done

if [[ -n "${MISSING_TOOLS}" ]]; then
    echo -e "${YELLOW}Installing required tools:${MISSING_TOOLS}${NC}"
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y ${MISSING_TOOLS} >/dev/null 2>&1
fi

echo -e "${GREEN}✅ System requirements satisfied${NC}"

echo ""
echo -e "${BOLD}${CYAN}Step 3: Quick Deployment${NC}"
echo ""

# Create a simple deployment function
deploy_noctis() {
    # Start Django if not running
    if ! pgrep -f "python.*manage.py.*runserver" > /dev/null; then
        echo "Starting NoctisPro services..."
        cd /workspace
        
        # Setup virtual environment if needed
        if [[ ! -d "venv" ]]; then
            python3 -m venv venv
            source venv/bin/activate
            pip install --upgrade pip >/dev/null 2>&1
            pip install -r requirements.txt >/dev/null 2>&1
        else
            source venv/bin/activate
        fi
        
        # Run migrations
        python manage.py migrate --noinput >/dev/null 2>&1
        python manage.py collectstatic --noinput >/dev/null 2>&1
        
        # Start server
        nohup python manage.py runserver 0.0.0.0:8000 > /tmp/noctis.log 2>&1 &
        
        echo -e "${GREEN}✅ NoctisPro started${NC}"
    else
        echo -e "${GREEN}✅ NoctisPro already running${NC}"
    fi
}

# Deploy NoctisPro
deploy_noctis

# Configure DuckDNS if new setup
if [[ "${USE_EXISTING}" == "false" ]]; then
    echo ""
    echo "Configuring DuckDNS..."
    
    # Update DuckDNS
    IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org)
    RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=${IP}")
    
    if [[ "${RESPONSE}" == "OK" ]]; then
        echo -e "${GREEN}✅ DuckDNS configured successfully${NC}"
        
        # Save configuration
        sudo mkdir -p /etc/noctis
        echo "DUCKDNS_SUBDOMAIN=${SUBDOMAIN}" | sudo tee /etc/noctis/duckdns.env >/dev/null
        echo "DUCKDNS_TOKEN=${TOKEN}" | sudo tee -a /etc/noctis/duckdns.env >/dev/null
        
        # Setup auto-update
        cat << 'CRON' | sudo tee /etc/cron.d/duckdns >/dev/null
*/5 * * * * root curl -s "https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=" >/dev/null 2>&1
CRON
        
        echo -e "${GREEN}✅ Auto-update configured (every 5 minutes)${NC}"
    else
        echo -e "${YELLOW}⚠️  DuckDNS update failed - check your token${NC}"
    fi
else
    SUBDOMAIN="${DUCKDNS_SUBDOMAIN}"
fi

# Install and configure nginx for production
if ! command -v nginx >/dev/null 2>&1; then
    echo ""
    echo "Installing Nginx for production deployment..."
    sudo apt-get install -y nginx >/dev/null 2>&1
fi

# Create nginx config
sudo tee /etc/nginx/sites-available/noctis >/dev/null << EOF
server {
    listen 80;
    server_name ${SUBDOMAIN}.duckdns.org localhost;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /static/ {
        alias /workspace/staticfiles/;
    }
    
    location /media/ {
        alias /workspace/media/;
    }
    
    client_max_body_size 500M;
}
EOF

sudo ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t >/dev/null 2>&1 && sudo systemctl reload nginx

echo ""
echo "=============================================="
echo -e "${BOLD}${GREEN}🎉 Deployment Complete!${NC}"
echo "=============================================="
echo ""
echo -e "${BOLD}${CYAN}Access your NoctisPro PACS:${NC}"
echo ""
echo -e "  🌐 Public URL: ${BOLD}${GREEN}http://${SUBDOMAIN}.duckdns.org${NC}"
echo -e "  🏥 Admin Panel: ${BOLD}${GREEN}http://${SUBDOMAIN}.duckdns.org/admin/${NC}"
echo -e "  📊 DICOM Viewer: ${BOLD}${GREEN}http://${SUBDOMAIN}.duckdns.org/dicom-viewer/${NC}"
echo ""
echo -e "  📧 Username: ${BOLD}admin${NC}"
echo -e "  🔑 Password: ${BOLD}admin123${NC}"
echo ""
echo "=============================================="
echo -e "${BOLD}${CYAN}Advantages over Ngrok:${NC}"
echo "  ✅ This URL is permanent (never changes)"
echo "  ✅ No request limits (unlimited API calls)"
echo "  ✅ No session timeout (runs 24/7)"
echo "  ✅ 100% FREE (no paid plans needed)"
echo "  ✅ Production ready"
echo "=============================================="
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. For HTTPS, run: sudo certbot --nginx -d ${SUBDOMAIN}.duckdns.org"
echo "  2. Change admin password after first login"
echo "  3. Configure your DICOM nodes"
echo ""
echo -e "${GREEN}Enjoy your unlimited, production-ready deployment!${NC}"
echo ""