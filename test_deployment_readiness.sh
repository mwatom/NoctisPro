#!/bin/bash

# 🧪 NoctisPro Deployment Readiness Test
# Quick validation script to check deployment prerequisites

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

echo -e "${BLUE}
🧪 NoctisPro Deployment Readiness Test
=====================================${NC}"

# Check workspace
if [ -d "/workspace" ]; then
    log "Workspace directory exists"
else
    error "Workspace directory not found"
    exit 1
fi

cd /workspace

# Check Python
if command -v python3 &> /dev/null; then
    log "Python3 available: $(python3 --version)"
else
    error "Python3 not found"
fi

# Check essential files
essential_files=(
    "manage.py"
    "deploy_production_complete.sh"
    ".env.production"
    ".env.ngrok"
)

for file in "${essential_files[@]}"; do
    if [ -f "$file" ]; then
        log "Found: $file"
    else
        warning "Missing: $file"
    fi
done

# Check Django structure
django_dirs=(
    "dicom_viewer"
    "accounts"
    "admin_panel"
)

for dir in "${django_dirs[@]}"; do
    if [ -d "$dir" ]; then
        log "Django app found: $dir"
    else
        warning "Django app missing: $dir"
    fi
done

# Test script permissions
if [ -x "deploy_production_complete.sh" ]; then
    log "Deployment script is executable"
else
    error "Deployment script not executable"
fi

# Check ngrok static URL configuration
if [ -f ".env.ngrok" ]; then
    if grep -q "colt-charmed-lark.ngrok-free.app" ".env.ngrok"; then
        log "Static ngrok URL configured: colt-charmed-lark.ngrok-free.app"
    else
        warning "Static ngrok URL not found in .env.ngrok"
    fi
fi

# Test Django syntax
if [ -f "manage.py" ]; then
    if python3 -m py_compile manage.py; then
        log "Django manage.py compiles successfully"
    else
        error "Django manage.py has syntax errors"
    fi
fi

# Check if virtual environment exists
if [ -d "venv" ]; then
    log "Virtual environment exists"
    if [ -f "venv/bin/activate" ]; then
        log "Virtual environment activation script found"
    else
        warning "Virtual environment activation script missing"
    fi
else
    warning "Virtual environment not found (will be created during deployment)"
fi

echo
info "🎯 Deployment Script Usage:"
echo "   sudo ./deploy_production_complete.sh"
echo
info "📋 After deployment, use these commands:"
echo "   ./start_production_complete.sh    - Start services"
echo "   ./stop_production_complete.sh     - Stop services"
echo "   ./status_production.sh           - Check status"
echo "   ./health_check_production.py     - Health check"
echo

success_count=$(grep -c "✓" /dev/stdout 2>/dev/null || echo "0")
if [ "$success_count" -gt 0 ]; then
    log "🎉 System appears ready for deployment!"
    echo
    info "Run: sudo ./deploy_production_complete.sh"
else
    warning "⚠️  Some issues found. Review the output above."
fi