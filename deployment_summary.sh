#!/bin/bash

# 📋 NoctisPro Deployment Summary
# Shows current status and available options

echo "🚀 NoctisPro Deployment Summary"
echo "==============================="
echo ""

# Check if virtual environment exists
if [ -d "venv" ]; then
    echo "✅ Python virtual environment: Ready"
else
    echo "❌ Python virtual environment: Missing"
fi

# Check if ngrok is configured
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok configuration: Valid"
else
    echo "❌ Ngrok configuration: Not configured"
    echo "   Run: ngrok config add-authtoken YOUR_TOKEN"
fi

# Check if Django is working
if [ -f "manage.py" ]; then
    echo "✅ Django project: Found"
    # Quick test
    cd /workspace
    source venv/bin/activate 2>/dev/null
    export USE_SQLITE=true
    if python manage.py check --quiet 2>/dev/null; then
        echo "✅ Django configuration: Valid"
    else
        echo "⚠️  Django configuration: Needs attention"
    fi
else
    echo "❌ Django project: Not found"
fi

# Check if admin user exists
if [ -f "db.sqlite3" ]; then
    echo "✅ Database: Present"
else
    echo "⚠️  Database: Needs migration"
fi

echo ""
echo "📁 Available Scripts:"
echo "===================="
ls -la *.sh | grep -E "(start|stop|check|deploy|setup)" | awk '{print "📝 " $9 " - " $5 " bytes"}'

echo ""
echo "🚀 Quick Start Options:"
echo "======================"
echo "1. 🌍 Static URL (Recommended):"
echo "   ./start_noctispro_static.sh"
echo ""
echo "2. 🔄 Dynamic URL:"
echo "   ./start_noctispro_simple.sh"
echo ""
echo "3. 🏠 Local Only:"
echo "   source venv/bin/activate"
echo "   export USE_SQLITE=true && python manage.py runserver 0.0.0.0:8000"
echo ""
echo "4. 🔧 Complete Redeployment:"
echo "   sudo ./quick_deploy_fixed.sh"
echo ""

echo "🌐 Expected URLs:"
echo "================"
echo "📱 Static URLs:"
echo "   https://noctispro-live.ngrok-free.app"
echo "   https://noctispro-production.ngrok-free.app"
echo ""
echo "🔧 Admin Panel:"
echo "   [YOUR_URL]/admin/"
echo ""
echo "🏠 Local Access:"
echo "   http://localhost:8000"
echo ""

echo "🔑 Admin Credentials:"
echo "===================="
echo "Username: admin"
echo "Password: admin123"
echo "Email: admin@noctispro.local"
echo ""

echo "📋 Status Check Commands:"
echo "========================"
echo "• Check processes: ps aux | grep -E '(python|ngrok)'"
echo "• Check ngrok: curl -s http://localhost:4040/api/tunnels"
echo "• Check Django: curl -s http://localhost:8000/health/"
echo "• Check admin: curl -s http://localhost:8000/admin/"
echo ""

echo "🛑 Stop Commands:"
echo "================"
echo "• Stop services: ./stop_noctispro_simple.sh"
echo "• Kill processes: pkill -f 'manage.py'; pkill -f 'ngrok'"
echo ""

echo "📚 Documentation:"
echo "=================="
echo "📖 Complete Guide: cat COMPLETE_DEPLOYMENT_GUIDE.md"
echo "🔧 Quick Deploy: cat quick_deploy_fixed.sh"
echo ""

# Check if any services are currently running
echo "🔍 Current Status:"
echo "=================="
if pgrep -f "manage.py runserver" > /dev/null; then
    DJANGO_PID=$(pgrep -f "manage.py runserver")
    echo "✅ Django server is running (PID: $DJANGO_PID)"
    echo "   Local: http://localhost:8000"
else
    echo "⭕ Django server is not running"
fi

if pgrep -f "ngrok" > /dev/null; then
    NGROK_PID=$(pgrep -f "ngrok")
    echo "✅ Ngrok tunnel is running (PID: $NGROK_PID)"
    # Try to get tunnel URL
    TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o 'https://[^"]*ngrok[^"]*' | head -1)
    if [ -n "$TUNNEL_URL" ]; then
        echo "   Public: $TUNNEL_URL"
    fi
else
    echo "⭕ Ngrok tunnel is not running"
fi

echo ""
echo "🎯 Ready to deploy! Choose a start option above. 🚀"