#!/usr/bin/env bash
set -euo pipefail

# Comprehensive Auto-Deployment System Test
# This script tests all components of the auto-deployment system

log() { echo "[$(date '+%F %T')] $*"; }
success() { echo -e "\e[32m✓\e[0m $*"; }
warning() { echo -e "\e[33m⚠\e[0m $*"; }
error() { echo -e "\e[31m✗\e[0m $*" >&2; }

# Test configuration
TEST_MODE=${TEST_MODE:-dry-run}  # dry-run or live
ENV_FILE=${ENV_FILE:-/etc/noctis/noctis.env}

# Load configuration
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

APP_DIR=${APP_DIR:-/opt/noctis}
HOST=${HOST:-127.0.0.1}
PORT=${PORT:-8000}
WEBHOOK_PORT=${WEBHOOK_PORT:-9000}
DICOM_PORT=${DICOM_PORT:-11112}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local is_critical="${3:-false}"
    
    ((TESTS_TOTAL++))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        if [ "$is_critical" = "true" ]; then
            error "$test_name (CRITICAL)"
        else
            warning "$test_name (non-critical)"
        fi
        ((TESTS_FAILED++))
        return 1
    fi
}

# Detailed test function with output
run_detailed_test() {
    local test_name="$1"
    local test_command="$2"
    local is_critical="${3:-false}"
    
    ((TESTS_TOTAL++))
    echo "=== Testing $test_name ==="
    
    if eval "$test_command"; then
        success "$test_name passed"
        ((TESTS_PASSED++))
        echo
        return 0
    else
        if [ "$is_critical" = "true" ]; then
            error "$test_name failed (CRITICAL)"
        else
            warning "$test_name failed (non-critical)"
        fi
        ((TESTS_FAILED++))
        echo
        return 1
    fi
}

# Test system prerequisites
test_prerequisites() {
    echo "=== Testing System Prerequisites ==="
    
    run_test "Git availability" "command -v git" true
    run_test "Python 3 availability" "command -v python3" true
    run_test "Systemctl availability" "command -v systemctl" true
    run_test "Curl availability" "command -v curl" true
    run_test "Environment file exists" "[ -f '$ENV_FILE' ]" true
    run_test "App directory exists" "[ -d '$APP_DIR' ]" true
    run_test "Virtual environment exists" "[ -d '$VENV_DIR' ]" true
    run_test "Deploy script exists" "[ -f '$APP_DIR/ops/deploy_from_git.sh' ]" true
    run_test "Webhook listener exists" "[ -f '$APP_DIR/tools/webhook_listener.py' ]" true
    
    echo
}

