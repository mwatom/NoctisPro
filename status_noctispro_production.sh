#!/bin/bash

echo "📊 NoctisPro Production System Status"
echo "===================================="

# Check Daphne process
echo "🔍 Process Status:"
if pgrep -f "daphne.*noctis_pro" > /dev/null; then
    DAPHNE_PID=$(pgrep -f "daphne.*noctis_pro")
    echo "✅ Daphne: Running (PID: $DAPHNE_PID)"
else
    echo "❌ Daphne: Not running"
fi

# Check ngrok process
if pgrep -f "ngrok" > /dev/null; then
    NGROK_PID=$(pgrep -f "ngrok")
    echo "✅ Ngrok: Running (PID: $NGROK_PID)"
else
    echo "❌ Ngrok: Not running"
fi

echo ""

# Check HTTP response
echo "🌐 Application Status:"
if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ Application: Responding on http://localhost:8000"
    
    # Get health status
    echo ""
    echo "🏥 Health Check:"
    curl -s http://localhost:8000/health/ | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(f\"Status: {data['status']}\")
    for check, info in data['checks'].items():
        status_icon = '✅' if info['status'] == 'healthy' else '⚠️' if info['status'] == 'warning' else '❌'
        print(f\"{status_icon} {check.title()}: {info['message']}\")
except:
    print('Health data not available')
" 2>/dev/null || echo "Health endpoint not responding"
else
    echo "❌ Application: Not responding"
fi

# Check public URL
if [ -f "current_ngrok_url.txt" ]; then
    PUBLIC_URL=$(cat current_ngrok_url.txt)
    echo ""
    echo "🌍 Public URL: $PUBLIC_URL"
fi

echo ""
echo "📋 Management:"
echo "• View logs: tail -f logs/daphne.log"
echo "• Start system: ./start_noctispro_production.sh"
echo "• Stop system: ./stop_noctispro_production.sh"
echo "• Setup ngrok: https://dashboard.ngrok.com/get-started/your-authtoken"