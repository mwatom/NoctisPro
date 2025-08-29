#!/bin/bash
echo "🌟 Starting NoctisPro Production Server with Ngrok"
echo "=================================================="

# Go to project directory
cd "$(dirname "$0")" || exit

# 📊 Check PostgreSQL
echo "📊 Checking services..."
if systemctl is-active --quiet postgresql 2>/dev/null; then
  echo "✅ PostgreSQL: Running"
else
  echo "❌ PostgreSQL not running, starting..."
  sudo systemctl start postgresql 2>/dev/null || echo "⚠️ PostgreSQL service not available (will use SQLite)"
fi

# 📊 Check Redis
if systemctl is-active --quiet redis-server 2>/dev/null; then
  echo "✅ Redis: Running"
else
  echo "❌ Redis not running, starting..."
  sudo systemctl start redis-server 2>/dev/null || echo "⚠️ Redis service not available (will use dummy cache)"
fi

# 🚀 Setup Python Virtual Environment
if [ ! -d "venv" ]; then
  echo "⚙️ Creating Python virtual environment..."
  python3 -m venv venv
  if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment. Installing python3-venv..."
    sudo apt update && sudo apt install -y python3-venv
    python3 -m venv venv
  fi
fi

echo "✅ Virtual environment ready"

# Activate venv
source venv/bin/activate

# Install dependencies
if [ -f "requirements.txt" ]; then
  echo "📦 Installing dependencies..."
  pip install --upgrade pip
  pip install -r requirements.txt
else
  echo "⚠️ requirements.txt not found!"
fi

# Load production environment
if [ -f ".env.production" ]; then
  set -a  # automatically export all variables
  source .env.production
  set +a  # stop automatically exporting
  echo "✅ Loaded production environment configuration"
else
  echo "⚠️ .env.production not found, using defaults"
fi

# Load ngrok environment configuration
if [ -f ".env.ngrok" ]; then
    set -a  # automatically export all variables
    source .env.ngrok
    set +a  # stop automatically exporting
    echo "✅ Loaded ngrok environment configuration"
fi

# 🚀 Starting Django Production Server
echo "🚀 Starting Django Production Server..."
if [ "$USE_SQLITE" = "True" ]; then
  echo "   Database: SQLite (db.sqlite3)"
else
  echo "   Database: PostgreSQL (noctis_pro)"
fi

if [ "$USE_DUMMY_CACHE" = "True" ]; then
  echo "   Cache: Dummy Cache"
else
  echo "   Cache: Redis (localhost:6379)"
fi
echo "   Server: http://0.0.0.0:${DJANGO_PORT:-80}"

# Run migrations
echo "🔄 Running database migrations..."
python manage.py migrate

# Collect static files
echo "🔄 Collecting static files..."
python manage.py collectstatic --noinput

# 🌐 Start ngrok tunnel
echo "🌐 Checking ngrok configuration..."
if command -v ngrok &> /dev/null; then
  echo "✅ Ngrok is configured - starting tunnel..."
  
  # Check if a specific static URL is configured
  if [ -n "$NGROK_STATIC_URL" ]; then
    echo "🌐 Starting ngrok with specific static URL: $NGROK_STATIC_URL"
    nohup ngrok http --url=$NGROK_STATIC_URL ${DJANGO_PORT:-80} > /dev/null 2>&1 &
    sleep 3
    echo "🌍 Ngrok tunnel active (specific static URL): https://$NGROK_STATIC_URL"
    echo "✅ Static URL confirmed: https://$NGROK_STATIC_URL"
  else
    echo "🌐 Starting ngrok with default static URL: colt-charmed-lark.ngrok-free.app"
    nohup ngrok http --url=colt-charmed-lark.ngrok-free.app ${DJANGO_PORT:-80} > /dev/null 2>&1 &
    sleep 3
    echo "🌍 Ngrok tunnel active (specific static URL): https://colt-charmed-lark.ngrok-free.app"
    echo "✅ Static URL confirmed: https://colt-charmed-lark.ngrok-free.app"
  fi
  
  echo "🌍 Local access: http://localhost:${DJANGO_PORT:-80}"
else
  echo "❌ Ngrok not found! Install it first."
  exit 1
fi

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    # Kill ngrok
    pkill -f "ngrok http"
    if [ $? -eq 0 ]; then
        echo "✅ Ngrok stopped"
    fi
    echo "✅ Django server stopped"
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup SIGINT SIGTERM

# Run Django server
echo ""
echo "🔥 Django server starting..."
echo "   Press Ctrl+C to stop both Django and ngrok"
echo ""

# Start Django server
python manage.py runserver 0.0.0.0:${DJANGO_PORT:-80}