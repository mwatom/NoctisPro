#!/bin/bash

# Test script to verify Noctis Pro PACS is working for demo

echo "🧪 Testing Noctis Pro PACS System..."

# Test main endpoints
echo "Testing main endpoints:"

echo -n "  • Home page: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ | grep -q "302"; then
    echo "✅ Working (redirects to login)"
else
    echo "❌ Failed"
fi

echo -n "  • Login page: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/login/ | grep -q "200"; then
    echo "✅ Working"
else
    echo "❌ Failed"
fi

echo -n "  • Health check: "
if curl -s http://localhost:8000/health/ | grep -q "healthy"; then
    echo "✅ Working"
else
    echo "❌ Failed"
fi

echo -n "  • Admin panel: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/admin/ | grep -q "302"; then
    echo "✅ Working (redirects to login)"
else
    echo "❌ Failed"
fi

echo -n "  • Worklist: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/worklist/ | grep -q "302"; then
    echo "✅ Working (redirects to login)"
else
    echo "❌ Failed"
fi

echo -n "  • DICOM Viewer: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/dicom-viewer/ | grep -q "302"; then
    echo "✅ Working (redirects to login)"
else
    echo "❌ Failed"
fi

echo ""
echo "🎯 DEMO CREDENTIALS:"
echo "   URL: http://localhost:8000"
echo "   Username: demo"
echo "   Password: demo123"

echo ""
echo "🎉 System verification complete!"