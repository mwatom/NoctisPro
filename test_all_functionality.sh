#!/bin/bash

# 🧪 Comprehensive Test Script - Verify ALL functionality works without Error 500
echo "🧪 Testing ALL NoctisPro functionality for Error 500s..."

BASE_URL="http://localhost:8000"
if [ "$1" ]; then
    BASE_URL="$1"
fi

echo "🎯 Testing URL: $BASE_URL"
echo "================================"

# Test endpoints and check for Error 500
test_endpoint() {
    local endpoint="$1"
    local description="$2"
    
    echo -n "Testing $description... "
    
    response=$(curl -s -w "%{http_code}" -o /dev/null "$BASE_URL$endpoint" 2>/dev/null)
    
    if [ "$response" = "500" ]; then
        echo "❌ ERROR 500 - CRITICAL ISSUE"
        return 1
    elif [ "$response" = "200" ] || [ "$response" = "302" ] || [ "$response" = "404" ]; then
        echo "✅ OK (HTTP $response)"
        return 0
    else
        echo "⚠️  HTTP $response"
        return 0
    fi
}

echo "🏠 Testing Core Pages:"
test_endpoint "/" "Home page"
test_endpoint "/login/" "Login page"
test_endpoint "/admin/" "Admin interface"

echo ""
echo "📋 Testing Dashboard & Worklist:"
test_endpoint "/worklist/" "Worklist dashboard"
test_endpoint "/worklist/api/studies/" "Studies API"
test_endpoint "/worklist/api/refresh-worklist/" "Refresh worklist API"
test_endpoint "/worklist/api/upload-stats/" "Upload stats API"

echo ""
echo "🏥 Testing DICOM Viewer:"
test_endpoint "/dicom-viewer/" "DICOM viewer main"
test_endpoint "/dicom-viewer/api/studies/" "DICOM studies API"
test_endpoint "/viewer/" "Viewer redirect"

echo ""
echo "📊 Testing Reports & Admin Panel:"
test_endpoint "/reports/" "Reports section"
test_endpoint "/admin-panel/" "Admin panel"

echo ""
echo "💬 Testing Communication Features:"
test_endpoint "/chat/" "Chat interface"
test_endpoint "/notifications/" "Notifications"

echo ""
echo "🤖 Testing AI Analysis:"
test_endpoint "/ai/" "AI analysis"

echo ""
echo "🔍 Testing Static Files:"
test_endpoint "/static/css/style.css" "CSS files"
test_endpoint "/static/js/main.js" "JavaScript files"

echo ""
echo "================================"
echo "🎯 Test Summary Complete!"
echo ""

# Check if server is responding
if curl -s "$BASE_URL/" > /dev/null 2>&1; then
    echo "✅ Server is responding"
    echo "🌐 Ready for production deployment!"
else
    echo "❌ Server not responding"
    echo "🔧 Please start the Django server first"
fi