# Test service status
test_services() {
    echo "=== Testing Service Status ==="
    
    local services=(
        "redis-server:true"
        "nginx:true"
        "noctis-web:true"
        "noctis-celery:false"
        "noctis-dicom:false"
        "noctis-webhook:false"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local is_critical="${service_info##*:}"
        
        run_test "$service service is active" "systemctl is-active --quiet $service.service" "$is_critical"
        run_test "$service service is enabled" "systemctl is-enabled --quiet $service.service" false
    done
    
    echo
}

# Test network connectivity
test_network() {
    echo "=== Testing Network Connectivity ==="
    
    run_test "Web service responds" "curl -f -s --max-time 10 'http://$HOST:$PORT/' >/dev/null" true
    run_test "Webhook service responds" "curl -f -s --max-time 10 'http://$HOST:$WEBHOOK_PORT/health' >/dev/null" false
    run_test "DICOM port is listening" "netstat -ln 2>/dev/null | grep -q ':$DICOM_PORT.*LISTEN' || ss -ln 2>/dev/null | grep -q ':$DICOM_PORT.*LISTEN'" false
    run_test "Redis is accessible" "redis-cli ping 2>/dev/null | grep -q PONG" true
    
    echo
}

# Test git repository
test_git_repository() {
    echo "=== Testing Git Repository ==="
    
    cd "$APP_DIR"
    
    run_test "Is git repository" "[ -d .git ]" true
    run_test "Has remote origin" "git remote get-url origin >/dev/null" true
    run_test "Can fetch from remote" "git fetch --dry-run" false
    run_test "Working tree is clean" "git diff --quiet && git diff --cached --quiet" false
    
    echo "Current branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Last commit: $(git log -1 --oneline 2>/dev/null || echo 'unknown')"
    echo "Remote URL: $(git remote get-url origin 2>/dev/null || echo 'unknown')"
    echo
}

# Test deployment script
test_deployment_script() {
    echo "=== Testing Deployment Script ==="
    
    # Test deployment script syntax
    run_test "Deploy script syntax" "bash -n '$APP_DIR/ops/deploy_from_git.sh'" true
    
    # Test webhook listener syntax
    run_test "Webhook listener syntax" "python3 -m py_compile '$APP_DIR/tools/webhook_listener.py'" true
    
    # Test startup check script
    run_test "Startup check script syntax" "bash -n '$APP_DIR/ops/startup_check.sh'" false
    
    if [ "$TEST_MODE" = "live" ]; then
        echo "Running live deployment test..."
        warning "This will actually deploy the current state!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_detailed_test "Live deployment" "bash '$APP_DIR/ops/deploy_from_git.sh'" true
        else
            warning "Skipping live deployment test"
        fi
    else
        log "Dry-run mode: skipping actual deployment test"
    fi
    
    echo
}

# Test webhook functionality
test_webhook() {
    echo "=== Testing Webhook Functionality ==="
    
    if ! systemctl is-active --quiet noctis-webhook.service; then
        warning "Webhook service not running, skipping webhook tests"
        return
    fi
    
    # Test webhook health endpoint
    run_detailed_test "Webhook health endpoint" "curl -s 'http://$HOST:$WEBHOOK_PORT/health' | jq . >/dev/null" false
    
    # Test webhook with dummy payload (if in live mode)
    if [ "$TEST_MODE" = "live" ]; then
        warning "Testing webhook with dummy payload..."
        local test_payload='{"ref":"refs/heads/test","repository":{"full_name":"test/test"}}'
        local response=$(curl -s -w "%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "X-GitHub-Event: push" \
            -d "$test_payload" \
            "http://$HOST:$WEBHOOK_PORT/")
        
        if [[ "$response" =~ 200$ ]]; then
            success "Webhook responds to test payload"
        else
            warning "Webhook test payload response: $response"
        fi
    fi
    
    echo
}

# Test log files and monitoring
test_monitoring() {
    echo "=== Testing Monitoring and Logs ==="
    
    local log_files=(
        "/var/log/noctis-deploy.log"
        "/var/log/noctis-webhook.log"
        "/var/log/noctis-startup.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            success "Log file exists: $log_file"
            echo "  Last 3 lines:"
            tail -n 3 "$log_file" | sed 's/^/    /'
        else
            warning "Log file missing: $log_file"
        fi
    done
    
    # Test startup check script
    if [ -x /usr/local/bin/noctis-check ]; then
        run_detailed_test "Startup check script" "/usr/local/bin/noctis-check status" false
    else
        warning "Startup check script not installed"
    fi
    
    echo
}

# Test GitHub integration setup
test_github_integration() {
    echo "=== Testing GitHub Integration Setup ==="
    
    # Check if GitHub Actions workflow exists
    if [ -f "$APP_DIR/.github/workflows/deploy.yml" ]; then
        success "GitHub Actions workflow exists"
        
        # Basic syntax check
        if command -v yq >/dev/null 2>&1; then
            run_test "GitHub workflow syntax" "yq eval '.jobs.deploy.steps[0]' '$APP_DIR/.github/workflows/deploy.yml' >/dev/null" false
        else
            log "yq not available, skipping workflow syntax check"
        fi
    else
        warning "GitHub Actions workflow not found"
    fi
    
    # Check webhook secret
    if [ -n "${GITHUB_WEBHOOK_SECRET:-}" ]; then
        success "Webhook secret is configured"
        if [ ${#GITHUB_WEBHOOK_SECRET} -lt 20 ]; then
            warning "Webhook secret seems short (less than 20 characters)"
        fi
    else
        warning "Webhook secret not configured"
    fi
    
    echo
}

# Test security configuration
test_security() {
    echo "=== Testing Security Configuration ==="
    
    # Check file permissions
    run_test "Environment file permissions" "[ \$(stat -c '%a' '$ENV_FILE') = '644' ] || [ \$(stat -c '%a' '$ENV_FILE') = '600' ]" false
    run_test "Deploy script is executable" "[ -x '$APP_DIR/ops/deploy_from_git.sh' ]" true
    
    # Check if webhook secret exists and is secure
    if [ -n "${GITHUB_WEBHOOK_SECRET:-}" ]; then
        if [ ${#GITHUB_WEBHOOK_SECRET} -ge 32 ]; then
            success "Webhook secret has good length"
        else
            warning "Webhook secret should be at least 32 characters"
        fi
    fi
    
    # Check systemd service security
    for service in noctis-web noctis-celery noctis-dicom noctis-webhook; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            local user=$(systemctl show -p User "${service}.service" --value 2>/dev/null || echo "unknown")
            if [ "$user" = "root" ]; then
                warning "$service runs as root (consider using dedicated user)"
            else
                success "$service runs as $user"
            fi
        fi
    done
    
    echo
}

# Main test execution
main() {
    echo "=== Noctis Pro Auto-Deployment System Test ==="
    echo "Test mode: $TEST_MODE"
    echo "Environment: $ENV_FILE"
    echo "App directory: $APP_DIR"
    echo "Timestamp: $(date)"
    echo

    test_prerequisites
    test_services
    test_network
    test_git_repository
    test_deployment_script
    test_webhook
    test_monitoring
    test_github_integration
    test_security

    echo "=== Test Summary ==="
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        success "All tests passed! Your auto-deployment system is ready."
        echo
        echo "Next steps:"
        echo "1. Configure GitHub secrets or webhook (run: bash ops/setup_github_integration.sh)"
        echo "2. Test with a real commit to your repository"
        echo "3. Monitor logs: tail -f /var/log/noctis-deploy.log"
        return 0
    else
        warning "$TESTS_FAILED tests failed. Please review and fix the issues above."
        return 1
    fi
}

# Handle script arguments
case "${1:-test}" in
    "test"|"check")
        TEST_MODE="dry-run"
        main
        ;;
    "live")
        TEST_MODE="live"
        warning "Running in LIVE mode - this may trigger actual deployments!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            main
        else
            echo "Cancelled."
            exit 0
        fi
        ;;
    *)
        echo "Usage: $0 {test|live}"
        echo "  test - Run tests in dry-run mode (default, safe)"
        echo "  live - Run tests including actual deployment (use with caution)"
        exit 1
        ;;
esac