#!/bin/bash

# Quick Internet Deployment for NoctisPro
# Ubuntu Server 24.04 - Fast deployment script

set -e

echo "🚀 Starting Quick Internet Deployment for NoctisPro..."
echo "=================================================="

# Check if we're in the right directory
if [[ ! -f "docker-compose.production.yml" ]]; then
    echo "❌ Error: docker-compose.production.yml not found"
    echo "Please run this script from the NoctisPro root directory"
    exit 1
fi

# Make sure the main deployment script is executable
chmod +x deploy_internet_production.sh

# Run the main deployment script
echo "🔧 Running comprehensive deployment..."
./deploy_internet_production.sh

echo ""
echo "✅ Quick deployment completed!"
echo ""
echo "🌐 Your system should now be accessible on the internet."
echo "Check the output above for the server IP address and access URLs."