#!/bin/bash
echo "🚀 Starting NoctisPro Production..."

cd /workspace
source venv/bin/activate

# Load environment variables
source .env.production
source .env.ngrok

# Create necessary directories
mkdir -p media/dicom staticfiles

# Start Django server in background
echo "🌐 Starting Django server on port 8000..."
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!
echo "Django PID: $DJANGO_PID"

# Wait a bit for Django to start
sleep 10

# Start ngrok tunnel
echo "🚇 Starting ngrok tunnel..."
if [ "$NGROK_USE_STATIC" = "true" ] && [ ! -z "$NGROK_STATIC_URL" ]; then
    ngrok http 8000 --hostname=$NGROK_STATIC_URL --log=stdout &
else
    ngrok http 8000 --log=stdout &
fi
NGROK_PID=$!
echo "Ngrok PID: $NGROK_PID"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down services..."
    kill $DJANGO_PID 2>/dev/null || true
    kill $NGROK_PID 2>/dev/null || true
    echo "✅ Services stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo ""
echo "🎉 SERVICES STARTED!"
echo ""
echo "🌐 Application URLs:"
echo "✅ Main App: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin Panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 DICOM Viewer: https://colt-charmed-lark.ngrok-free.app/dicom-viewer/"
echo "📋 Worklist: https://colt-charmed-lark.ngrok-free.app/worklist/"
echo "🏠 Local Access: http://localhost:8000"
echo ""
echo "🔑 Admin Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Press Ctrl+C to stop all services"
echo ""

# Wait for background processes
wait
