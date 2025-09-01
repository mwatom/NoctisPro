#!/bin/bash

# Start NoctisPro Production System
# This script starts the complete NoctisPro system

echo "🚀 Starting NoctisPro Production System"
echo "======================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Stop any existing processes
echo "🛑 Stopping existing processes..."
pkill -f "daphne.*noctis_pro" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
sleep 2

# Activate virtual environment
source venv/bin/activate

# Start Daphne ASGI server
echo "🌐 Starting Daphne ASGI server..."
mkdir -p logs
daphne -b 0.0.0.0 -p 8000 --access-log logs/daphne-access.log noctis_pro.asgi:application > logs/daphne.log 2>&1 &
DAPHNE_PID=$!
echo $DAPHNE_PID > daphne.pid

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 5

# Test the application
if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ NoctisPro is running successfully!"
    echo ""
    echo "📊 System Status:"
    echo "• Local URL: http://localhost:8000"
    echo "• Health Check: http://localhost:8000/health/"
    echo "• Process PID: $DAPHNE_PID"
    echo "• Logs: tail -f logs/daphne.log"
    echo ""
    echo "🔧 Management Commands:"
    echo "• Status: ./status_noctispro_production.sh"
    echo "• Stop: ./stop_noctispro_production.sh"
    echo ""
    echo "🌍 For Public Access:"
    echo "• Set up ngrok: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "• Then run: ngrok http 8000"
    echo ""
else
    echo "❌ Failed to start NoctisPro. Check logs/daphne.log for details."
    exit 1
fi