#!/bin/bash
echo "🛑 Stopping NoctisPro Production..."
pkill -f "manage.py runserver" || echo "Django server not running"
pkill -f "ngrok" || echo "Ngrok not running"
echo "✅ Services stopped"
