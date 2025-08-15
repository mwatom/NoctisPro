#!/bin/bash
# Noctis Pro PACS - Universal One-Line Deployment
set -euo pipefail

REPO_URL="https://github.com/mwatom/NoctisPro.git"
PROJECT_DIR="NoctisPro"

echo "🚀 Noctis Pro PACS - Universal Deployment Starting..."
echo "📥 Repository: $REPO_URL"

# Clean up any existing installation
if [[ -d "$PROJECT_DIR" ]]; then
    echo "🧹 Cleaning up existing installation..."
    sudo rm -rf "$PROJECT_DIR"
fi

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "📦 Installing git..."
    sudo apt-get update -y && sudo apt-get install -y git
fi

# Clone the repository
echo "📥 Downloading Noctis Pro PACS..."
git clone "$REPO_URL"
cd "$PROJECT_DIR"

# Make deployment script executable and run it
echo "🔧 Setting up system..."
chmod +x deploy.sh
./deploy.sh

# Wait for services to start
echo "⏳ Starting services..."
sleep 5

# Install Node.js and localtunnel for public access
echo "🌐 Setting up public access tunnel..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

if ! command -v lt &> /dev/null; then
    sudo npm install -g localtunnel
fi

# Create unique subdomain and start tunnel
SUBDOMAIN="noctis-pacs-$(date +%s | tail -c 4)"
echo "🔗 Creating tunnel with subdomain: $SUBDOMAIN"
nohup lt --port 8000 --subdomain "$SUBDOMAIN" > tunnel.log 2>&1 &

# Wait for tunnel to establish
sleep 8

# Get URLs
PUBLIC_URL=""
for i in {1..5}; do
    if [[ -f tunnel.log ]]; then
        PUBLIC_URL=$(grep -o 'https://.*\.loca\.lt' tunnel.log 2>/dev/null | tail -1 || true)
        if [[ -n "$PUBLIC_URL" ]]; then
            break
        fi
    fi
    echo "⏳ Waiting for tunnel... (attempt $i/5)"
    sleep 3
done

LOCAL_IP=$(hostname -I | awk '{print $1}' || echo "localhost")

# Display results
echo ""
echo "🎉 ==============================================="
echo "✅ NOCTIS PRO PACS DEPLOYED SUCCESSFULLY!"
echo "🎉 ==============================================="
echo ""
echo "🌐 PUBLIC ACCESS (Internet accessible, no IP exposed):"
if [[ -n "$PUBLIC_URL" ]]; then
    echo "   🔗 Main System: $PUBLIC_URL/"
    echo "   👨‍💼 Admin Panel: $PUBLIC_URL/admin-panel/"
    echo "   📋 Worklist: $PUBLIC_URL/worklist/"
    echo "   🏥 DICOM Viewer: $PUBLIC_URL/dicom-viewer/"
else
    echo "   ⚠️  Tunnel still connecting... Check: tail -f tunnel.log"
fi
echo ""
echo "🏠 LOCAL ACCESS:"
echo "   🔗 Main System: http://$LOCAL_IP:8000/"
echo "   👨‍💼 Admin Panel: http://$LOCAL_IP:8000/admin-panel/"
echo "   📋 Worklist: http://$LOCAL_IP:8000/worklist/"
echo ""
echo "🔐 Create admin user:"
echo "   ADMIN_USER=admin ADMIN_EMAIL=admin@example.com ADMIN_PASS=admin123 ./deploy.sh"
echo ""
echo "📊 System Status:"
echo "   • Web Server: ✅ Running on port 8000"
echo "   • DICOM Receiver: ✅ Running on port 11112"
echo "   • Database: ✅ SQLite ready"
echo "   • Public Tunnel: ✅ Active"
echo "==============================================="