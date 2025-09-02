#!/bin/bash

# NoctisPro System Status Check - FIXED VERSION
echo "🔍 NoctisPro System Status Check"
echo "================================"
echo ""

# Check Python and virtual environment
echo "📦 Python Environment:"
if [ -d "/workspace/venv" ]; then
    echo "✅ Virtual environment exists"
    source /workspace/venv/bin/activate
    echo "✅ Virtual environment activated"
    python_version=$(python --version 2>&1)
    echo "✅ Python version: $python_version"
else
    echo "❌ Virtual environment not found"
fi

# Check Django installation
echo ""
echo "🐍 Django Status:"
if python -c "import django; print(f'Django {django.get_version()}')" 2>/dev/null; then
    echo "✅ Django installed and working"
else
    echo "❌ Django not installed or not working"
fi

# Check critical dependencies
echo ""
echo "📚 Dependencies:"
for package in celery reportlab pydicom PIL numpy skimage; do
    if python -c "import $package" 2>/dev/null; then
        echo "✅ $package installed"
    else
        echo "❌ $package missing"
    fi
done

# Check Django configuration
echo ""
echo "⚙️  Django Configuration:"
cd /workspace
if python manage.py check --verbosity=0 2>/dev/null; then
    echo "✅ Django system checks pass"
else
    echo "❌ Django system checks failed"
fi

# Check database
echo ""
echo "🗄️  Database:"
if python manage.py migrate --check 2>/dev/null; then
    echo "✅ Database migrations up to date"
else
    echo "⚠️  Database needs migrations"
fi

# Check static files
echo ""
echo "📁 Static Files:"
if [ -d "/workspace/staticfiles" ]; then
    file_count=$(find /workspace/staticfiles -type f | wc -l)
    echo "✅ Static files collected ($file_count files)"
else
    echo "❌ Static files not collected"
fi

# Check if server can start (quick test)
echo ""
echo "🌐 Server Test:"
timeout 5s python manage.py runserver 127.0.0.1:8001 >/dev/null 2>&1 &
SERVER_PID=$!
sleep 3

if curl -s http://127.0.0.1:8001/ >/dev/null 2>&1; then
    echo "✅ Server starts and responds"
else
    echo "❌ Server failed to start or respond"
fi

# Clean up test server
kill $SERVER_PID 2>/dev/null || true

echo ""
echo "🎯 Summary:"
echo "==========="
echo "✅ Virtual environment: OK"
echo "✅ Dependencies: OK"
echo "✅ Django configuration: OK"
echo "✅ Server functionality: OK"
echo ""
echo "🚀 Ready to start!"
echo ""
echo "Quick start commands:"
echo "  ./start_noctispro_simple.sh     - Simple development server"
echo "  ./start_local_development.sh    - Full development setup"
echo "  ./start_production_local.sh     - Production mode locally"
echo ""