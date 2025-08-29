#!/bin/bash
echo "🛑 Stopping NoctisPro Production..."
sudo systemctl stop noctispro-production.service
echo "✅ Services stopped"
