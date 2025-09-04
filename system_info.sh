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
