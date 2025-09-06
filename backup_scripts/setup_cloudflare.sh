#!/bin/bash

echo "☁️  CLOUDFLARE SETUP"
echo "==================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load Duck DNS config
if [ -f "/workspace/.duckdns_config" ]; then
    source /workspace/.duckdns_config
    echo -e "${BLUE}Loaded Duck DNS domain: ${DUCKDNS_DOMAIN}.duckdns.org${NC}"
else
    echo -e "${RED}❌ Duck DNS not configured! Please run setup_duckdns.sh first${NC}"
    exit 1
fi

# Check for Cloudflare credentials
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo -e "${RED}❌ Missing Cloudflare credentials!${NC}"
    echo ""
    echo -e "${YELLOW}Please set the following environment variables:${NC}"
    echo "export CLOUDFLARE_API_TOKEN=your-api-token"
    echo "export CLOUDFLARE_ZONE_ID=your-zone-id"
    echo ""
    echo -e "${BLUE}To get these:${NC}"
    echo "1. Go to https://dash.cloudflare.com"
    echo "2. Add your domain (or use a Cloudflare domain)"
    echo "3. Get Zone ID from the right sidebar"
    echo "4. Create API Token: My Profile > API Tokens > Create Token"
    echo "   - Use 'Custom token' template"
    echo "   - Permissions: Zone:Zone:Read, Zone:DNS:Edit"
    echo "   - Zone Resources: Include:Specific Zone:Your Zone"
    echo ""
    echo -e "${YELLOW}Alternative: Use Cloudflare Tunnel (recommended for home servers)${NC}"
    echo "This bypasses the need for port forwarding and provides better security."
    echo ""
    exit 1
fi

echo -e "${BLUE}Setting up Cloudflare for ${DUCKDNS_DOMAIN}.duckdns.org${NC}"

# Get current public IP
PUBLIC_IP=$(curl -s ifconfig.me)
echo -e "${BLUE}Current public IP: ${PUBLIC_IP}${NC}"

# Function to create/update DNS record
update_dns_record() {
    local record_type=$1
    local record_name=$2
    local record_content=$3
    
    # Check if record exists
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=${record_type}&name=${record_name}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | \
        python3 -c "import sys, json; data=json.load(sys.stdin); print(data['result'][0]['id'] if data['result'] else '')")
    
    if [ -n "$RECORD_ID" ]; then
        # Update existing record
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${record_content}\",\"ttl\":1}")
        echo -e "${GREEN}✅ Updated ${record_type} record for ${record_name}${NC}"
    else
        # Create new record
        RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${record_content}\",\"ttl\":1}")
        echo -e "${GREEN}✅ Created ${record_type} record for ${record_name}${NC}"
    fi
}

# Create CNAME record pointing to Duck DNS
update_dns_record "CNAME" "noctispro" "${DUCKDNS_DOMAIN}.duckdns.org"

# Enable Cloudflare proxy (orange cloud) for SSL and performance
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/settings/ssl" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{"value":"full"}'

echo -e "${GREEN}✅ SSL mode set to Full${NC}"

# Save Cloudflare config
echo "CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}" > /workspace/.cloudflare_config
echo "CLOUDFLARE_ZONE_ID=${CLOUDFLARE_ZONE_ID}" >> /workspace/.cloudflare_config
chmod 600 /workspace/.cloudflare_config

echo ""
echo -e "${GREEN}🎉 Cloudflare setup complete!${NC}"
echo -e "${BLUE}Your domain will be accessible at: https://noctispro.yourdomain.com${NC}"
echo -e "${BLUE}Configuration saved to: /workspace/.cloudflare_config${NC}"
echo ""
echo -e "${YELLOW}Note: DNS changes may take a few minutes to propagate${NC}"
echo -e "${YELLOW}Cloudflare provides SSL, CDN, and DDoS protection automatically${NC}"