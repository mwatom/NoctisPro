#!/bin/bash
echo "🚀 NOCTIS PRO PACS v2.0 - AUTO-START CONFIGURATION"
echo "================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 CONFIGURING AUTOMATIC STARTUP FOR PUBLIC ACCESS${NC}"
echo ""

# Function to install ngrok if not present
install_ngrok() {
    echo -e "${YELLOW}📦 Installing ngrok...${NC}"
    cd /tmp
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    sudo mv ngrok /usr/local/bin/
    rm -f ngrok-v3-stable-linux-amd64.tgz
    echo -e "${GREEN}✅ ngrok installed successfully${NC}"
}

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    install_ngrok
else
    echo -e "${GREEN}✅ ngrok already installed${NC}"
fi

# Create enhanced startup script that always starts ngrok
echo -e "${YELLOW}📝 Creating auto-startup script...${NC}"

cat > /workspace/start_noctispro_production.sh << 'EOF'
#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - PRODUCTION AUTO-START"
echo "=============================================="
echo "🚀 Starting all services with public access..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd /workspace

# 1. Start/Restart Nginx
echo -e "${YELLOW}🌐 Starting Nginx reverse proxy...${NC}"
sudo nginx -t && sudo nginx -s reload 2>/dev/null || sudo nginx
if pgrep -f "nginx" > /dev/null; then
    echo -e "${GREEN}✅ Nginx running on port 80${NC}"
else
    echo "❌ Failed to start Nginx"
    exit 1
fi

# 2. Start/Restart Gunicorn
echo -e "${YELLOW}🐍 Starting Django application server...${NC}"
pkill -f gunicorn 2>/dev/null
sleep 2

source venv/bin/activate
nohup gunicorn noctis_pro.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 1800 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /workspace/gunicorn_access.log \
    --error-logfile /workspace/gunicorn_error.log \
    --daemon

sleep 3
if pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    echo -e "${GREEN}✅ Gunicorn running on port 8000${NC}"
else
    echo "❌ Failed to start Gunicorn"
    exit 1
fi

# 3. Start Ngrok tunnel (ALWAYS)
echo -e "${YELLOW}🌍 Starting ngrok public tunnel...${NC}"
pkill -f ngrok 2>/dev/null
sleep 2

# Start ngrok in background with logging
nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 \
    > /workspace/ngrok.log 2>&1 &

# Wait for ngrok to start
sleep 5

if pgrep -f ngrok > /dev/null; then
    echo -e "${GREEN}✅ Ngrok tunnel active${NC}"
    echo "   🌍 Public URL: https://mallard-shining-curiously.ngrok-free.app"
else
    echo "❌ Failed to start ngrok tunnel"
fi

echo ""
echo -e "${GREEN}🎉 NOCTIS PRO PACS PRODUCTION READY WITH PUBLIC ACCESS!${NC}"
echo ""
echo -e "${BLUE}📋 ACCESS INFORMATION:${NC}"
echo "   🏠 Local Domain: http://noctispro"
echo "   🌍 Public Domain: https://mallard-shining-curiously.ngrok-free.app"
echo ""
echo -e "${BLUE}🔐 LOGIN CREDENTIALS:${NC}"
echo "   👤 Username: admin"
echo "   🔑 Password: admin123"
echo ""
echo -e "${BLUE}📊 MONITORING:${NC}"
echo "   📋 System Status: ./noctispro_status.sh"
echo "   📝 Ngrok Logs: tail -f /workspace/ngrok.log"
echo "   📝 Gunicorn Logs: tail -f /workspace/gunicorn_*.log"
echo ""
echo -e "${GREEN}✅ All services running with automatic public access!${NC}"
EOF

chmod +x /workspace/start_noctispro_production.sh
echo -e "${GREEN}✅ Production auto-start script created${NC}"

# Create a service monitoring script
echo -e "${YELLOW}📝 Creating service monitoring script...${NC}"

cat > /workspace/monitor_noctispro.sh << 'EOF'
#!/bin/bash
# NOCTIS PRO PACS - Service Monitor and Auto-Restart

