#!/bin/bash

# Simple status check for NoctisPro in container environment
echo "🔍 NoctisPro System Status Check"
echo "================================="

# Check if autostart service is running
if [ -f "/workspace/autostart_noctispro.pid" ] && kill -0 $(cat "/workspace/autostart_noctispro.pid") 2>/dev/null; then
    echo "✅ Autostart service is running"
    echo "   PID: $(cat /workspace/autostart_noctispro.pid)"
    echo "   Static URL: https://colt-charmed-lark.ngrok-free.app"
else
    echo "❌ Autostart service is not running"
    echo "   💡 Start with: ./manage_autostart.sh start"
fi
echo ""

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
echo "   Start autostart:    ./manage_autostart.sh start"
echo "   Stop autostart:     ./manage_autostart.sh stop"
echo "   Restart autostart:  ./manage_autostart.sh restart"
echo "   View logs:          ./manage_autostart.sh logs"
echo "   Service status:     ./manage_autostart.sh status"
echo "   Django admin:       source venv/bin/activate && python manage.py createsuperuser"
echo ""
echo "🌍 Static URL: https://colt-charmed-lark.ngrok-free.app"