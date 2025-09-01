#!/bin/bash
echo "🚀 Starting NoctisPro Production..."
cd /workspace
source venv/bin/activate

# Start Django server
echo "🖥️ Starting Django server..."
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!
echo $DJANGO_PID > django.pid
echo "Django PID: $DJANGO_PID"

# Wait for Django to start
sleep 8

# Test Django
if curl -s http://localhost:8000/ > /dev/null; then
    echo "✅ Django server started successfully"
else
    echo "❌ Django server failed to start"
    kill $DJANGO_PID 2>/dev/null
    exit 1
fi

# Start ngrok
echo "🌐 Starting ngrok tunnel..."
./ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout > ngrok.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > ngrok.pid
echo "Ngrok PID: $NGROK_PID"

# Wait for ngrok to connect
sleep 10

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "================================"
echo "🌐 Your app is live at: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 Login credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📊 Monitoring:"
echo "   Django logs: tail -f noctis_pro.log"
echo "   Ngrok logs: tail -f ngrok.log"
echo ""
echo "🛑 To stop: ./stop_noctispro.sh"
