#!/bin/bash

# NoctisPro PACS - Simple Startup Script
# This script starts the NoctisPro PACS system in the background

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
cd "$PROJECT_DIR"

echo "🚀 Starting NoctisPro PACS..."
echo "================================"

# Activate or create virtual environment (auto-detect Python)
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
elif [ -f "venv_optimized/bin/activate" ]; then
    source venv_optimized/bin/activate
else
    echo "ℹ️  Virtual environment not found. Creating one..."
    PYTHON_BIN=""
    for candidate in python3.12 python3.11 python3.10 python3; do
        if command -v "$candidate" >/dev/null 2>&1; then
            PYTHON_BIN="$candidate"
            break
        fi
    done
    if [ -z "$PYTHON_BIN" ]; then
        echo "❌ No suitable Python 3 interpreter found. Please install Python 3.10+ and retry."
        exit 1
    fi
    "$PYTHON_BIN" -m venv venv
    source venv/bin/activate
    pip install --upgrade pip setuptools wheel
    if [ -f requirements.txt ]; then
        pip install -r requirements.txt || true
    fi
fi

# Load .env if present and set defaults
if [ -f ./.env ]; then
    set -a
    . ./.env
    set +a
fi

# Set environment variables
export DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE:-noctis_pro.settings}
export DEBUG=${DEBUG:-False}

# If NGROK_URL is provided and STATIC_URL not set, derive STATIC_URL
if [ -n "${NGROK_URL}" ] && [ -z "${STATIC_URL}" ]; then
    NGROK_BASE=${NGROK_URL%/}
    export STATIC_URL="${NGROK_BASE}/static/"
fi

# Create logs directory
mkdir -p logs

# Start-only mode: do not stop existing processes

# Start web service
echo "Starting web service (start-only)..."
if [ -f logs/web.pid ] && kill -0 "$(cat logs/web.pid)" 2>/dev/null; then
    echo "ℹ️  Web service already running (PID: $(cat logs/web.pid))"
else
    [ -f logs/web.pid ] && rm -f logs/web.pid
    nohup gunicorn --bind 0.0.0.0:8080 --workers 4 --timeout 120 noctis_pro.wsgi:application > logs/web.log 2>&1 &
    WEB_PID=$!
    echo $WEB_PID > logs/web.pid
    echo "✅ Web service started (PID: $WEB_PID) on :8080"
fi

# Start DICOM receiver (start-only)
echo "Starting DICOM receiver (start-only)..."
if [ -f logs/dicom.pid ] && kill -0 "$(cat logs/dicom.pid)" 2>/dev/null; then
    echo "ℹ️  DICOM receiver already running (PID: $(cat logs/dicom.pid))"
else
    [ -f logs/dicom.pid ] && rm -f logs/dicom.pid
    nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
    DICOM_PID=$!
    echo $DICOM_PID > logs/dicom.pid
    echo "✅ DICOM receiver started (PID: $DICOM_PID)"
fi

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 10

# Health checks
echo ""
echo "🔍 Performing health checks..."
echo "================================"

# Test web service
if curl -f -s --max-time 10 "http://localhost:8080/" >/dev/null 2>&1; then
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
echo "   Web Interface: http://localhost:8080"
echo "   Admin Panel:   http://localhost:8080/admin/"
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