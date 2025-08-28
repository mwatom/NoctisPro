#!/bin/bash

# 🚀 NoctisPro Simple Start - No systemd required
# For container environments or when systemd is not available

echo "🚀 Starting NoctisPro Production (Simple Mode)..."

# Navigate to project directory
cd /workspace

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export USE_SQLITE=true
export DEBUG=False
export SECRET_KEY=noctis-production-secret-2024-change-me
export ALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1
export STATIC_ROOT=/workspace/staticfiles
export MEDIA_ROOT=/workspace/media
export SERVE_MEDIA_FILES=True
export HEALTH_CHECK_ENABLED=True
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true

# Create necessary directories
mkdir -p media/dicom staticfiles

# Collect static files
echo "📦 Collecting static files..."
python manage.py collectstatic --noinput

# Run migrations
echo "🗄️ Running database migrations..."
python manage.py migrate --noinput

# Create admin user if it doesn't exist
echo "👤 Ensuring admin user exists..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell

# Check if ngrok auth token is configured
if ! ngrok config check; then
    echo "⚠️  WARNING: Ngrok auth token not configured"
    echo "   Configure it with: ngrok config add-authtoken YOUR_TOKEN"
    echo "   You can get a free token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo ""
fi

# Function to start Django server in background
start_django() {
    echo "🌐 Starting Django server on port 8000..."
    python manage.py runserver 0.0.0.0:8000 &
    DJANGO_PID=$!
    echo "Django PID: $DJANGO_PID"
    sleep 5
}

# Function to start ngrok tunnel
start_ngrok() {
    echo "🚇 Starting ngrok tunnel..."
    if command -v ngrok >/dev/null 2>&1; then
        ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout &
        NGROK_PID=$!
        echo "Ngrok PID: $NGROK_PID"
    else
        echo "❌ Ngrok not found. Please install ngrok first."
        return 1
    fi
}

# Function to cleanup processes on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down services..."
    if [ ! -z "$DJANGO_PID" ]; then
        kill $DJANGO_PID 2>/dev/null || true
        echo "✅ Django server stopped"
    fi
    if [ ! -z "$NGROK_PID" ]; then
        kill $NGROK_PID 2>/dev/null || true
        echo "✅ Ngrok tunnel stopped"
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start services
start_django
start_ngrok

# Display access information
echo ""
echo "🎉 NoctisPro is now running!"
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