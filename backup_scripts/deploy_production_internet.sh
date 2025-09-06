#!/bin/bash

# Production Internet Deployment for NoctisPro
# Deploy to internet using DuckDNS with Gunicorn for production

set -e

echo "🌍 PRODUCTION INTERNET DEPLOYMENT 🌍"
echo "====================================="
echo "🔗 Domain: noctispro2.duckdns.org"
echo "⚡ Using Gunicorn for production performance"
echo ""

# Kill any existing processes on port 8000
echo "🔹 Stopping any process on port 8000..."
sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
sudo pkill -f gunicorn 2>/dev/null || true
sleep 2

# Find and navigate to NoctisPro directory
if [ -f "manage.py" ]; then
    echo "✅ Found manage.py in current directory"
elif [ -d "/home/noctispro/NoctisPro" ]; then
    cd /home/noctispro/NoctisPro
    echo "✅ Changed to /home/noctispro/NoctisPro"
elif [ -d "/workspace" ]; then
    cd /workspace
    echo "✅ Using workspace directory"
else
    echo "❌ Could not find NoctisPro directory"
    exit 1
fi

# Activate virtual environment
if [ ! -f "venv/bin/activate" ]; then
    echo "❌ Error: Virtual environment not found. Creating new one..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
else
    echo "🔹 Activating virtual environment..."
    source venv/bin/activate
fi

# Update DuckDNS with current IP
echo "🔹 Updating DuckDNS with current IP..."
if [ -f "/workspace/update_duckdns.sh" ]; then
    /workspace/update_duckdns.sh
elif [ -f "update_duckdns.sh" ]; then
    ./update_duckdns.sh
fi

# Set production environment variables
echo "🔹 Setting production environment..."
export DEBUG=False
export SECRET_KEY="noctis-production-secret-$(date +%s)"
export ALLOWED_HOSTS="*,noctispro2.duckdns.org,*.duckdns.org,localhost,127.0.0.1,0.0.0.0"
export DJANGO_SETTINGS_MODULE="noctis_pro.settings"

# Run migrations
echo "🔹 Running database migrations..."
python manage.py migrate --noinput

# Create admin user if missing
echo "🔹 Creating admin user if missing..."
python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created successfully!')
else:
    print('✅ Admin user already exists')
EOF

# Collect static files
echo "🔹 Collecting static files..."
python manage.py collectstatic --noinput --clear

# Create media directories
echo "🔹 Setting up media directories..."
mkdir -p media/dicom media/uploads staticfiles logs
chmod -R 755 media staticfiles logs

# Create Gunicorn configuration
echo "🔹 Creating Gunicorn configuration..."
cat > gunicorn.conf.py << 'GUNICORN_EOF'
bind = "0.0.0.0:8000"
workers = 4
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2
user = None
group = None
tmp_upload_dir = None
errorlog = "logs/gunicorn_error.log"
accesslog = "logs/gunicorn_access.log"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'
loglevel = "info"
capture_output = True
enable_stdio_inheritance = True
GUNICORN_EOF

echo ""
echo "🎉 PRODUCTION DEPLOYMENT COMPLETE!"
echo "=================================="
echo ""
echo "🌍 Your NoctisPro is now accessible from anywhere:"
echo "   🔗 Main Site: http://noctispro2.duckdns.org:8000"
echo "   🔑 Admin Panel: http://noctispro2.duckdns.org:8000/admin/"
echo ""
echo "👤 Admin Login Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo "   Email: admin@noctispro.com"
echo ""
echo "⚡ Starting production server with Gunicorn..."
echo "   Press Ctrl+C to stop the server"
echo ""

# Start Gunicorn for production
gunicorn noctis_pro.wsgi:application -c gunicorn.conf.py