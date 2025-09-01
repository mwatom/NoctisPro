#!/bin/bash

# NoctisPro Status Check Script

echo "🔍 NoctisPro Status Check"
echo "========================"

cd /workspace

# Check if Daphne is running
if [ -f "daphne.pid" ] && kill -0 $(cat daphne.pid) 2>/dev/null; then
    echo "✅ Daphne process running (PID: $(cat daphne.pid))"
else
    echo "❌ Daphne process not running"
fi

# Check HTTP response
if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ Application responding to HTTP requests"
    
    # Get response details
    echo ""
    echo "📊 Response Details:"
    curl -s -I http://localhost:8000 | head -3
    
    # Test health endpoint
    echo ""
    echo "🏥 Health Check:"
    curl -s http://localhost:8000/health/ | python3 -m json.tool 2>/dev/null || echo "Health endpoint available but not JSON"
    
else
    echo "❌ Application not responding"
fi

# Check logs for recent errors
echo ""
echo "📋 Recent Log Entries:"
if [ -f "logs/daphne.log" ]; then
    tail -5 logs/daphne.log
else
    echo "No daphne.log found"
fi

echo ""
echo "🌐 Access URLs:"
echo "• Main App: http://localhost:8000"
echo "• Health: http://localhost:8000/health/"
echo "• Admin: http://localhost:8000/admin/"