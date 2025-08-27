#!/bin/bash

echo "🌟 Starting NoctisPro Production Server with Ngrok"
echo "=================================================="

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

# Navigate to workspace (use current directory)
cd "$(dirname "$0")"

# Activate virtual environment
source venv/bin/activate

# Load production environment
source .env.production

# Run migrations
echo "🔄 Running database migrations..."
python manage.py migrate

# Collect static files
echo "🔄 Collecting static files..."
python manage.py collectstatic --noinput

# Start ngrok in background
echo "🌐 Starting ngrok tunnel..."
ngrok http 8000 --log=stdout > ngrok.log 2>&1 &
NGROK_PID=$!

# Wait a moment for ngrok to start
sleep 3

# Get ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
")

if [ ! -z "$NGROK_URL" ]; then
    echo "🌍 Ngrok tunnel active: $NGROK_URL"
    echo "🌍 Local access: http://localhost:8000"
else
    echo "⚠️  Could not get ngrok URL - check ngrok.log"
fi

echo ""
echo "🔥 Django server starting..."
echo "   Press Ctrl+C to stop both Django and ngrok"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    kill $NGROK_PID 2>/dev/null
    echo "✅ Ngrok stopped"
    exit 0
}

# Set trap to cleanup on exit
trap cleanup SIGINT SIGTERM

# Start Django server
python manage.py runserver 0.0.0.0:8000

# Cleanup when Django exits
cleanup