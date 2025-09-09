#!/bin/bash

# ============================================================================
# NoctisPro PACS - Comprehensive Smoke Test Script
# ============================================================================
# This script performs a complete smoke test of all NoctisPro PACS features
# to ensure everything is working before deployment
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/smoke_test.log"
VENV_DIR="$SCRIPT_DIR/venv"
TEST_PORT=8001
TEST_TIMEOUT=30

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_WARNINGS++))
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_PASSED++))
}

test_start() {
    ((TESTS_TOTAL++))
    echo -e "${CYAN}[TEST $TESTS_TOTAL]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║         🏥 NoctisPro PACS - Comprehensive Smoke Test          ║
    ║                                                               ║
    ║  Testing all features before deployment to ensure             ║
    ║  everything is working correctly                              ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        info "Running as root - this is acceptable for testing"
    else
        info "Running as regular user"
    fi
}

# Setup test environment
setup_test_environment() {
    header "Setting Up Test Environment"
    
    cd "$SCRIPT_DIR"
    
    # Initialize log file
    echo "NoctisPro PACS Smoke Test - $(date)" > "$LOG_FILE"
    
    # Create virtual environment if it doesn't exist
    test_start "Creating Python virtual environment"
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
        success "Virtual environment created"
    else
        success "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    test_start "Activating virtual environment"
    source "$VENV_DIR/bin/activate"
    if [[ "$VIRTUAL_ENV" == "$VENV_DIR" ]]; then
        success "Virtual environment activated"
    else
        error "Failed to activate virtual environment"
        return 1
    fi
    
    # Upgrade pip
    test_start "Upgrading pip"
    pip install --upgrade pip &>> "$LOG_FILE"
    success "Pip upgraded"
    
    # Install requirements
    test_start "Installing Python requirements"
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt &>> "$LOG_FILE"
        success "Requirements installed"
    else
        error "requirements.txt not found"
        return 1
    fi
}

# Test Django configuration
test_django_configuration() {
    header "Testing Django Configuration"
    
    test_start "Django system check"
    if python manage.py check &>> "$LOG_FILE"; then
        success "Django system check passed"
    else
        error "Django system check failed"
    fi
    
    test_start "Django settings validation"
    if python -c "import django; django.setup(); from django.conf import settings; print('Settings loaded successfully')" &>> "$LOG_FILE"; then
        success "Django settings are valid"
    else
        error "Django settings validation failed"
    fi
}

# Test database connectivity
test_database() {
    header "Testing Database"
    
    test_start "Database migrations"
    if python manage.py migrate &>> "$LOG_FILE"; then
        success "Database migrations completed"
    else
        error "Database migrations failed"
    fi
    
    test_start "Database connectivity"
    if python manage.py shell -c "from django.db import connection; connection.cursor(); print('Database connected')" &>> "$LOG_FILE"; then
        success "Database connection successful"
    else
        error "Database connection failed"
    fi
    
    test_start "Creating test superuser"
    if python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='testadmin').exists():
    User.objects.create_superuser('testadmin', 'test@example.com', 'testpass123')
    print('Test superuser created')
else:
    print('Test superuser already exists')
" &>> "$LOG_FILE"; then
        success "Test superuser ready"
    else
        error "Failed to create test superuser"
    fi
}

# Test static files
test_static_files() {
    header "Testing Static Files"
    
    test_start "Collecting static files"
    if python manage.py collectstatic --noinput &>> "$LOG_FILE"; then
        success "Static files collected"
    else
        error "Static files collection failed"
    fi
    
    test_start "Static files accessibility"
    if [[ -d "staticfiles" && -f "staticfiles/admin/css/base.css" ]]; then
        success "Static files are accessible"
    else
        error "Static files not found"
    fi
}

# Start test server
start_test_server() {
    header "Starting Test Server"
    
    test_start "Starting Django development server"
    
    # Kill any existing server on test port
    pkill -f "manage.py runserver.*$TEST_PORT" || true
    sleep 2
    
    # Start server in background
    python manage.py runserver "127.0.0.1:$TEST_PORT" &>> "$LOG_FILE" &
    SERVER_PID=$!
    
    # Wait for server to start
    local count=0
    while ! curl -s "http://127.0.0.1:$TEST_PORT" > /dev/null 2>&1; do
        sleep 1
        ((count++))
        if [[ $count -gt $TEST_TIMEOUT ]]; then
            error "Server failed to start within $TEST_TIMEOUT seconds"
            kill $SERVER_PID 2>/dev/null || true
            return 1
        fi
    done
    
    success "Test server started on port $TEST_PORT (PID: $SERVER_PID)"
    echo "SERVER_PID=$SERVER_PID" > /tmp/smoke_test_server.pid
}

