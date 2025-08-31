#!/bin/bash
# Test script to check worklist button endpoints for 500 errors

BASE_URL="http://localhost:8000"
echo "🔍 Testing Worklist Button Endpoints"
echo "=" $(printf '=%.0s' {1..50})

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    
    echo -n "Testing $name... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$url" 2>/dev/null)
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL$url" 2>/dev/null)
    fi
    
    case $response in
        "000")
            echo "🔌 CONNECTION_ERROR (Server not running)"
            return 2
            ;;
        "200")
            echo "✅ OK"
            return 0
            ;;
        "302")
            echo "🔄 REDIRECT (Expected for auth-protected endpoints)"
            return 0
            ;;
        "403")
            echo "🚫 FORBIDDEN"
            return 0
            ;;
        "404")
            echo "❌ NOT_FOUND"
            return 1
            ;;
        "500")
            echo "💥 ERROR_500 (CRITICAL)"
            return 3
            ;;
        *)
            echo "❓ OTHER ($response)"
            return 1
            ;;
    esac
}

# Test all endpoints
echo ""
echo "📋 Testing Worklist Endpoints:"

test_endpoint "Dashboard" "/worklist/"
test_endpoint "Study List" "/worklist/studies/"
test_endpoint "Upload Study" "/worklist/upload/"
test_endpoint "Studies API" "/worklist/api/studies/"
test_endpoint "Refresh Worklist API" "/worklist/api/refresh-worklist/"
test_endpoint "Upload Stats API" "/worklist/api/upload-stats/"

echo ""
echo "📋 Testing DICOM Viewer Endpoints:"

test_endpoint "DICOM Viewer" "/dicom-viewer/"
test_endpoint "DICOM API Study" "/dicom-viewer/api/study/1/"
test_endpoint "DICOM API Image" "/dicom-viewer/api/image/1/display/"

echo ""
echo "📋 Testing Other System Endpoints:"

test_endpoint "Admin Panel" "/admin-panel/"
test_endpoint "Notifications" "/notifications/"
test_endpoint "Chat Rooms" "/chat/"
test_endpoint "Login Page" "/login/"

echo ""
echo "📊 Test completed. Check for any 💥 ERROR_500 entries above."