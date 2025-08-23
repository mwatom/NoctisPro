#!/bin/bash

# 🦆 Quick DuckDNS Setup for NoctisPro
# Sets up free DNS in 5 minutes
# Run with: bash SETUP_FREE_DNS.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "🦆 DuckDNS Free DNS Setup for NoctisPro"
echo "======================================"
echo -e "${NC}"
echo -e "${GREEN}Get your free domain in 5 minutes!${NC}\n"

# Step 1: Get server IP
echo -e "${BLUE}Step 1: Getting your server's public IP...${NC}"
SERVER_IP=$(curl -s -4 ifconfig.me)
echo -e "Your server IP: ${GREEN}$SERVER_IP${NC}\n"

# Step 2: Instructions for DuckDNS account
echo -e "${BLUE}Step 2: Create DuckDNS Account${NC}"
echo -e "1. Open this link in your browser: ${YELLOW}https://www.duckdns.org/${NC}"
echo -e "2. Sign in with Google, GitHub, Reddit, or Twitter"
echo -e "3. Create a subdomain (examples: myclinic, hospitalxray, medicalcenter)"
echo -e "4. Copy your token from the DuckDNS dashboard"
echo -e "\n${YELLOW}Press Enter when you've completed the above steps...${NC}"
read -p ""

# Step 3: Get user input
echo -e "\n${BLUE}Step 3: Configure DuckDNS${NC}"
read -p "Enter your subdomain name (without .duckdns.org): " SUBDOMAIN
read -p "Enter your DuckDNS token: " TOKEN

if [[ -z "$SUBDOMAIN" || -z "$TOKEN" ]]; then
    echo -e "${RED}Error: Subdomain and token are required!${NC}"
    exit 1
fi

FULL_DOMAIN="${SUBDOMAIN}.duckdns.org"

echo -e "\n${YELLOW}Configuration:${NC}"
echo -e "Domain: ${GREEN}$FULL_DOMAIN${NC}"
echo -e "Server IP: ${GREEN}$SERVER_IP${NC}"
echo -e "Token: ${GREEN}${TOKEN:0:10}...${NC}"

read -p "Continue with setup? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Step 4: Create DuckDNS directory and script
echo -e "\n${BLUE}Step 4: Setting up DuckDNS client...${NC}"

mkdir -p ~/duckdns
cd ~/duckdns

# Create update script
cat > duck.sh << EOF
#!/bin/bash

# DuckDNS Configuration
SUBDOMAIN="$SUBDOMAIN"
TOKEN="$TOKEN"

# Update DuckDNS with current IP
echo url="https://www.duckdns.org/update?domains=\${SUBDOMAIN}&token=\${TOKEN}&ip=" | curl -k -o ~/duckdns/duck.log -K -

# Log the update
echo "\$(date): DuckDNS update completed - \$(cat ~/duckdns/duck.log)" >> ~/duckdns/update.log
EOF

chmod +x duck.sh

# Test the update
echo -e "${BLUE}Testing DuckDNS update...${NC}"
./duck.sh

# Check result
if grep -q "OK" duck.log; then
    echo -e "${GREEN}✅ DuckDNS update successful!${NC}"
else
    echo -e "${RED}❌ DuckDNS update failed. Check your token and subdomain.${NC}"
    echo "Response: $(cat duck.log)"
    exit 1
fi

# Step 5: Setup automatic updates
echo -e "\n${BLUE}Step 5: Setting up automatic updates...${NC}"

# Add to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

echo -e "${GREEN}✅ Automatic updates configured (every 5 minutes)${NC}"

# Step 6: Test DNS resolution
echo -e "\n${BLUE}Step 6: Testing DNS resolution...${NC}"
sleep 10  # Wait for DNS propagation

if nslookup "$FULL_DOMAIN" >/dev/null 2>&1; then
    RESOLVED_IP=$(dig +short "$FULL_DOMAIN" | head -n1)
    echo -e "Domain resolves to: ${GREEN}$RESOLVED_IP${NC}"
    
    if [[ "$RESOLVED_IP" == "$SERVER_IP" ]]; then
        echo -e "${GREEN}✅ DNS is correctly configured!${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS may still be propagating. Expected: $SERVER_IP, Got: $RESOLVED_IP${NC}"
        echo -e "${YELLOW}Wait 5-10 minutes and test again.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  DNS not yet propagated. This is normal and can take a few minutes.${NC}"
fi

# Success message
echo -e "\n${GREEN}🎉 DuckDNS Setup Complete! 🎉${NC}\n"

echo -e "${BLUE}Your free domain: ${GREEN}$FULL_DOMAIN${NC}"
echo -e "${BLUE}Domain will update automatically every 5 minutes${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Use ${GREEN}$FULL_DOMAIN${NC} when deploying NoctisPro"
echo -e "2. When running deployment script, enter: ${GREEN}$FULL_DOMAIN${NC}"
echo -e "3. SSL certificates will work automatically with this domain"

echo -e "\n${YELLOW}Useful Commands:${NC}"
echo -e "• Test domain: ${GREEN}nslookup $FULL_DOMAIN${NC}"
echo -e "• Check updates: ${GREEN}cat ~/duckdns/update.log${NC}"
echo -e "• Manual update: ${GREEN}~/duckdns/duck.sh${NC}"
echo -e "• View cron jobs: ${GREEN}crontab -l${NC}"

echo -e "\n${BLUE}Ready to deploy NoctisPro with domain: ${GREEN}$FULL_DOMAIN${NC}"

# Create a simple domain info file
cat > ~/duckdns/domain_info.txt << EOF
DuckDNS Configuration for NoctisPro
===================================
Domain: $FULL_DOMAIN
Subdomain: $SUBDOMAIN
Token: $TOKEN
Server IP: $SERVER_IP
Setup Date: $(date)

Use this domain when deploying NoctisPro:
sudo bash QUICK_MANUAL_DEPLOY_UBUNTU24.sh
# Enter domain: $FULL_DOMAIN
EOF

echo -e "\n${BLUE}Domain info saved to: ${GREEN}~/duckdns/domain_info.txt${NC}"
echo -e "${GREEN}Your free DNS is ready! 🚀${NC}"