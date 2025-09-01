#!/bin/bash

# Fix for NoctisPro Deployment Issues
# This script fixes the common deployment issues

echo "🔧 Fixing NoctisPro Deployment Issues"
echo "====================================="

# Navigate to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# 2. Activate virtual environment and install dependencies
echo "📚 Installing dependencies..."
source venv/bin/activate
pip install -r requirements.txt
pip install dj-database-url scikit-image matplotlib opencv-python

# 3. Fix Django settings to use development settings
echo "⚙️ Configuring Django settings..."
sed -i "s/noctis_pro.settings_production/noctis_pro.settings/g" manage.py
sed -i "s/noctis_pro.settings_production/noctis_pro.settings/g" noctis_pro/asgi.py

# 4. Run Django checks and collect static files
echo "✅ Running Django system check..."
python manage.py check

echo "🎨 Collecting static files..."
python manage.py collectstatic --noinput

# 5. Start Daphne server
echo "🚀 Starting Daphne ASGI server..."
mkdir -p logs
daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application --access-log logs/daphne-access.log --verbosity 2 > logs/daphne.log 2>&1 &

# Get the PID and save it
DAPHNE_PID=$!
echo $DAPHNE_PID > daphne.pid

# Wait for server to start
sleep 5

# 6. Test the deployment
echo "🧪 Testing deployment..."
if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ Application is responding successfully!"
    echo ""
    echo "🎉 Deployment Fixed!"
    echo "==================="
    echo "• Application URL: http://localhost:8000"
    echo "• Health Check: http://localhost:8000/health/"
    echo "• Admin URL: http://localhost:8000/admin/"
    echo "• Process PID: $DAPHNE_PID"
    echo "• Logs: tail -f logs/daphne.log"
    echo ""
    echo "To stop the server: kill $DAPHNE_PID"
else
    echo "❌ Application is not responding. Check logs/daphne.log for details."
    exit 1
fi