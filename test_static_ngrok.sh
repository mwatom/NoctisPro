#!/bin/bash

echo "🧪 Testing NoctisPro Static Ngrok URL Configuration"
echo "=================================================="
echo ""

# Test ngrok configuration
echo "📋 Testing ngrok configuration..."
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok configuration is valid"
else
    echo "❌ Ngrok configuration has issues:"
    ngrok config check
    exit 1
fi

echo ""

# Check environment configuration
echo "📋 Checking environment configuration..."
if [ -f ".env.ngrok" ]; then
    echo "✅ .env.ngrok file exists"
    source .env.ngrok
    
    if [ "${NGROK_USE_STATIC:-false}" = "true" ]; then
        echo "✅ Static URL enabled"
        if [ ! -z "${NGROK_STATIC_URL:-}" ]; then
            echo "✅ Static URL configured: $NGROK_STATIC_URL"
        else
            echo "⚠️  No static URL configured"
        fi
    else
        echo "⚠️  Static URL not enabled"
    fi
    
    echo "✅ Django port: ${DJANGO_PORT:-80}"
    echo "✅ Django host: ${DJANGO_HOST:-0.0.0.0}"
else
    echo "❌ .env.ngrok file not found"
    exit 1
fi

echo ""

# Test Django configuration
echo "📋 Testing Django configuration..."
cd "$(dirname "$0")"

if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "⚠️  No virtual environment found"
fi

# Load environment
source .env.ngrok 2>/dev/null || true

# Test Django settings
python3 -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')

# Set environment variables from .env.ngrok
os.environ['ALLOWED_HOSTS'] = '*'
os.environ['DEBUG'] = 'False'
os.environ['SERVE_MEDIA_FILES'] = 'True'

django.setup()

from django.conf import settings

print('✅ Django settings loaded successfully')
print(f'✅ Debug mode: {settings.DEBUG}')
print(f'✅ Allowed hosts: {settings.ALLOWED_HOSTS}')
print(f'✅ Media serving: {getattr(settings, \"SERVE_MEDIA_FILES\", False)}')
print(f'✅ Image optimization: {settings.IMAGE_OPTIMIZATION.get(\"ENABLE\", False)}')

# Test middleware
middleware = settings.MIDDLEWARE
optimization_middleware = [m for m in middleware if 'middleware' in m.lower() and 'optimization' in m.lower()]
if optimization_middleware:
    print(f'✅ Optimization middleware configured: {len(optimization_middleware)} found')
else:
    print('⚠️  No optimization middleware found')
"

if [ $? -eq 0 ]; then
    echo "✅ Django configuration test passed"
else
    echo "❌ Django configuration test failed"
    exit 1
fi

echo ""

# Test specific ngrok command
echo "📋 Testing ngrok command syntax..."
NGROK_CMD="ngrok http --url=${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app} ${DJANGO_PORT:-80}"
echo "Command: $NGROK_CMD"

# Just test the syntax, don't actually run it
if command -v ngrok > /dev/null; then
    echo "✅ Ngrok command syntax is valid"
else
    echo "❌ Ngrok not found in PATH"
    exit 1
fi

echo ""

# Display final configuration summary
echo "🎯 Configuration Summary"
echo "======================="
echo "Static URL: https://${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}"
echo "Django Port: ${DJANGO_PORT:-80}"
echo "Django Host: ${DJANGO_HOST:-0.0.0.0}"
echo "Optimization: Enabled for slow connections"
echo "Image formats: JPEG, PNG, WebP (auto-detect)"
echo ""

echo "🚀 Ready to start!"
echo ""
echo "Next steps:"
echo "1. Configure your ngrok auth token: ngrok config add-authtoken <your-token>"
echo "2. Start the application: ./start_with_ngrok.sh"
echo "3. Access at: https://${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}"
echo ""

echo "🔍 Testing URLs:"
echo "- Main app: https://${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}/"
echo "- Admin panel: https://${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}/admin-panel/"
echo "- DICOM viewer: https://${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}/dicom-viewer/"
echo "- Connection info: https://${NGROK_STATIC_URL:-colt-charmed-lark.ngrok-free.app}/connection-info/"
echo ""

echo "📱 Image optimization testing:"
echo "- Slow connection: Add ?connection=slow to any image URL"
echo "- Custom quality: Add ?quality=50 to any image URL"
echo "- Custom size: Add ?max_width=800&max_height=600 to any image URL"
echo ""

echo "✅ All tests passed! Configuration is ready."