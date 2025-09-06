#!/bin/bash
# Simple service starter for NoctisPro PACS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
cd "$PROJECT_DIR"
source venv_optimized/bin/activate

echo "Starting NoctisPro PACS services..."

# Start web service
nohup gunicorn --bind 0.0.0.0:8000 --workers 8 --timeout 120 noctis_pro.wsgi:application > logs/web.log 2>&1 &
echo $! > logs/web.pid
echo "Web service started (PID: $(cat logs/web.pid))"

# Start DICOM receiver
nohup python dicom_receiver.py --port 11112 --aet NOCTIS_SCP > logs/dicom.log 2>&1 &
echo $! > logs/dicom.pid
echo "DICOM receiver started (PID: $(cat logs/dicom.pid))"

echo "All services started successfully"
echo "Web interface: http://localhost:8000"
echo "DICOM port: localhost:11112"
