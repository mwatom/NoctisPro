#!/bin/bash
# Auto-update Duck DNS IP for NOCTIS PRO deployment
set -e

# Load configuration
if [ -f "/workspace/.duckdns_config" ]; then
    source /workspace/.duckdns_config
else
    DUCKDNS_DOMAIN="noctispro2"
    DUCKDNS_TOKEN="9d40387a-ac37-4268-8d51-69985ae32c30"
fi

# Get current public IP with fallback methods
PUBLIC_IP=""
for service in "ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "checkip.amazonaws.com"; do
    PUBLIC_IP=$(curl -s --connect-timeout 10 "$service" 2>/dev/null | tr -d '\n\r' | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    if [[ $PUBLIC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        break
    fi
    PUBLIC_IP=""
done

if [ -z "$PUBLIC_IP" ]; then
    echo "$(date): ERROR: Could not determine public IP" >> /workspace/duckdns.log
    exit 1
fi

# Update Duck DNS
RESPONSE=$(curl -s --connect-timeout 30 "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=${PUBLIC_IP}")

if [ "$RESPONSE" = "OK" ]; then
    echo "$(date): SUCCESS: Updated ${DUCKDNS_DOMAIN}.duckdns.org to ${PUBLIC_IP}" >> /workspace/duckdns.log
else
    echo "$(date): ERROR: Failed to update DNS. Response: ${RESPONSE}" >> /workspace/duckdns.log
fi
