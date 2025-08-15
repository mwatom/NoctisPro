#!/bin/bash
# Noctis Pro PACS - One-line deployment with public access
set -euo pipefail

echo "🚀 Starting Noctis Pro PACS deployment with public access..."

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok not found. Installing..."
    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install -y ngrok
fi

# Run the main deployment script
chmod +x /workspace/deploy.sh && /workspace/deploy.sh

# Wait a moment for services to fully start
sleep 3

# Start ngrok tunnel in background
echo "🌐 Setting up public tunnel..."
nohup ngrok http 8000 --log /workspace/ngrok.log > /dev/null 2>&1 &

# Wait for tunnel to establish
sleep 5

# Get the public URL
PUBLIC_URL=""
for i in {1..10}; do
    PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*\.ngrok-free\.app' | head -1 || true)
    if [[ -n "$PUBLIC_URL" ]]; then
        break
    fi
    echo "⏳ Waiting for tunnel to establish... (attempt $i/10)"
    sleep 2
done

LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "✅ Deployment completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 PUBLIC ACCESS (no IP exposed):"
if [[ -n "$PUBLIC_URL" ]]; then
    echo "   🔗 Main System: $PUBLIC_URL/"
    echo "   👨‍💼 Admin Panel: $PUBLIC_URL/admin-panel/"
    echo "   📋 Worklist: $PUBLIC_URL/worklist/"
else
    echo "   ❌ Failed to establish tunnel. Check ngrok status."
fi
echo ""
echo "🏠 LOCAL ACCESS:"
echo "   🔗 Main System: http://$LOCAL_IP:8000/"
echo "   👨‍💼 Admin Panel: http://$LOCAL_IP:8000/admin-panel/"
echo "   📋 Worklist: http://$LOCAL_IP:8000/worklist/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔧 To create admin user:"
echo "    ADMIN_USER=admin ADMIN_EMAIL=admin@example.com ADMIN_PASS=admin123 /workspace/deploy.sh"
echo ""
echo "📊 Monitor tunnel status: http://localhost:4040"
echo "📝 Logs: tail -f /workspace/ngrok.log"