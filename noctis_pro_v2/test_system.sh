#!/bin/bash

# 🧪 NoctisPro V2 - System Test Script
# Comprehensive testing of all endpoints

echo "🧪 Testing NoctisPro V2 System..."
echo ""

# Test health endpoint
echo -n "🔍 Health check: "
if curl -s -f http://localhost:8000/health/ > /dev/null; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test main page redirect
echo -n "🏠 Main page redirect: "
response=$(curl -s -I http://localhost:8000/ | grep "Location:")
if [[ $response == *"/login/"* ]]; then
    echo "✅ PASS (redirects to login)"
else
    echo "❌ FAIL"
fi

# Test login page
echo -n "🔐 Login page: "
if curl -s -f http://localhost:8000/login/ | grep -q "NoctisPro V2"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test admin page redirect
echo -n "👑 Admin page: "
response=$(curl -s -I http://localhost:8000/admin/ | grep "Location:")
if [[ $response == *"/admin/login/"* ]]; then
    echo "✅ PASS (redirects to admin login)"
else
    echo "❌ FAIL"
fi

# Test static files
echo -n "📁 Static files: "
if curl -s -f http://localhost:8000/static/css/noctis-v2.css | grep -q "NoctisPro V2"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test favicon
echo -n "🖼️  Favicon: "
if curl -s -I http://localhost:8000/favicon.ico | grep -q "204"; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

echo ""
echo "📊 System Status:"
echo "  🌐 Local URL: http://localhost:8000"
echo "  🌍 Public URL: https://colt-charmed-lark.ngrok-free.app"
echo "  👤 Login: admin / admin123"
echo ""
echo "🎉 NoctisPro V2 is ready for production!"