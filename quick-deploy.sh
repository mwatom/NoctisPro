#!/bin/bash
# Noctis Pro PACS - One-line deployment script
set -euo pipefail

echo "🚀 Starting Noctis Pro PACS deployment..."

# Run the main deployment script
chmod +x /workspace/deploy.sh && /workspace/deploy.sh

echo "✅ Deployment completed successfully!"
echo "🌐 System is accessible at: http://$(hostname -I | awk '{print $1}'):8000/"
echo "👨‍💼 Admin panel: http://$(hostname -I | awk '{print $1}'):8000/admin-panel/"
echo "📋 Worklist: http://$(hostname -I | awk '{print $1}'):8000/worklist/"
echo ""
echo "🔧 To create admin user, run:"
echo "    ADMIN_USER=admin ADMIN_EMAIL=admin@example.com ADMIN_PASS=admin123 /workspace/deploy.sh"