#!/bin/bash

echo "🌐 NOCTISPRO STATIC URL SETUP"
echo "============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}Welcome to NoctisPro Static URL Setup!${NC}"
echo -e "${BLUE}This will replace ngrok with a permanent static URL solution.${NC}"
echo ""

# Show options
echo -e "${YELLOW}Choose your preferred setup:${NC}"
echo ""
echo "1. 🦆 Duck DNS Only (Free, Simple)"
echo "   - Free subdomain (e.g., noctispro.duckdns.org)"
echo "   - Automatic IP updates"
echo "   - Basic SSL via Let's Encrypt"
echo ""
echo "2. ☁️  Duck DNS + Cloudflare (Recommended)"
echo "   - Duck DNS for dynamic IP"
echo "   - Cloudflare for SSL, CDN, DDoS protection"
echo "   - Professional performance"
echo ""
echo "3. 🚇 Cloudflare Tunnel (Best for Home Servers)"
echo "   - No port forwarding needed"
echo "   - Works behind NAT/firewall"
echo "   - Enterprise-grade security"
echo ""
echo "4. 📖 Show Setup Guide"
echo "   - Detailed instructions for manual setup"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "${BLUE}Setting up Duck DNS...${NC}"
        echo ""
        echo -e "${YELLOW}You'll need Duck DNS credentials:${NC}"
        echo "1. Go to https://www.duckdns.org"
        echo "2. Sign in and create a subdomain"
        echo "3. Copy your token"
        echo ""
        read -p "Enter your Duck DNS domain (without .duckdns.org): " domain
        read -p "Enter your Duck DNS token: " token
        echo ""
        export DUCKDNS_DOMAIN=$domain
        export DUCKDNS_TOKEN=$token
        bash setup_duckdns.sh
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Duck DNS setup complete!${NC}"
            echo -e "${BLUE}Deploying your application...${NC}"
            bash deploy_static_url.sh
        fi
        ;;
    2)
        echo -e "${BLUE}Setting up Duck DNS + Cloudflare...${NC}"
        echo ""
        echo -e "${YELLOW}You'll need both Duck DNS and Cloudflare credentials.${NC}"
        echo ""
        read -p "Enter your Duck DNS domain: " domain
        read -p "Enter your Duck DNS token: " token
        read -p "Enter your Cloudflare API token: " cf_token
        read -p "Enter your Cloudflare Zone ID: " cf_zone
        echo ""
        export DUCKDNS_DOMAIN=$domain
        export DUCKDNS_TOKEN=$token
        export CLOUDFLARE_API_TOKEN=$cf_token
        export CLOUDFLARE_ZONE_ID=$cf_zone
        bash setup_duckdns.sh && bash setup_cloudflare.sh
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Duck DNS + Cloudflare setup complete!${NC}"
            echo -e "${BLUE}Deploying your application...${NC}"
            bash deploy_static_url.sh
        fi
        ;;
    3)
        echo -e "${BLUE}Setting up Cloudflare Tunnel...${NC}"
        echo ""
        echo -e "${YELLOW}This will require browser authentication with Cloudflare.${NC}"
        echo -e "${YELLOW}Make sure you have a Cloudflare account and domain ready.${NC}"
        echo ""
        read -p "Press Enter to continue..."
        bash setup_cloudflare_tunnel.sh
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Cloudflare Tunnel setup complete!${NC}"
            echo -e "${BLUE}Deploying your application...${NC}"
            bash deploy_static_url.sh
        fi
        ;;
    4)
        echo -e "${BLUE}Opening setup guide...${NC}"
        if command -v less &> /dev/null; then
            less STATIC_URL_SETUP_GUIDE.md
        else
            cat STATIC_URL_SETUP_GUIDE.md
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo -e "${BLUE}Your NoctisPro DICOM Viewer is now accessible via static URL!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test your application access"
echo "2. Change the default admin password"
echo "3. Configure any additional settings"
echo ""
echo -e "${BLUE}For troubleshooting, see: STATIC_URL_SETUP_GUIDE.md${NC}"