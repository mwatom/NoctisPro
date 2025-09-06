#!/bin/bash
# Simple service stopper for NoctisPro PACS

cd "/workspace"

echo "Stopping NoctisPro PACS services..."

# Stop web service
if [[ -f logs/web.pid ]]; then
    PID=$(cat logs/web.pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Web service stopped (PID: $PID)"
    else
        echo "Web service was not running"
    fi
    rm -f logs/web.pid
fi

# Stop DICOM receiver
if [[ -f logs/dicom.pid ]]; then
    PID=$(cat logs/dicom.pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "DICOM receiver stopped (PID: $PID)"
    else
        echo "DICOM receiver was not running"
    fi
    rm -f logs/dicom.pid
fi

echo "All services stopped"
