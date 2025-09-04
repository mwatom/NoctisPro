#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - AUTOMATIC DEPLOYMENT WITH PUBLIC ACCESS"
echo "================================================================"
echo ""

# Run domain configuration
if [ -f /workspace/configure_noctispro_domain.sh ]; then
    echo "🔧 Configuring domain..."
    /workspace/configure_noctispro_domain.sh
fi

# Start all services with public access
echo "🚀 Starting production services with public access..."
/workspace/start_noctispro_production.sh

echo ""
echo "🎉 NOCTIS PRO PACS deployed with automatic public access!"
echo "🌍 Public URL: https://mallard-shining-curiously.ngrok-free.app"
echo "🏠 Local URL: http://noctispro"