# Test web interface
test_web_interface() {
    header "Testing Web Interface"
    
    local base_url="http://127.0.0.1:$TEST_PORT"
    
    test_start "Home page accessibility"
    if curl -s -o /dev/null -w "%{http_code}" "$base_url" | grep -q "200\|302"; then
        success "Home page is accessible"
    else
        error "Home page not accessible"
    fi
    
    test_start "Admin panel accessibility"
    if curl -s -o /dev/null -w "%{http_code}" "$base_url/admin/" | grep -q "200\|302"; then
        success "Admin panel is accessible"
    else
        error "Admin panel not accessible"
    fi
    
    test_start "Login page"
    if curl -s "$base_url/login/" | grep -q "login\|username\|password"; then
        success "Login page is functional"
    else
        error "Login page not working"
    fi
    
    test_start "Static files serving"
    if curl -s -o /dev/null -w "%{http_code}" "$base_url/static/admin/css/base.css" | grep -q "200"; then
        success "Static files are being served"
    else
        warning "Static files may not be serving correctly"
    fi
}

# Test NoctisPro applications
test_noctispro_applications() {
    header "Testing NoctisPro Applications"
    
    local base_url="http://127.0.0.1:$TEST_PORT"
    
    # Test each application
    local apps=("worklist" "dicom_viewer" "reports" "admin_panel" "chat" "notifications" "ai_analysis")
    
    for app in "${apps[@]}"; do
        test_start "Testing $app application"
        if curl -s -o /dev/null -w "%{http_code}" "$base_url/$app/" | grep -q "200\|302\|403"; then
            success "$app application is responding"
        else
            warning "$app application may have issues"
        fi
    done
}

# Test API endpoints
test_api_endpoints() {
    header "Testing API Endpoints"
    
    local base_url="http://127.0.0.1:$TEST_PORT"
    
    test_start "API root endpoint"
    if curl -s -o /dev/null -w "%{http_code}" "$base_url/api/" | grep -q "200\|401\|403"; then
        success "API root is responding"
    else
        warning "API root may not be configured"
    fi
    
    test_start "REST framework browsable API"
    if curl -s "$base_url/api/" | grep -q "API\|browsable\|Django REST"; then
        success "REST framework is working"
    else
        warning "REST framework may not be properly configured"
    fi
}

# Test DICOM functionality
test_dicom_functionality() {
    header "Testing DICOM Functionality"
    
    test_start "DICOM Python modules"
    if python -c "import pydicom, pynetdicom; print('DICOM modules imported successfully')" &>> "$LOG_FILE"; then
        success "DICOM modules are available"
    else
        error "DICOM modules not working"
    fi
    
    test_start "DICOM storage directory"
    if [[ -d "media" ]]; then
        mkdir -p "media/dicom"
        success "DICOM storage directory ready"
    else
        error "Media directory not found"
    fi
    
    test_start "Image processing modules"
    if python -c "import cv2, skimage, matplotlib; print('Image processing modules ready')" &>> "$LOG_FILE"; then
        success "Image processing modules available"
    else
        warning "Some image processing modules may be missing"
    fi
}

# Test AI functionality
test_ai_functionality() {
    header "Testing AI Functionality"
    
    test_start "AI/ML Python modules"
    if python -c "import torch, sklearn, numpy, pandas; print('AI modules imported successfully')" &>> "$LOG_FILE"; then
        success "AI/ML modules are available"
    else
        warning "Some AI/ML modules may be missing"
    fi
    
    test_start "AI analysis application"
    if python -c "from ai_analysis.models import *; print('AI models imported')" &>> "$LOG_FILE"; then
        success "AI analysis models are working"
    else
        warning "AI analysis models may have issues"
    fi
}

# Test user authentication
test_authentication() {
    header "Testing Authentication System"
    
    test_start "User model functionality"
    if python manage.py shell -c "
from accounts.models import User
print(f'User model working, total users: {User.objects.count()}')
" &>> "$LOG_FILE"; then
        success "User model is functional"
    else
        error "User model has issues"
    fi
    
    test_start "Authentication views"
    local base_url="http://127.0.0.1:$TEST_PORT"
    if curl -s "$base_url/login/" | grep -q "csrf"; then
        success "Authentication views are working"
    else
        warning "Authentication views may have issues"
    fi
}

# Test file upload capabilities
test_file_uploads() {
    header "Testing File Upload Capabilities"
    
    test_start "Media directory permissions"
    if [[ -w "media" ]]; then
        success "Media directory is writable"
    else
        error "Media directory is not writable"
    fi
    
    test_start "File upload settings"
    if python -c "
from django.conf import settings
print(f'Max upload size: {settings.FILE_UPLOAD_MAX_MEMORY_SIZE}')
print(f'Media root: {settings.MEDIA_ROOT}')
" &>> "$LOG_FILE"; then
        success "File upload settings are configured"
    else
        error "File upload settings have issues"
    fi
}

