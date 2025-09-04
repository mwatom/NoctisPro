#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - PRODUCTION SYSTEM STATUS"
echo "================================================="

cd /workspace
source venv/bin/activate

echo "📊 Django Version:"
python -c "import django; print(f'   Django {django.get_version()}')"

echo ""
echo "🐍 Python Version:"
python --version | sed 's/^/   /'

echo ""
echo "💾 Production Database:"
DJANGO_SETTINGS_MODULE=noctis_pro.settings python -c "
import django; django.setup()
from accounts.models import User
from worklist.models import Study, Series, DicomImage
print(f'   System Users: {User.objects.count()}')
print(f'   Medical Studies: {Study.objects.count()}')
print(f'   Image Series: {Series.objects.count()}')
print(f'   DICOM Images: {DicomImage.objects.count()}')
"

echo ""
echo "📦 Core Medical Packages:"
pip list --format=freeze | grep -E "(Django|pydicom|numpy|scipy|pillow)" | sed 's/^/   /'

echo ""
echo "🌐 Server Status:"
if pgrep -f "python manage.py runserver" > /dev/null; then
    echo "   ✅ Medical Imaging Server: OPERATIONAL"
else
    echo "   ❌ Medical Imaging Server: OFFLINE"
fi

echo ""
echo "📁 System Storage:"
du -sh /workspace | sed 's/^/   Total System: /'
du -sh /workspace/venv | sed 's/^/   Core Platform: /'
du -sh /workspace/staticfiles | sed 's/^/   Web Assets: /'
du -sh /workspace/media 2>/dev/null | sed 's/^/   Medical Data: /' || echo "   Medical Data: Ready for uploads"
