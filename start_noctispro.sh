#!/bin/bash

# Noctis Pro PACS - Simple Startup Script (No sudo required)
# This script starts the system with the current fixes

set -e

echo "🚀 Starting Noctis Pro PACS..."
echo "================================"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the right directory
if [[ ! -f "manage.py" ]]; then
    echo "Error: This script must be run from the Django project root directory"
    exit 1
fi

print_header "1. Environment Setup"

# Set environment variables for this session
export DEBUG=True
export USE_SQLITE=True
export DATABASE_PATH="/workspace/db.sqlite3"
export SERVE_MEDIA_FILES=True

print_status "Environment configured"

print_header "2. Installing Dependencies (User Mode)"

# Try to install dependencies in user mode if needed
if ! python3 -c "import django" 2>/dev/null; then
    print_status "Installing Django in user mode..."
    python3 -m pip install --user django djangorestframework pillow numpy pydicom python-decouple django-cors-headers channels daphne
fi

print_header "3. Database Setup"

# Run migrations
print_status "Running database migrations..."
python3 manage.py makemigrations --noinput 2>/dev/null || echo "No new migrations"
python3 manage.py migrate --noinput

print_header "4. Static Files"

# Create directories
mkdir -p staticfiles/css staticfiles/js media/dicom

# Collect static files
print_status "Collecting static files..."
python3 manage.py collectstatic --noinput --clear

print_header "5. Creating Admin User"

# Create superuser if needed
python3 manage.py shell << 'EOF'
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    if not User.objects.filter(username='admin').exists():
        User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
        print('✅ Superuser created: admin/admin123')
    else:
        print('✅ Superuser already exists')
except Exception as e:
    print(f'Note: {e}')
EOF

print_header "6. Starting Server"

# Kill any existing Django processes
pkill -f "manage.py runserver" 2>/dev/null || true
sleep 2

print_status "Starting Django development server..."

# Start the server in the background
nohup python3 manage.py runserver 0.0.0.0:8000 > noctis_pro.log 2>&1 &
SERVER_PID=$!

# Wait a moment for server to start
sleep 3

# Check if server is running
if kill -0 $SERVER_PID 2>/dev/null; then
    print_status "Server started successfully (PID: $SERVER_PID)"
else
    echo "❌ Server failed to start. Check noctis_pro.log for details."
    exit 1
fi

print_header "7. System Ready!"

echo ""
echo "🎉 Noctis Pro PACS is now running!"
echo "=================================="
echo ""
echo "🌐 Access URLs:"
echo "   • Main Application: http://localhost:8000"
echo "   • Admin Interface:  http://localhost:8000/admin"
echo "   • Health Check:     http://localhost:8000/health/"
echo ""
echo "🔐 Login Credentials:"
echo "   • Username: admin"
echo "   • Password: admin123"
echo ""
echo "📊 Server Process ID: $SERVER_PID"
echo "📋 Log File: noctis_pro.log"
echo ""
echo "🔧 Useful Commands:"
echo "   • View logs:    tail -f noctis_pro.log"
echo "   • Stop server:  kill $SERVER_PID"
echo "   • Restart:      ./start_noctispro.sh"
echo ""

# Test the server
print_status "Testing server connection..."
sleep 2
if curl -s http://localhost:8000/health/simple/ >/dev/null 2>&1; then
    echo "✅ Server is responding correctly"
else
    echo "⚠️  Server may still be starting up..."
fi

echo ""
echo "🚀 System is ready for use!"
echo ""
echo "To stop the server, run: kill $SERVER_PID"
echo "To view real-time logs, run: tail -f noctis_pro.log"