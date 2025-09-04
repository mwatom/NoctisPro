#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🔄 Restarting NOCTIS PRO PACS services..."
"${SCRIPT_DIR}/keep_services_running.sh"
sleep 5
echo "✅ Services restarted!"
"${SCRIPT_DIR}/status.sh"
