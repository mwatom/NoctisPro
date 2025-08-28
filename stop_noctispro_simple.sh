#!/bin/bash

# 🛑 NoctisPro Simple Stop Script
# Stops Django and ngrok processes

echo "🛑 Stopping NoctisPro services..."

# Kill Django development server
echo "Stopping Django server..."
pkill -f "manage.py runserver" || echo "Django server not running"

# Kill ngrok
echo "Stopping ngrok tunnel..."
pkill -f "ngrok" || echo "Ngrok not running"

echo "✅ All services stopped"