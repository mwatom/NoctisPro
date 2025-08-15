#!/bin/bash
# Quick deployment script for Noctis Pro
# This script asks for domain information and deploys with SSL

set -euo pipefail

echo "=================================================="
echo "    Noctis Pro DICOM System - Quick Deploy"
echo "=================================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root. Please use sudo."
    exit 1
fi

echo "This script will deploy Noctis Pro on Ubuntu 22.04 with:"
echo "• Production-ready configuration"
echo "• Nginx reverse proxy"
echo "• PostgreSQL database"
echo "• Redis for caching and background tasks"
echo "• SSL certificate via Let's Encrypt (if domain provided)"
echo "• Firewall and security configurations"
echo "• System monitoring and logging"
echo

# Ask for domain name
read -p "Enter your domain name (leave empty for IP-only access): " DOMAIN_NAME

if [[ -n "$DOMAIN_NAME" ]]; then
    echo "✅ Domain: $DOMAIN_NAME"
    
    # Validate domain format
    if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        echo "❌ Invalid domain name format"
        exit 1
    fi
    
    # Ask for admin email
    read -p "Enter admin email address: " ADMIN_EMAIL
    
    if [[ ! "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Invalid email address format"
        exit 1
    fi
    
    echo "✅ Admin email: $ADMIN_EMAIL"
else
    ADMIN_EMAIL="admin@localhost"
    echo "ℹ️ No domain provided. System will be accessible via IP address only."
fi

echo
echo "Deployment will start in 10 seconds..."
echo "Press Ctrl+C to cancel"
for i in {10..1}; do
    echo -n "$i... "
    sleep 1
done
echo
echo

# Make deployment script executable
chmod +x deploy_production.sh

# Run main deployment script
if [[ -n "$DOMAIN_NAME" ]]; then
    ./deploy_production.sh "$DOMAIN_NAME" "$ADMIN_EMAIL"
else
    ./deploy_production.sh
fi