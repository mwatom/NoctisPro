#!/bin/bash

echo "🌟 Starting NoctisPro Production Server"
echo "======================================="

# Check if services are running
echo "📊 Checking services..."

# Check PostgreSQL
if sudo service postgresql status > /dev/null 2>&1; then
    echo "✅ PostgreSQL: Running"
else
    echo "🔄 Starting PostgreSQL..."
    sudo service postgresql start
fi

# Check Redis
if sudo service redis-server status > /dev/null 2>&1; then
    echo "✅ Redis: Running"
else
    echo "🔄 Starting Redis..."
    sudo service redis-server start
fi

echo ""
echo "🚀 Starting Django Production Server..."
echo "   Database: PostgreSQL (noctis_pro)"
echo "   Cache: Redis (localhost:6379)" 
echo "   Server: http://0.0.0.0:8000"
echo ""

# Navigate to workspace
cd /workspace

# Activate virtual environment
source venv/bin/activate

# Load production environment
source .env.production

# Start Django server
echo "🔥 Django server starting..."
echo "   Press Ctrl+C to stop"
echo "   Access at: http://localhost:8000"
echo ""

python manage.py runserver 0.0.0.0:8000