#!/bin/bash

# 🎯 Quick Masterpiece Deployment
# One-command deployment for the refined system

echo "🚀 Deploying NoctisPro Masterpiece with Auto-Start..."
echo ""

# Run the full deployment
/workspace/deploy_masterpiece_service.sh deploy

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "To manage your service:"
echo "  ./deploy_masterpiece_service.sh status   - Check status"
echo "  ./deploy_masterpiece_service.sh stop     - Stop service"
echo "  ./deploy_masterpiece_service.sh start    - Start service"
echo "  ./deploy_masterpiece_service.sh restart  - Restart service"
echo ""