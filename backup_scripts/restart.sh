#!/bin/bash
echo "🔄 Restarting NOCTIS PRO PACS services..."
/workspace/keep_services_running.sh
sleep 5
echo "✅ Services restarted!"
/workspace/status.sh
