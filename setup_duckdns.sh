#!/bin/bash

echo "🦆 DUCK DNS SETUP"
echo "=================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Duck DNS token and domain are provided
if [ -z "$DUCKDNS_DOMAIN" ] || [ -z "$DUCKDNS_TOKEN" ]; then
    echo -e "${RED}❌ Missing Duck DNS credentials!${NC}"
    echo ""
    echo -e "${YELLOW}Please set the following environment variables:${NC}"
    echo "export DUCKDNS_DOMAIN=your-subdomain"
    echo "export DUCKDNS_TOKEN=your-token-from-duckdns.org"
    echo ""
    echo -e "${BLUE}To get these:${NC}"
    echo "1. Go to https://www.duckdns.org"
    echo "2. Sign in with Google/GitHub/Reddit/Twitter"
    echo "3. Create a subdomain (e.g., 'noctispro')"
    echo "4. Copy your token from the top of the page"
    echo ""
    echo -e "${YELLOW}Then run:${NC}"
    echo "export DUCKDNS_DOMAIN=noctispro"
    echo "export DUCKDNS_TOKEN=your-actual-token"
    echo "bash setup_duckdns.sh"
    exit 1
fi

echo -e "${BLUE}Setting up Duck DNS for domain: ${DUCKDNS_DOMAIN}.duckdns.org${NC}"

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
cat > /workspace/update_duckdns.sh << EOF
#!/bin/bash
# Auto-update Duck DNS IP
PUBLIC_IP=\$(curl -s ifconfig.me)
curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=\${PUBLIC_IP}"
echo "\$(date): Updated ${DUCKDNS_DOMAIN}.duckdns.org to \${PUBLIC_IP}" >> /workspace/duckdns.log
EOF

chmod +x /workspace/update_duckdns.sh

# Set up cron job for automatic updates
(crontab -l 2>/dev/null; echo "*/5 * * * * /workspace/update_duckdns.sh") | crontab -

echo -e "${GREEN}✅ Auto-update cron job created (runs every 5 minutes)${NC}"

# Test DNS resolution
sleep 2
RESOLVED_IP=$(nslookup ${DUCKDNS_DOMAIN}.duckdns.org | grep "Address:" | tail -1 | awk '{print $2}')
echo -e "${BLUE}DNS resolution test: ${DUCKDNS_DOMAIN}.duckdns.org resolves to ${RESOLVED_IP}${NC}"

if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
    echo -e "${GREEN}✅ DNS resolution successful!${NC}"
else
    echo -e "${YELLOW}⚠️  DNS may take a few minutes to propagate${NC}"
fi

# Save credentials for later use
echo "DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN}" > /workspace/.duckdns_config
echo "DUCKDNS_TOKEN=${DUCKDNS_TOKEN}" >> /workspace/.duckdns_config
chmod 600 /workspace/.duckdns_config

echo ""
echo -e "${GREEN}🎉 Duck DNS setup complete!${NC}"
echo -e "${BLUE}Your domain: https://${DUCKDNS_DOMAIN}.duckdns.org${NC}"
echo -e "${BLUE}Configuration saved to: /workspace/.duckdns_config${NC}"
echo ""
echo -e "${YELLOW}Next step: Set up Cloudflare for SSL and CDN${NC}"