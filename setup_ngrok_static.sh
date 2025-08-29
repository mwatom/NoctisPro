#!/bin/bash

# 🚇 Setup Ngrok Static URL Configuration
# This script sets up ngrok with a consistent subdomain

echo "🚇 Setting up Ngrok with static configuration..."

# Create ngrok config with static subdomain
cat > ~/.config/ngrok/ngrok.yml << 'EOF'
version: "2"
authtoken: 31Ru57qNtsoaFXnGZDyosoqQBKi_2RV15cXnsTifpKjae1N36
tunnels:
  noctispro:
    proto: http
    addr: 8000
    subdomain: noctispro-live
    inspect: true
  noctispro-alt:
    proto: http
    addr: 8000
    subdomain: noctispro-production
    inspect: true
EOF

echo "✅ Ngrok configuration created with static subdomains:"
echo "   - noctispro-live.ngrok-free.app"
echo "   - noctispro-production.ngrok-free.app (fallback)"
echo ""
echo "🔧 To start a tunnel, use:"
echo "   ngrok start noctispro"
echo "   or"
echo "   ngrok start noctispro-alt"