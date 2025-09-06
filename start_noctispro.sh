#!/bin/bash

# NoctisPro PACS - Simple Startup Script
# This script starts the NoctisPro PACS system in the background

cd /workspace

echo "🚀 Starting NoctisPro PACS..."
echo "================================"

# Activate virtual environment
source venv_optimized/bin/activate

# Set environment variables
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
export DEBUG=False

# Create logs directory
mkdir -p logs

# Stop any existing processes
echo "Stopping any existing services..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "dicom_receiver.py" 2>/dev/null || true
sleep 2

# Start web service
echo "Starting web service..."
nohup gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 noctis_pro.wsgi:application > logs/web.log 2>&1 &
WEB_PID=$!
echo $WEB_PID > logs/web.pid
echo "✅ Web service started (PID: $WEB_PID)"

# Start DICOM receiver
echo "Starting DICOM receiver..."
nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
DICOM_PID=$!
echo $DICOM_PID > logs/dicom.pid
echo "✅ DICOM receiver started (PID: $DICOM_PID)"

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 10

# Health checks
echo ""
echo "🔍 Performing health checks..."
echo "================================"

# Test web service
if curl -f -s --max-time 10 "http://localhost:8000/" >/dev/null 2>&1; then
    echo "✅ Web service is responding"
    WEB_STATUS="✅ Healthy"
else
    echo "❌ Web service is not responding"
    WEB_STATUS="❌ Not responding"
fi

# Test DICOM port
if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
    echo "✅ DICOM port is accessible"
    DICOM_STATUS="✅ Accessible"
else
    echo "❌ DICOM port is not accessible"
    DICOM_STATUS="❌ Not accessible"
fi

# Display summary
echo ""
echo "🎉 NoctisPro PACS Deployment Summary"
echo "===================================="
echo "Web Service:    $WEB_STATUS"
echo "DICOM Service:  $DICOM_STATUS"
echo ""
echo "🌐 Access Information:"
echo "   Web Interface: http://localhost:8000"
echo "   Admin Panel:   http://localhost:8000/admin/"
echo "   DICOM Port:    localhost:11112"
echo "   Default Login: admin / admin123"
echo ""
echo "📁 Service Management:"
echo "   Start Services: ./start_noctispro.sh"
echo "   Stop Services:  ./stop_noctispro.sh"
echo "   View Logs:      tail -f logs/web.log logs/dicom.log"
echo "   Service Status: ps aux | grep -E '(gunicorn|dicom_receiver)'"
echo ""
echo "🚀 NoctisPro PACS is ready!"