#!/bin/bash

echo "🚀 Starting Noctis Pro Medical Imaging System (Development Mode)..."

# Change to application directory
cd "$(dirname "$0")"

# Load environment variables
set -a
source .env.development
set +a

# Activate virtual environment
source venv/bin/activate

# Start Django development server
echo "🌐 Starting Django development server..."
echo ""
echo "✅ Noctis Pro is now running in development mode!"
echo ""
echo "🌐 Access Information:"
echo "====================="
echo "Web Interface: http://localhost:8000"
echo "Admin Interface: http://localhost:8000/admin"
echo ""
echo "👤 Admin Login:"
echo "==============="
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "📝 Press Ctrl+C to stop the server"
echo ""

python manage.py runserver 0.0.0.0:8000
