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
