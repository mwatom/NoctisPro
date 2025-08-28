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

# Load ngrok environment configuration
if [ -f ".env.ngrok" ]; then
    source .env.ngrok
    echo "✅ Loaded ngrok environment configuration"
fi

# Run migrations
echo "🔄 Running database migrations..."
python manage.py migrate

# Collect static files
echo "🔄 Collecting static files..."
python manage.py collectstatic --noinput

# Check if ngrok is configured
echo "🌐 Checking ngrok configuration..."

# Check if ngrok auth token is configured
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok is configured - starting tunnel..."
    
    # Determine which tunnel to start based on configuration
    if [ "${NGROK_USE_STATIC:-false}" = "true" ]; then
        if [ ! -z "${NGROK_DOMAIN:-}" ]; then
            echo "🌐 Starting ngrok with custom domain: $NGROK_DOMAIN"
            ngrok start noctispro-domain --log=stdout > ngrok.log 2>&1 &
            TUNNEL_TYPE="custom domain"
            EXPECTED_URL="https://$NGROK_DOMAIN"
        elif [ ! -z "${NGROK_SUBDOMAIN:-}" ]; then
            echo "🌐 Starting ngrok with static subdomain: $NGROK_SUBDOMAIN"
            ngrok start noctispro-static --log=stdout > ngrok.log 2>&1 &
            TUNNEL_TYPE="static subdomain"
            EXPECTED_URL="https://$NGROK_SUBDOMAIN.ngrok.io"
        else
            echo "⚠️  Static URL requested but no subdomain/domain configured, using default"
            ngrok start ${NGROK_TUNNEL_NAME:-noctispro-http} --log=stdout > ngrok.log 2>&1 &
            TUNNEL_TYPE="random URL"
            EXPECTED_URL="(dynamic)"
        fi
    else
        echo "🌐 Starting ngrok with random URL"
        ngrok start ${NGROK_TUNNEL_NAME:-noctispro-http} --log=stdout > ngrok.log 2>&1 &
        TUNNEL_TYPE="random URL"
        EXPECTED_URL="(dynamic)"
    fi
    
    NGROK_PID=$!
    
    # Wait a moment for ngrok to start
    sleep 5
    
    # Get ngrok URL from API
    NGROK_URL=$(curl -s http://${NGROK_WEB_ADDR:-localhost:4040}/api/tunnels | python3 -c "
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
        echo "🌍 Ngrok tunnel active ($TUNNEL_TYPE): $NGROK_URL"
        echo "🌍 Local access: http://localhost:8000"
        
        # Save the URL for other scripts to use
        echo "$NGROK_URL" > .ngrok_url
        
        if [ "$EXPECTED_URL" != "(dynamic)" ] && [ "$NGROK_URL" = "$EXPECTED_URL" ]; then
            echo "✅ Static URL confirmed: $NGROK_URL"
        fi
    else
        echo "⚠️  Could not get ngrok URL - check ngrok.log"
        echo "   Expected: $EXPECTED_URL"
    fi
else
    echo "❌ Ngrok not configured!"
    echo ""
    echo "📋 To set up ngrok:"
    echo "   1. Sign up at: https://dashboard.ngrok.com/signup"
    echo "   2. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "   3. Run: ngrok config add-authtoken <your-token>"
    echo ""
    echo "🌍 For now, your server will be available at:"
    echo "   Local: http://localhost:8000"
    echo "   Network: http://$(hostname -I | awk '{print $1}'):8000"
    echo ""
    NGROK_PID=""
fi

echo ""
echo "🔥 Django server starting..."
echo "   Press Ctrl+C to stop both Django and ngrok"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    if [ ! -z "$NGROK_PID" ]; then
        kill $NGROK_PID 2>/dev/null
        echo "✅ Ngrok stopped"
    fi
    echo "✅ Django server stopped"
    exit 0
}

# Set trap to cleanup on exit
trap cleanup SIGINT SIGTERM

# Start Django server
python manage.py runserver 0.0.0.0:8000

# Cleanup when Django exits
cleanup