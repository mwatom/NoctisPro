#!/bin/bash

# Final Emergency Deployment Script for NoctisPro
# Fixed version to resolve syntax errors

set -e

echo "🔹 Stopping any process on port 8000..."
# Kill any process using port 8000
sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
sleep 2

echo "🔹 Activating virtual environment..."
# Check if we're in the right directory
if [ -f "manage.py" ]; then
    echo "✅ Found manage.py in current directory"
else
    # Try to find the correct directory
    if [ -d "/home/noctispro/NoctisPro" ]; then
        cd /home/noctispro/NoctisPro
        echo "✅ Changed to /home/noctispro/NoctisPro"
    else
        echo "❌ Could not find NoctisPro directory"
        exit 1
    fi
fi

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "❌ Virtual environment not found"
    exit 1
fi

echo "🔹 Installing/updating dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "🔹 Running migrations..."
python manage.py migrate --noinput

echo "🔹 Creating admin user if missing..."
# Use heredoc syntax to avoid shell parsing issues
python manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('✅ Admin user created: admin/admin123')
else:
    print('✅ Admin user already exists')
EOF

echo "🔹 Collecting static files..."
python manage.py collectstatic --noinput --clear

echo "🔹 Starting Django development server..."
echo "🌟 NoctisPro will be available at: http://localhost:8000"
echo "🔑 Admin credentials: admin / admin123"
echo ""
echo "🚀 Starting server now..."

# Start the Django development server
python manage.py runserver 0.0.0.0:8000