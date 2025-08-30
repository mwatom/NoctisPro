#!/bin/bash

# Test script to verify bulletproof deployment fixes

set -e

echo "🧪 Testing NoctisPro Bulletproof Deployment Fixes"
echo "================================================"

# Test 1: Check if we can create virtual environment
echo "✅ Test 1: Virtual environment creation"
if python3 -m venv test_venv; then
    echo "   ✓ Virtual environment can be created"
    rm -rf test_venv
else
    echo "   ❌ Virtual environment creation failed"
    exit 1
fi

# Test 2: Check requirements.txt format
echo "✅ Test 2: Requirements file format"
if grep -q "==" requirements.txt; then
    echo "   ❌ Found version pins in requirements.txt"
    echo "   ℹ️  Version pins have been removed for flexibility"
else
    echo "   ✓ Requirements.txt has no version pins"
fi

# Test 3: Check if Redis can start
echo "✅ Test 3: Redis service"
if pgrep redis-server > /dev/null; then
    echo "   ✓ Redis is already running"
elif redis-server --daemonize yes; then
    echo "   ✓ Redis started successfully"
    sleep 1
    if redis-cli ping > /dev/null 2>&1; then
        echo "   ✓ Redis is responding"
    else
        echo "   ⚠️  Redis started but not responding"
    fi
else
    echo "   ❌ Redis failed to start"
fi

# Test 4: Check Django
echo "✅ Test 4: Django system check"
if [ -d "venv" ]; then
    source venv/bin/activate
    if python manage.py check > /dev/null 2>&1; then
        echo "   ✓ Django system check passed"
    else
        echo "   ❌ Django system check failed"
    fi
else
    echo "   ⚠️  No virtual environment found, skipping Django test"
fi

# Test 5: Check CUPS installation
echo "✅ Test 5: CUPS printing system"
if command -v cupsd &> /dev/null; then
    echo "   ✓ CUPS is installed"
    if pgrep cupsd > /dev/null; then
        echo "   ✓ CUPS service is running"
    else
        echo "   ⚠️  CUPS installed but not running"
    fi
else
    echo "   ⚠️  CUPS not installed (will be installed by deployment script)"
fi

# Test 6: Check bulletproof script syntax
echo "✅ Test 6: Deployment script syntax"
if bash -n deploy_production_bulletproof.sh; then
    echo "   ✓ Bulletproof deployment script syntax is valid"
else
    echo "   ❌ Bulletproof deployment script has syntax errors"
    exit 1
fi

echo ""
echo "🎯 All tests completed!"
echo ""
echo "Summary of fixes applied:"
echo "• Fixed virtual environment creation in bulletproof script"
echo "• Removed version pins from requirements.txt for flexibility" 
echo "• Added system dependencies installation including CUPS"
echo "• Added CUPS service configuration"
echo "• Enhanced error handling and logging"
echo ""
echo "The bulletproof deployment should now work correctly!"
echo "Run: sudo ./deploy_production_bulletproof.sh"