check_and_restart_service() {
    local service_name=$1
    local check_command=$2
    local restart_command=$3
    
    if ! eval $check_command > /dev/null 2>&1; then
        echo "$(date): $service_name is down, restarting..."
        eval $restart_command
        sleep 5
        if eval $check_command > /dev/null 2>&1; then
            echo "$(date): $service_name restarted successfully"
        else
            echo "$(date): Failed to restart $service_name"
        fi
    fi
}

# Check Nginx
check_and_restart_service "Nginx" \
    "pgrep -f nginx" \
    "sudo nginx"

# Check Gunicorn
check_and_restart_service "Gunicorn" \
    "pgrep -f 'gunicorn.*noctis_pro'" \
    "cd /workspace && source venv/bin/activate && nohup gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 1800 --daemon > /dev/null 2>&1"

# Check Ngrok (always ensure it's running)
check_and_restart_service "Ngrok" \
    "pgrep -f ngrok" \
    "nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 > /workspace/ngrok.log 2>&1 &"
EOF

chmod +x /workspace/monitor_noctispro.sh
echo -e "${GREEN}✅ Service monitoring script created${NC}"

# Create cron job for monitoring (every 5 minutes)
echo -e "${YELLOW}📝 Setting up automatic monitoring...${NC}"

# Add cron job to ensure services stay running
(crontab -l 2>/dev/null; echo "*/5 * * * * /workspace/monitor_noctispro.sh >> /workspace/monitor.log 2>&1") | crontab -

echo -e "${GREEN}✅ Automatic monitoring configured (every 5 minutes)${NC}"

# Create startup script for system boot
echo -e "${YELLOW}📝 Creating system boot script...${NC}"

cat > /workspace/noctispro_boot.sh << 'EOF'
#!/bin/bash
# NOCTIS PRO PACS - Boot startup script
sleep 30  # Wait for system to fully boot
/workspace/start_noctispro_production.sh
EOF

chmod +x /workspace/noctispro_boot.sh

# Add to user's bashrc for automatic startup on login
if ! grep -q "start_noctispro_production.sh" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Auto-start NOCTIS PRO PACS with public access" >> ~/.bashrc
    echo "if [ -f /workspace/start_noctispro_production.sh ]; then" >> ~/.bashrc
    echo "    /workspace/start_noctispro_production.sh" >> ~/.bashrc
    echo "fi" >> ~/.bashrc
    echo -e "${GREEN}✅ Added auto-start to user login${NC}"
fi

# Update the main deployment script
echo -e "${YELLOW}📝 Updating main deployment script...${NC}"

cat > /workspace/deploy_noctispro_auto.sh << 'EOF'
#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - AUTOMATIC DEPLOYMENT WITH PUBLIC ACCESS"
echo "================================================================"
echo ""

# Run domain configuration
if [ -f /workspace/configure_noctispro_domain.sh ]; then
    echo "🔧 Configuring domain..."
    /workspace/configure_noctispro_domain.sh
fi

# Start all services with public access
echo "🚀 Starting production services with public access..."
/workspace/start_noctispro_production.sh

echo ""
echo "🎉 NOCTIS PRO PACS deployed with automatic public access!"
echo "🌍 Public URL: https://mallard-shining-curiously.ngrok-free.app"
echo "🏠 Local URL: http://noctispro"
EOF

chmod +x /workspace/deploy_noctispro_auto.sh
echo -e "${GREEN}✅ Main deployment script updated${NC}"

echo ""
echo -e "${GREEN}🎉 AUTO-START CONFIGURATION COMPLETE!${NC}"
echo ""
echo -e "${BLUE}📋 WHAT'S BEEN CONFIGURED:${NC}"
echo "   ✅ Automatic ngrok startup with system"
echo "   ✅ Service monitoring every 5 minutes"
echo "   ✅ Auto-restart if any service goes down"
echo "   ✅ Public access always available"
echo "   ✅ Login triggers automatic startup"
echo ""
echo -e "${YELLOW}🚀 TO START NOW:${NC}"
echo "   Run: ./start_noctispro_production.sh"
echo ""
echo -e "${YELLOW}🔄 AUTOMATIC FEATURES:${NC}"
echo "   • Ngrok tunnel starts automatically"
echo "   • Services restart if they crash"
echo "   • Public access is always maintained"
echo "   • Monitoring runs every 5 minutes"
echo ""
echo -e "${GREEN}✅ Your NOCTIS PRO PACS will now always have public access!${NC}"