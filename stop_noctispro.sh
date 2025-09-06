#!/bin/bash

# NoctisPro PACS - Simple Stop Script
# This script stops all NoctisPro PACS services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
cd "$PROJECT_DIR"

echo "🛑 Stopping NoctisPro PACS..."
echo "==============================="

# Stop web service
if [[ -f logs/web.pid ]]; then
    WEB_PID=$(cat logs/web.pid)
    if kill -0 "$WEB_PID" 2>/dev/null; then
        kill "$WEB_PID"
        echo "✅ Web service stopped (PID: $WEB_PID)"
    else
        echo "ℹ️  Web service was not running"
    fi
    rm -f logs/web.pid
else
    echo "ℹ️  No web service PID file found"
fi

# Stop DICOM receiver
if [[ -f logs/dicom.pid ]]; then
    DICOM_PID=$(cat logs/dicom.pid)
    if kill -0 "$DICOM_PID" 2>/dev/null; then
        kill "$DICOM_PID"
        echo "✅ DICOM receiver stopped (PID: $DICOM_PID)"
    else
        echo "ℹ️  DICOM receiver was not running"
    fi
    rm -f logs/dicom.pid
else
    echo "ℹ️  No DICOM receiver PID file found"
fi

# Kill any remaining processes
echo "Cleaning up any remaining processes..."
pkill -f "manage.py runserver" 2>/dev/null && echo "✅ Stopped Django runserver processes"
pkill -f "dicom_receiver.py" 2>/dev/null && echo "✅ Stopped DICOM receiver processes"
pkill -f "gunicorn.*noctis_pro" 2>/dev/null && echo "✅ Stopped Gunicorn processes"

echo ""
echo "🔴 All NoctisPro PACS services have been stopped"