#!/bin/bash

echo "🚇 CLOUDFLARE TUNNEL SETUP"
echo "=========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Cloudflare Tunnel (cloudflared)...${NC}"

# Download and install cloudflared
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    echo -e "${GREEN}✅ Cloudflared installed${NC}"
else
    echo -e "${GREEN}✅ Cloudflared already installed${NC}"
fi

# Check if tunnel already exists
if [ -f "/workspace/.cloudflared/config.yml" ]; then
    echo -e "${YELLOW}⚠️  Existing tunnel configuration found${NC}"
    echo -e "${BLUE}Current configuration:${NC}"
    cat /workspace/.cloudflared/config.yml
    echo ""
    read -p "Do you want to recreate the tunnel? (y/N): " recreate
    if [ "$recreate" != "y" ] && [ "$recreate" != "Y" ]; then
        echo -e "${BLUE}Using existing tunnel configuration${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${YELLOW}🔐 AUTHENTICATION REQUIRED${NC}"
echo -e "${BLUE}Please follow these steps:${NC}"
echo ""
echo "1. A browser window will open"
echo "2. Log in to your Cloudflare account"
echo "3. Authorize the tunnel"
echo "4. Return to this terminal"
echo ""
read -p "Press Enter to continue..."

# Authenticate with Cloudflare
cloudflared tunnel login

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Authentication failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"

# Create tunnel
TUNNEL_NAME="noctispro-$(date +%s)"
echo -e "${BLUE}Creating tunnel: ${TUNNEL_NAME}${NC}"

cloudflared tunnel create ${TUNNEL_NAME}

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to create tunnel${NC}"
    exit 1
fi

# Get tunnel UUID
TUNNEL_UUID=$(cloudflared tunnel list | grep ${TUNNEL_NAME} | awk '{print $1}')
echo -e "${GREEN}✅ Tunnel created with UUID: ${TUNNEL_UUID}${NC}"

# Create config directory
mkdir -p /workspace/.cloudflared

# Create tunnel configuration
cat > /workspace/.cloudflared/config.yml << EOF
tunnel: ${TUNNEL_UUID}
credentials-file: /home/ubuntu/.cloudflared/${TUNNEL_UUID}.json

ingress:
  - hostname: noctispro.your-domain.com
    service: http://localhost:8000
  - hostname: "*.your-domain.com"
    service: http://localhost:8000
  - service: http_status:404
EOF

echo -e "${BLUE}Created tunnel configuration${NC}"

# Create systemd service
sudo tee /etc/systemd/system/cloudflared-tunnel.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/local/bin/cloudflared tunnel --config /workspace/.cloudflared/config.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-tunnel.service

echo -e "${GREEN}✅ Systemd service created and enabled${NC}"

# Create DNS record
echo ""
echo -e "${YELLOW}📋 MANUAL DNS SETUP REQUIRED${NC}"
echo -e "${BLUE}Please add the following DNS record in your Cloudflare dashboard:${NC}"
echo ""
echo "Type: CNAME"
echo "Name: noctispro (or your preferred subdomain)"
echo "Target: ${TUNNEL_UUID}.cfargotunnel.com"
echo "Proxy status: Proxied (orange cloud)"
echo ""
echo -e "${YELLOW}Alternatively, you can use the command:${NC}"
echo "cloudflared tunnel route dns ${TUNNEL_NAME} noctispro.your-domain.com"
echo ""

# Save tunnel info
echo "TUNNEL_NAME=${TUNNEL_NAME}" > /workspace/.tunnel_config
echo "TUNNEL_UUID=${TUNNEL_UUID}" >> /workspace/.tunnel_config
chmod 600 /workspace/.tunnel_config

echo ""
echo -e "${GREEN}🎉 Cloudflare Tunnel setup complete!${NC}"
echo -e "${BLUE}Configuration saved to: /workspace/.tunnel_config${NC}"
echo ""
echo -e "${YELLOW}To start the tunnel:${NC}"
echo "sudo systemctl start cloudflared-tunnel.service"
echo ""
echo -e "${YELLOW}To check tunnel status:${NC}"
echo "sudo systemctl status cloudflared-tunnel.service"
echo ""
echo -e "${YELLOW}Benefits of Cloudflare Tunnel:${NC}"
echo "✅ No port forwarding required"
echo "✅ Automatic SSL/TLS encryption"
echo "✅ DDoS protection"
echo "✅ Works behind NAT/firewall"
echo "✅ Free for personal use"