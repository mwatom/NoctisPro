#!/bin/bash
# NoctisPro Masterpiece Auto-Start Script

cd /workspace/noctis_pro_deployment
source venv/bin/activate
nohup python manage.py runserver 0.0.0.0:8000 > /workspace/masterpiece_autostart.log 2>&1 &

echo "NoctisPro Masterpiece started at $(date)" >> /workspace/masterpiece_autostart.log