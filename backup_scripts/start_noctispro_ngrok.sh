#!/bin/bash
echo "🚀 STARTING NOCTIS PRO PACS WITH NGROK TUNNEL"
echo "============================================="

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok not found. Installing ngrok..."
    
    # Download and install ngrok
    cd /tmp
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xvzf ngrok-v3-stable-linux-amd64.tgz
    sudo mv ngrok /usr/local/bin/
    
    echo "✅ ngrok installed successfully"
fi

# Start ngrok tunnel
echo "🌐 Starting ngrok tunnel for NOCTIS PRO PACS..."
echo "📍 Domain: noctispro (local)"
echo "🌍 Public URL: https://mallard-shining-curiously.ngrok-free.app"
echo ""

# Start ngrok in background
nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 > /workspace/ngrok.log 2>&1 &

echo "✅ Ngrok tunnel started!"
echo "📊 Check logs: tail -f /workspace/ngrok.log"
echo ""
echo "🔗 Access your NOCTIS PRO PACS:"
echo "   Local: http://noctispro"
echo "   Public: https://mallard-shining-curiously.ngrok-free.app"
echo ""
echo "🔐 Login credentials:"
echo "   Username: admin"
echo "   Password: admin123"
