#!/bin/bash

# NOCTIS PRO PACS DEMO STARTUP SCRIPT
# Use this script to start the system for your demo tonight

echo "🚀 Starting Noctis Pro PACS System for Demo..."

# Navigate to the application directory
cd /workspace/noctis_pro_deployment

# Set required environment variables
export PATH=$PATH:/home/ubuntu/.local/bin
export SECRET_KEY='django-insecure-demo-key-for-tonight-only'
export DJANGO_SETTINGS_MODULE='noctis_pro.settings_production'

# Create logs directory if it doesn't exist
mkdir -p logs

# Start the Django development server
echo "🔧 Starting Django server on http://localhost:8000"
python3 manage.py runserver 0.0.0.0:8000 &

# Wait a moment for server to start
sleep 5

# Test if server is responding
if curl -s http://localhost:8000/ > /dev/null; then
    echo "✅ Server is running successfully!"
    echo ""
    echo "🎯 DEMO ACCESS INFORMATION:"
    echo "   URL: http://localhost:8000"
    echo "   Demo User: demo"
    echo "   Password: demo123"
    echo ""
    echo "📋 Available endpoints:"
    echo "   • Login: http://localhost:8000/login/"
    echo "   • Worklist: http://localhost:8000/worklist/"
    echo "   • DICOM Viewer: http://localhost:8000/dicom-viewer/"
    echo "   • Admin Panel: http://localhost:8000/admin/"
    echo ""
    echo "🎉 System ready for demo!"
else
    echo "❌ Server failed to start properly"
    echo "Check the logs for errors"
fi