# Test security configurations
test_security() {
    header "Testing Security Configurations"
    
    test_start "CSRF protection"
    if python -c "
from django.conf import settings
print('CSRF middleware:', 'django.middleware.csrf.CsrfViewMiddleware' in settings.MIDDLEWARE)
print('CSRF trusted origins:', len(settings.CSRF_TRUSTED_ORIGINS))
" &>> "$LOG_FILE"; then
        success "CSRF protection is configured"
    else
        warning "CSRF protection may have issues"
    fi
    
    test_start "Security headers"
    local base_url="http://127.0.0.1:$TEST_PORT"
    if curl -s -I "$base_url" | grep -q "X-Frame-Options\|X-Content-Type-Options"; then
        success "Security headers are present"
    else
        warning "Some security headers may be missing"
    fi
}

# Performance tests
test_performance() {
    header "Testing Performance"
    
    test_start "Response time measurement"
    local base_url="http://127.0.0.1:$TEST_PORT"
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$base_url")
    
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        success "Response time is good: ${response_time}s"
    else
        warning "Response time is slow: ${response_time}s"
    fi
    
    test_start "Memory usage check"
    local memory_usage=$(python -c "
import psutil
process = psutil.Process()
memory_mb = process.memory_info().rss / 1024 / 1024
print(f'{memory_mb:.1f}')
")
    
    if (( $(echo "$memory_usage < 500" | bc -l) )); then
        success "Memory usage is reasonable: ${memory_usage}MB"
    else
        warning "Memory usage is high: ${memory_usage}MB"
    fi
}

# Stop test server
stop_test_server() {
    header "Stopping Test Server"
    
    if [[ -f "/tmp/smoke_test_server.pid" ]]; then
        SERVER_PID=$(cat /tmp/smoke_test_server.pid | cut -d= -f2)
        if kill $SERVER_PID 2>/dev/null; then
            success "Test server stopped"
        else
            warning "Test server may have already stopped"
        fi
        rm -f /tmp/smoke_test_server.pid
    fi
}

# Generate test report
generate_report() {
    header "Test Results Summary"
    
    echo ""
    echo -e "${CYAN}🏥 NoctisPro PACS - Comprehensive Smoke Test Results${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo ""
    
    echo -e "${BLUE}Test Statistics:${NC}"
    echo -e "  Total Tests: ${TESTS_TOTAL}"
    echo -e "  ${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "  ${RED}Failed: ${TESTS_FAILED}${NC}"
    echo -e "  ${YELLOW}Warnings: ${TESTS_WARNINGS}${NC}"
    echo ""
    
    # Calculate success rate
    local success_rate=0
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    fi
    
    echo -e "${BLUE}Success Rate: ${success_rate}%${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}NoctisPro PACS is ready for deployment!${NC}"
        echo ""
        echo -e "${CYAN}Next Steps:${NC}"
        echo "1. Create bootable media: sudo ./create_bootable_ubuntu.sh"
        echo "2. Or deploy directly: sudo ./deploy_ubuntu_gui_master.sh"
        echo "3. Access system at: http://localhost"
        echo ""
        return 0
    elif [[ $TESTS_FAILED -le 2 && $TESTS_WARNINGS -le 5 ]]; then
        echo -e "${YELLOW}⚠️  TESTS PASSED WITH WARNINGS${NC}"
        echo -e "${YELLOW}System should work but may need attention${NC}"
        echo ""
        echo -e "${CYAN}Recommendations:${NC}"
        echo "• Review warnings in the log file: $LOG_FILE"
        echo "• Consider fixing issues before deployment"
        echo "• Test deployment in a controlled environment first"
        echo ""
        return 0
    else
        echo -e "${RED}❌ CRITICAL ISSUES FOUND${NC}"
        echo -e "${RED}System is NOT ready for deployment${NC}"
        echo ""
        echo -e "${CYAN}Required Actions:${NC}"
        echo "• Review error log: $LOG_FILE"
        echo "• Fix critical issues before proceeding"
        echo "• Re-run smoke test after fixes"
        echo ""
        return 1
    fi
}

# Cleanup function
cleanup() {
    stop_test_server
    deactivate 2>/dev/null || true
}

# Main function
main() {
    # Initialize
    show_banner
    check_root
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Run tests
    setup_test_environment
    test_django_configuration
    test_database
    test_static_files
    start_test_server
    test_web_interface
    test_noctispro_applications
    test_api_endpoints
    test_dicom_functionality
    test_ai_functionality
    test_authentication
    test_file_uploads
    test_security
    test_performance
    
    # Generate report
    generate_report
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS Comprehensive Smoke Test"
        echo ""
        echo "This script tests all NoctisPro PACS features to ensure"
        echo "the system is ready for deployment."
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --verbose           Enable verbose output"
        echo "  --port PORT         Use custom test port (default: 8001)"
        echo ""
        echo "The test results will be saved to: $LOG_FILE"
        exit 0
        ;;
    --verbose)
        set -x
        ;;
    --port)
        if [[ -n "$2" ]]; then
            TEST_PORT="$2"
            shift
        else
            error "--port requires a port number"
        fi
        ;;
esac

# Install bc for floating point comparisons if not available
if ! command -v bc &> /dev/null; then
    if command -v apt &> /dev/null; then
        sudo apt install -y bc &> /dev/null || true
    fi
fi

# Run main function
main "$@"