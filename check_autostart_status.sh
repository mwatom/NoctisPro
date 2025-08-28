#!/bin/bash

# Simple status check for NoctisPro in container environment
echo "🔍 NoctisPro System Status Check"
echo "================================="

# Check if Django server is running
if pgrep -f "python.*manage.py" > /dev/null; then
    echo "✅ Django server is running"
    DJANGO_PID=$(pgrep -f "python.*manage.py")
    echo "   PID: $DJANGO_PID"
else
    echo "❌ Django server is not running"
fi

# Check if ngrok is running
if pgrep -f "ngrok" > /dev/null; then
    echo "✅ Ngrok is running"
    NGROK_PID=$(pgrep -f "ngrok")
    echo "   PID: $NGROK_PID"
    
    # Check for ngrok URL
    if [ -f "/workspace/current_ngrok_url.txt" ]; then
        URL=$(cat /workspace/current_ngrok_url.txt)
        echo "   URL: $URL"
    fi
else
    echo "❌ Ngrok is not running"
fi

# Check database
if [ -f "/workspace/db.sqlite3" ]; then
    echo "✅ Database file exists"
    DB_SIZE=$(du -h /workspace/db.sqlite3 | cut -f1)
    echo "   Size: $DB_SIZE"
else
    echo "❌ Database file missing"
fi

# Check log files
echo ""
echo "📋 Recent log entries:"
if [ -f "/workspace/noctispro_complete.log" ]; then
    echo "   Last 5 lines from noctispro_complete.log:"
    tail -5 /workspace/noctispro_complete.log | sed 's/^/   /'
else
    echo "   No complete log file found"
fi

# Quick commands section
echo ""
echo "🔧 Quick Commands:"
echo "   Start system:  ./start_robust_system.sh"
echo "   Stop system:   ./stop_robust_system.sh"
echo "   View logs:     tail -f noctispro_complete.log"
echo "   Django admin:  python manage.py createsuperuser"