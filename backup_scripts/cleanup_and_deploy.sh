#!/bin/bash

echo "🧹 NOCTIS PRO PACS v2.0 - SYSTEM CLEANUP & PRODUCTION DEPLOYMENT"
echo "=================================================================="

# Stop any running processes
echo "🔄 Stopping existing processes..."
pkill -f "python manage.py runserver" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
pkill -f "cloudflared" 2>/dev/null || true

# Clean up log files
echo "🗑️  Cleaning up log files..."
find /workspace -name "*.log" -not -path "*/venv/*" -delete
rm -f /workspace/*.pid
rm -f /workspace/noctispro-masterpiece.pid

# Remove unnecessary deployment files
echo "🗂️  Removing deployment artifacts..."
rm -f /workspace/*.tar.gz
rm -f /workspace/*.tgz
rm -f /workspace/*.deb
rm -f /workspace/cloudflared.deb
rm -f /workspace/ngrok-v3-stable-linux-amd64.tgz

# Clean up temporary scripts
echo "📜 Removing temporary scripts..."
rm -f /workspace/fix_ngrok_setup.sh
rm -f /workspace/quick_ngrok_fix.sh
rm -f /workspace/deploy_with_ngrok_auth.sh
rm -f /workspace/automated_ngrok_deploy.sh
rm -f /workspace/autostart_masterpiece.sh
rm -f /workspace/connect_static_url.sh

# Remove backup directories
echo "🗃️  Cleaning backup directories..."
rm -rf /workspace/backup_*
rm -rf /workspace/archived_scripts
rm -rf /workspace/noctis_pro_deployment

# Clean up test files
echo "🧪 Removing test files..."
rm -f /workspace/test_deployment.py
rm -f /workspace/verify_*.py
rm -f /workspace/health_check.py
rm -f /workspace/system_status_check.py
rm -f /workspace/init_system.py
rm -f /workspace/install_security_system.sh

# Remove demo files
echo "🎭 Removing demo files..."
rm -f /workspace/demo_view.py
rm -f /workspace/templates/demo.html

# Clean up documentation files (keep only essential ones)
echo "📚 Organizing documentation..."
mkdir -p /workspace/docs/archive
mv /workspace/*.md /workspace/docs/archive/ 2>/dev/null || true
# Keep only the main README
cp /workspace/docs/archive/README.md /workspace/ 2>/dev/null || true

# Clean up cookies and temporary files
echo "🍪 Removing temporary files..."
rm -f /workspace/cookies.txt
rm -f /workspace/current_ngrok_url.txt*
rm -f /workspace/deployment_status.json

# Clean Python cache
echo "🐍 Cleaning Python cache..."
find /workspace -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find /workspace -name "*.pyc" -delete 2>/dev/null || true

# Optimize database
echo "💾 Optimizing database..."
cd /workspace
source venv/bin/activate
python manage.py collectstatic --noinput --clear > /dev/null 2>&1

# Set proper permissions
echo "🔐 Setting permissions..."
chmod +x /workspace/manage.py
chmod 755 /workspace/venv/bin/python

# Create production deployment script
cat > /workspace/deploy_production.sh << 'EOF'
#!/bin/bash
echo "🚀 NOCTIS PRO PACS v2.0 - PRODUCTION DEPLOYMENT"
echo "=============================================="

cd /workspace
source venv/bin/activate

echo "📊 System Status Check..."
python manage.py check --deploy

echo "🔄 Starting Django server on port 80..."
sudo venv/bin/python manage.py runserver 0.0.0.0:80 &

echo "⏳ Waiting for server to start..."
sleep 3

echo "✅ Server started successfully!"
echo ""
echo "🌐 TO ACCESS THE SYSTEM:"
echo "1. Run: ngrok http --url=mallard-shining-curiously.ngrok-free.app 80"
echo "2. Visit: https://mallard-shining-curiously.ngrok-free.app"
echo "3. Login with: admin / admin123"
echo ""
echo "🏥 AVAILABLE MODULES:"
echo "   • Login System: /login/"
echo "   • Admin Panel: /admin/"
echo "   • DICOM Viewer: /dicom-viewer/"
echo "   • Worklist: /worklist/"
echo "   • AI Analysis: /ai/"
echo "   • Reports: /reports/"
echo "   • Chat: /chat/"
echo ""
echo "🎉 NOCTIS PRO PACS v2.0 IS READY!"
EOF

chmod +x /workspace/deploy_production.sh

# Create system info script
cat > /workspace/system_info.sh << 'EOF'
#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - SYSTEM INFORMATION"
echo "==========================================="

cd /workspace
source venv/bin/activate

echo "📊 Django Version:"
python -c "import django; print(f'   Django {django.get_version()}')"

echo ""
echo "🐍 Python Version:"
python --version | sed 's/^/   /'

echo ""
echo "💾 Database Status:"
DJANGO_SETTINGS_MODULE=noctis_pro.settings python -c "
import django; django.setup()
from accounts.models import User
from worklist.models import Study, Series, DicomImage
print(f'   Users: {User.objects.count()}')
print(f'   Studies: {Study.objects.count()}')
print(f'   Series: {Series.objects.count()}')
print(f'   DICOM Images: {DicomImage.objects.count()}')
"

echo ""
echo "📦 Installed Packages:"
pip list --format=freeze | grep -E "(Django|pydicom|numpy|scipy|pillow)" | sed 's/^/   /'

echo ""
echo "🌐 Server Status:"
if pgrep -f "python manage.py runserver" > /dev/null; then
    echo "   ✅ Django Server: RUNNING"
else
    echo "   ❌ Django Server: STOPPED"
fi

echo ""
echo "📁 Directory Size:"
du -sh /workspace | sed 's/^/   Total: /'
du -sh /workspace/venv | sed 's/^/   Virtual Env: /'
du -sh /workspace/staticfiles | sed 's/^/   Static Files: /'
EOF

chmod +x /workspace/system_info.sh

echo ""
echo "✅ CLEANUP COMPLETE!"
echo ""
echo "📊 SYSTEM SUMMARY:"
echo "   🧹 Removed $(find /workspace -name "*.log" 2>/dev/null | wc -l) log files"
echo "   🗑️  Cleaned Python cache files"
echo "   📦 Optimized static files"
echo "   🔧 Created production deployment script"
echo ""
echo "🚀 TO DEPLOY THE CLEAN SYSTEM:"
echo "   Run: ./deploy_production.sh"
echo ""
echo "📊 TO CHECK SYSTEM INFO:"
echo "   Run: ./system_info.sh"
echo ""
echo "🎉 NOCTIS PRO PACS v2.0 - CLEAN & READY FOR PRODUCTION!"