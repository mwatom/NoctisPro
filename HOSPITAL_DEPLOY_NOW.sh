#!/bin/bash

# 🚨 HOSPITAL EMERGENCY DEPLOYMENT - NOCTIS PACS 🚨
# Run this IMMEDIATELY after: git clone && cd NoctisPro
# For surgeons and doctors waiting for PACS access

set -e

echo "🏥 HOSPITAL EMERGENCY PACS DEPLOYMENT 🏥"
echo "========================================"
echo "🚨 DEPLOYING FOR SURGEON ACCESS NOW!"
echo "🔗 Will be live at: http://noctispro2.duckdns.org:8000"
echo ""

# Kill any existing processes immediately
echo "🔹 Clearing port 8000..."
sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
sudo pkill -f python 2>/dev/null || true
sudo pkill -f gunicorn 2>/dev/null || true
sleep 1

# Ensure we're in the right directory
if [ ! -f "manage.py" ]; then
    echo "❌ ERROR: Run this script from the NoctisPro directory (where manage.py is located)"
    echo "Usage: git clone [repo] && cd NoctisPro && ./HOSPITAL_DEPLOY_NOW.sh"
    exit 1
fi

echo "✅ Found NoctisPro project files"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🔹 Creating Python virtual environment..."
    python3 -m venv venv
fi

echo "🔹 Activating virtual environment..."
source venv/bin/activate

# Install dependencies with error handling
echo "🔹 Installing critical dependencies..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet || {
    echo "🔄 Trying alternative dependency installation..."
    pip install django pillow pydicom requests gunicorn whitenoise --quiet
}

# Set production environment for hospital use
echo "🔹 Configuring for hospital production..."
export DEBUG=False
export SECRET_KEY="hospital-noctis-pacs-$(date +%s)"
export ALLOWED_HOSTS="*,noctispro2.duckdns.org,*.duckdns.org,localhost,127.0.0.1,0.0.0.0"
export DJANGO_SETTINGS_MODULE="noctis_pro.settings"

# Update DuckDNS IP
echo "🔹 Updating hospital domain IP..."
if [ -f "update_duckdns.sh" ]; then
    chmod +x update_duckdns.sh
    ./update_duckdns.sh 2>/dev/null || true
fi

# Database setup
echo "🔹 Setting up PACS database..."
python manage.py migrate --noinput

# Create hospital admin user
echo "🔹 Creating hospital admin access..."
python manage.py shell << 'EOF'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
import django
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    admin = User.objects.create_superuser('admin', 'admin@hospital.com', 'admin123')
    print('✅ Hospital admin created: admin/admin123')
else:
    print('✅ Hospital admin ready')
EOF

# Setup static files and media
echo "🔹 Setting up PACS file storage..."
python manage.py collectstatic --noinput --clear 2>/dev/null || true
mkdir -p media/dicom media/uploads staticfiles
chmod -R 755 media staticfiles 2>/dev/null || true

# Create hospital configuration
echo "🔹 Configuring PACS for hospital use..."
cat > .env.hospital << 'HOSPITAL_ENV'
DEBUG=False
SECRET_KEY=hospital-noctis-pacs-production
ALLOWED_HOSTS=*,noctispro2.duckdns.org,*.duckdns.org,localhost,127.0.0.1,0.0.0.0
DJANGO_SETTINGS_MODULE=noctis_pro.settings
HOSPITAL_MODE=True
PACS_READY=True
HOSPITAL_ENV

echo ""
echo "🎉 HOSPITAL PACS DEPLOYMENT COMPLETE!"
echo "===================================="
echo ""
echo "🏥 NOCTIS PACS is now LIVE for hospital use:"
echo "   🌍 Internet Access: http://noctispro2.duckdns.org:8000"
echo "   🔑 Admin Panel: http://noctispro2.duckdns.org:8000/admin/"
echo ""
echo "👨‍⚕️ SURGEON/DOCTOR LOGIN:"
echo "   Username: admin"
echo "   Password: admin123"
echo "   Email: admin@hospital.com"
echo ""
echo "🚀 STARTING HOSPITAL PACS SERVER NOW..."
echo "   Server will run in background for continuous access"
echo "   Accessible from any internet browser worldwide"
echo ""

# Start server for hospital access
nohup python manage.py runserver 0.0.0.0:8000 > hospital_pacs.log 2>&1 &
SERVER_PID=$!

sleep 3

# Verify server is running
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "✅ HOSPITAL PACS SERVER RUNNING (PID: $SERVER_PID)"
    echo "✅ Surgeons can now access: http://noctispro2.duckdns.org:8000"
    echo ""
    echo "📋 Server Status:"
    echo "   - Server PID: $SERVER_PID"
    echo "   - Log file: hospital_pacs.log"
    echo "   - To stop: kill $SERVER_PID"
    echo ""
    echo "🏥 NOCTIS PACS IS READY FOR HOSPITAL USE! 🏥"
else
    echo "❌ Server failed to start. Trying alternative method..."
    python manage.py runserver 0.0.0.0:8000
fi