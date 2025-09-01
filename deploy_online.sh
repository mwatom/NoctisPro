#!/bin/bash

# 🚀 Deploy NoctisPro Online with Static Ngrok URL
echo "🚀 Deploying NoctisPro online with ngrok static URL..."

# Set up environment variables
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export DEBUG=False
export ALLOWED_HOSTS="*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1"

cd /workspace

# Activate virtual environment
source venv/bin/activate

# Create production environment file
cat > .env.production << 'EOF'
DEBUG=False
SECRET_KEY=noctis-production-secret-2024-change-me
DJANGO_SETTINGS_MODULE=noctis_pro.settings
ALLOWED_HOSTS=*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1
USE_SQLITE=True
STATIC_ROOT=/workspace/staticfiles
MEDIA_ROOT=/workspace/media
SERVE_MEDIA_FILES=True
BUILD_TARGET=production
ENVIRONMENT=production
HEALTH_CHECK_ENABLED=True
TIME_ZONE=UTC
USE_TZ=True
DICOM_STORAGE_PATH=/workspace/media/dicom
EOF

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Run migrations
echo "🗄️ Running migrations..."
python manage.py migrate --noinput

# Create admin user if doesn't exist
echo "👤 Setting up admin user..."
echo "from accounts.models import User; User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell

# Start Django server in background
echo "🖥️ Starting Django server..."
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!
echo "Django PID: $DJANGO_PID"

# Wait for server to start
sleep 5

# Test if server is running
echo "🔍 Testing server..."
if curl -s http://localhost:8000/ > /dev/null; then
    echo "✅ Django server is running"
else
    echo "❌ Django server failed to start"
    kill $DJANGO_PID 2>/dev/null
    exit 1
fi

# Start ngrok with static URL
echo "🌐 Starting ngrok with static URL..."
./ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app --log=stdout &
NGROK_PID=$!
echo "Ngrok PID: $NGROK_PID"

# Wait for ngrok to start
sleep 10

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "================================"
echo "🌐 Access your app at: https://colt-charmed-lark.ngrok-free.app"
echo "🔧 Admin panel: https://colt-charmed-lark.ngrok-free.app/admin/"
echo "📱 Login credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🔄 To stop the deployment:"
echo "   kill $DJANGO_PID $NGROK_PID"
echo ""
echo "📊 To monitor:"
echo "   tail -f noctis_pro.log"
echo ""

# Create stop script
cat > stop_deployment.sh << EOF
#!/bin/bash
echo "🛑 Stopping deployment..."
kill $DJANGO_PID $NGROK_PID 2>/dev/null
echo "✅ Stopped"
EOF
chmod +x stop_deployment.sh

echo "💡 Run ./stop_deployment.sh to stop all services"