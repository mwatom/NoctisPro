#!/bin/bash

# 🎯 Quick Masterpiece Deployment
# One-command deployment for the refined system
# Enhanced with Auto-Detection

echo "🚀 Deploying NoctisPro Masterpiece with Auto-Detection & Auto-Start..."
echo ""

# Run the full deployment with auto-detection
/workspace/deploy_masterpiece_service.sh deploy

echo ""
echo "🎉 Deployment Complete with Auto-Detection!"
echo ""
echo "To manage your service:"
echo "  ./deploy_masterpiece_service.sh status   - Check status"
echo "  ./deploy_masterpiece_service.sh stop     - Stop service"
echo "  ./deploy_masterpiece_service.sh start    - Start service (auto-detects env)"
echo "  ./deploy_masterpiece_service.sh restart  - Restart service (auto-detects env)"
echo ""
echo "🔍 Auto-Detection handled:"
echo "  • Workspace tokens and environment variables"
echo "  • SECRET_KEY generation if needed"
echo "  • Ngrok authentication from env files"
echo "  • Environment file creation if missing"
echo ""