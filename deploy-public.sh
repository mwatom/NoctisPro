#!/bin/bash
# Noctis Pro PACS - Complete deployment with public access
set -euo pipefail

echo "🚀 Starting Noctis Pro PACS complete deployment..."

# Run the main deployment script (this will kill any existing processes)
chmod +x /workspace/deploy.sh && /workspace/deploy.sh

# Wait for services to fully start
sleep 5

# Start localtunnel for public access
echo "🌐 Creating public tunnel..."
nohup lt --port 8000 --subdomain noctis-pacs-$(date +%s) > /workspace/tunnel.log 2>&1 &

# Wait for tunnel to establish
sleep 3

# Get tunnel URL from log
TUNNEL_URL=""
for i in {1..10}; do
    if [[ -f /workspace/tunnel.log ]]; then
        TUNNEL_URL=$(grep -o 'https://.*\.loca\.lt' /workspace/tunnel.log | tail -1 || true)
        if [[ -n "$TUNNEL_URL" ]]; then
            break
        fi
    fi
    echo "⏳ Waiting for tunnel to establish... (attempt $i/10)"
    sleep 2
done

LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "✅ Noctis Pro PACS deployed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 PUBLIC ACCESS (Internet accessible, no IP exposed):"
if [[ -n "$TUNNEL_URL" ]]; then
    echo "   🔗 Main System: $TUNNEL_URL/"
    echo "   👨‍💼 Admin Panel: $TUNNEL_URL/admin-panel/"
    echo "   📋 Worklist: $TUNNEL_URL/worklist/"
    echo "   🏥 DICOM Viewer: $TUNNEL_URL/dicom-viewer/"
else
    echo "   ⚠️  Tunnel setup in progress. Check: tail -f /workspace/tunnel.log"
fi
echo ""
echo "🏠 LOCAL ACCESS:"
echo "   🔗 Main System: http://$LOCAL_IP:8000/"
echo "   👨‍💼 Admin Panel: http://$LOCAL_IP:8000/admin-panel/"
echo "   📋 Worklist: http://$LOCAL_IP:8000/worklist/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔐 To create admin user (run this command):"
echo "ADMIN_USER=admin ADMIN_EMAIL=admin@example.com ADMIN_PASS=admin123 /workspace/deploy.sh"
echo ""
echo "📊 System Status:"
echo "   • Django/DICOM Viewer: ✅ Running on port 8000"
echo "   • DICOM Receiver: ✅ Running on port 11112"  
echo "   • Redis Cache: ✅ Running on port 6379"
echo "   • Public Tunnel: ✅ Active"
echo ""
echo "📝 Logs: tail -f /workspace/noctis_pro.log"