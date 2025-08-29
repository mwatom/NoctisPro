#!/bin/bash

# 🚀 NoctisPro Start with Static Ngrok URL
# Uses configured static subdomain

echo "🚀 Starting NoctisPro with Static URL..."

# Navigate to project directory
cd /workspace

# Activate virtual environment
source venv/bin/activate

# Set environment variables
export USE_SQLITE=true
export DEBUG=False
export SECRET_KEY=noctis-production-secret-2024-change-me
export ALLOWED_HOSTS=*,noctispro-live.ngrok-free.app,noctispro-production.ngrok-free.app,localhost,127.0.0.1
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

# Function to start Django server in background
start_django() {
    echo "🌐 Starting Django server on port 8000..."
    python manage.py runserver 0.0.0.0:8000 &
    DJANGO_PID=$!
    echo "Django PID: $DJANGO_PID"
    sleep 5
}

# Function to start ngrok tunnel with static subdomain
start_ngrok() {
    echo "🚇 Starting ngrok tunnel with static URL..."
    if ngrok start noctispro > /dev/null 2>&1 &
    then
        NGROK_PID=$!
        echo "Ngrok PID: $NGROK_PID"
        sleep 3
        # Try to get the tunnel URL
        TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*ngrok[^"]*' | head -1)
        if [ -n "$TUNNEL_URL" ]; then
            echo "✅ Tunnel established: $TUNNEL_URL"
        else
            echo "⚠️  Tunnel started but URL not immediately available"
            echo "   Static URL should be: https://noctispro-live.ngrok-free.app"
        fi
    else
        echo "❌ Failed to start ngrok tunnel with static subdomain"
        echo "🔄 Trying fallback subdomain..."
        ngrok start noctispro-alt > /dev/null 2>&1 &
        NGROK_PID=$!
        echo "Ngrok PID: $NGROK_PID (fallback)"
        sleep 3
        echo "   Fallback URL should be: https://noctispro-production.ngrok-free.app"
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
echo "🎉 NoctisPro is now running with Static URLs!"
echo ""
echo "🌐 Application URLs:"
echo "✅ Primary URL: https://noctispro-live.ngrok-free.app"
echo "🔄 Fallback URL: https://noctispro-production.ngrok-free.app"
echo "🔧 Admin Panel: https://noctispro-live.ngrok-free.app/admin/"
echo "📱 DICOM Viewer: https://noctispro-live.ngrok-free.app/dicom-viewer/"
echo "📋 Worklist: https://noctispro-live.ngrok-free.app/worklist/"
echo "🏠 Local Access: http://localhost:8000"
echo "🔍 Ngrok Inspector: http://localhost:4040"
echo ""
echo "🔑 Admin Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Press Ctrl+C to stop all services"
echo ""

# Wait for background processes
wait