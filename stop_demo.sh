#!/bin/bash

# Stop the Noctis Pro PACS demo server

echo "🛑 Stopping Noctis Pro PACS Demo Server..."

# Kill the Django runserver processes
pkill -f "python3 manage.py runserver"

echo "✅ Demo server stopped"