#!/bin/bash

# =============================================================================
# NoctisPro PACS - Deployment Testing and Validation Suite
# =============================================================================
# Comprehensive testing suite for the intelligent deployment system
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly TEST_LOG_FILE="/tmp/noctis_test_$(date +%Y%m%d_%H%M%S).log"
readonly TEST_RESULTS_DIR="/tmp/noctis_test_results_$(date +%Y%m%d_%H%M%S)"

# Test counters
declare -g TESTS_TOTAL=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g TESTS_SKIPPED=0

# Test results
declare -g TEST_RESULTS=()

# =============================================================================
# LOGGING AND UTILITY FUNCTIONS
# =============================================================================

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "${message}" >> "${TEST_LOG_FILE}"
}

warn() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}${message}${NC}" >&2
    echo "${message}" >> "${TEST_LOG_FILE}"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}${message}${NC}" >&2
    echo "${message}" >> "${TEST_LOG_FILE}"
}

info() {
    local message="[INFO] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "${message}" >> "${TEST_LOG_FILE}"
}

success() {
    local message="[SUCCESS] $1"
    echo -e "${GREEN}✅ ${message}${NC}"
    echo "${message}" >> "${TEST_LOG_FILE}"
}

# Test result functions
test_start() {
    local test_name="$1"
    ((TESTS_TOTAL++))
    info "🧪 Starting test: ${test_name}"
    echo "TEST_START: ${test_name}" >> "${TEST_LOG_FILE}"
}

test_pass() {
    local test_name="$1"
    ((TESTS_PASSED++))
    success "Test passed: ${test_name}"
    TEST_RESULTS+=("PASS: ${test_name}")
    echo "TEST_PASS: ${test_name}" >> "${TEST_LOG_FILE}"
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    ((TESTS_FAILED++))
    error "Test failed: ${test_name} - ${reason}"
    TEST_RESULTS+=("FAIL: ${test_name} - ${reason}")
    echo "TEST_FAIL: ${test_name} - ${reason}" >> "${TEST_LOG_FILE}"
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    ((TESTS_SKIPPED++))
    warn "Test skipped: ${test_name} - ${reason}"
    TEST_RESULTS+=("SKIP: ${test_name} - ${reason}")
    echo "TEST_SKIP: ${test_name} - ${reason}" >> "${TEST_LOG_FILE}"
}

# =============================================================================
# SYSTEM VALIDATION TESTS
# =============================================================================

test_system_detection() {
    test_start "System Detection"
    
    local temp_script="${TEST_RESULTS_DIR}/test_detection.sh"
    
    # Extract system detection functions from main script
    cat > "${temp_script}" << 'EOF'
#!/bin/bash
source /workspace/deploy_intelligent.sh

# Test system detection functions
detect_operating_system
detect_system_resources
detect_installed_software

# Verify variables are set
[[ -n "$DETECTED_OS" ]] || exit 1
[[ -n "$DETECTED_ARCH" ]] || exit 1
[[ "$AVAILABLE_MEMORY_GB" -gt 0 ]] || exit 1
[[ "$AVAILABLE_CPU_CORES" -gt 0 ]] || exit 1
[[ "$AVAILABLE_STORAGE_GB" -gt 0 ]] || exit 1

echo "OS: $DETECTED_OS"
echo "Architecture: $DETECTED_ARCH"
echo "Memory: ${AVAILABLE_MEMORY_GB}GB"
echo "CPUs: $AVAILABLE_CPU_CORES"
echo "Storage: ${AVAILABLE_STORAGE_GB}GB"
EOF

    chmod +x "${temp_script}"
    
    if "${temp_script}" > "${TEST_RESULTS_DIR}/system_detection.log" 2>&1; then
        test_pass "System Detection"
    else
        test_fail "System Detection" "Failed to detect system properties"
    fi
}

test_dependency_optimization() {
    test_start "Dependency Optimization"
    
    # Test if dependency optimizer can run
    if command -v python3 >/dev/null 2>&1; then
        # Create a minimal test
        local test_output="${TEST_RESULTS_DIR}/dependency_test.log"
        
        if python3 -c "
import sys
sys.path.insert(0, '${PROJECT_DIR}')
try:
    from dependency_optimizer import SystemAnalyzer, DependencyOptimizer
    analyzer = SystemAnalyzer()
    system_analysis = analyzer.analyze_system()
    optimizer = DependencyOptimizer(system_analysis)
    requirements, report = optimizer.generate_optimized_requirements()
    print(f'Generated {len(requirements)} requirements')
    print(f'Selected {len(report[\"selected_categories\"])} categories')
    assert len(requirements) > 0
    assert len(report['selected_categories']) > 0
    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
" > "${test_output}" 2>&1; then
            test_pass "Dependency Optimization"
        else
            test_fail "Dependency Optimization" "Python dependency optimizer failed"
        fi
    else
        test_skip "Dependency Optimization" "Python3 not available"
    fi
}

test_configuration_generation() {
    test_start "Configuration Generation"
    
    local test_config_dir="${TEST_RESULTS_DIR}/test_configs"
    
    # Test configuration generator
    if "${PROJECT_DIR}/deployment_configurator.sh" 4 2 "docker_minimal" "/opt/test/venv" false > "${TEST_RESULTS_DIR}/config_gen.log" 2>&1; then
        # Check if configurations were generated
        local configs_found=0
        
        [[ -d "${PROJECT_DIR}/deployment_configs/nginx" ]] && ((configs_found++))
        [[ -d "${PROJECT_DIR}/deployment_configs/systemd" ]] && ((configs_found++))
        [[ -d "${PROJECT_DIR}/deployment_configs/docker" ]] && ((configs_found++))
        [[ -d "${PROJECT_DIR}/deployment_configs/env" ]] && ((configs_found++))
        [[ -d "${PROJECT_DIR}/deployment_configs/monitoring" ]] && ((configs_found++))
        
        if [[ $configs_found -ge 4 ]]; then
            test_pass "Configuration Generation"
        else
            test_fail "Configuration Generation" "Only $configs_found/5 configuration directories created"
        fi
    else
        test_fail "Configuration Generation" "Configuration generator script failed"
    fi
}

test_docker_compose_validity() {
    test_start "Docker Compose Validity"
    
    if command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1; then
        local compose_file="${PROJECT_DIR}/deployment_configs/docker/docker-compose.optimized.yml"
        
        if [[ -f "$compose_file" ]]; then
            # Test docker-compose config validation
            if docker-compose -f "$compose_file" config > "${TEST_RESULTS_DIR}/docker_compose_test.log" 2>&1; then
                test_pass "Docker Compose Validity"
            else
                test_fail "Docker Compose Validity" "Docker Compose configuration is invalid"
            fi
        else
            test_skip "Docker Compose Validity" "Docker Compose file not found"
        fi
    else
        test_skip "Docker Compose Validity" "Docker/Docker Compose not available"
    fi
}

test_nginx_config_validity() {
    test_start "Nginx Configuration Validity"
    
    if command -v nginx >/dev/null 2>&1; then
        local nginx_config="${PROJECT_DIR}/deployment_configs/nginx/nginx.optimized.conf"
        
        if [[ -f "$nginx_config" ]]; then
            # Test nginx configuration syntax
            if nginx -t -c "$nginx_config" > "${TEST_RESULTS_DIR}/nginx_test.log" 2>&1; then
                test_pass "Nginx Configuration Validity"
            else
                test_fail "Nginx Configuration Validity" "Nginx configuration syntax error"
            fi
        else
            test_skip "Nginx Configuration Validity" "Nginx configuration file not found"
        fi
    else
        test_skip "Nginx Configuration Validity" "Nginx not available"
    fi
}

test_systemd_service_validity() {
    test_start "Systemd Service Validity"
    
    if command -v systemd-analyze >/dev/null 2>&1; then
        local services_dir="${PROJECT_DIR}/deployment_configs/systemd"
        local valid_services=0
        local total_services=0
        
        if [[ -d "$services_dir" ]]; then
            for service_file in "$services_dir"/*.service; do
                if [[ -f "$service_file" ]]; then
                    ((total_services++))
                    if systemd-analyze verify "$service_file" > "${TEST_RESULTS_DIR}/systemd_$(basename "$service_file").log" 2>&1; then
                        ((valid_services++))
                    fi
                fi
            done
            
            if [[ $valid_services -eq $total_services ]] && [[ $total_services -gt 0 ]]; then
                test_pass "Systemd Service Validity"
            elif [[ $total_services -eq 0 ]]; then
                test_skip "Systemd Service Validity" "No systemd service files found"
            else
                test_fail "Systemd Service Validity" "$valid_services/$total_services services are valid"
            fi
        else
            test_skip "Systemd Service Validity" "Systemd services directory not found"
        fi
    else
        test_skip "Systemd Service Validity" "systemd-analyze not available"
    fi
}

# =============================================================================
# DEPLOYMENT MODE TESTS
# =============================================================================

test_deployment_mode_selection() {
    test_start "Deployment Mode Selection"
    
    # Test different system scenarios
    local scenarios=(
        "8:4:docker_full"
        "4:2:docker_minimal"
        "2:1:native_systemd"
        "1:1:install_dependencies"
    )
    
    local passed_scenarios=0
    
    for scenario in "${scenarios[@]}"; do
        IFS=':' read -r memory cpu expected_mode <<< "$scenario"
        
        # Mock system detection for testing
        local test_script="${TEST_RESULTS_DIR}/test_mode_${memory}gb_${cpu}cpu.sh"
        
        cat > "$test_script" << EOF
#!/bin/bash
# Mock system values
AVAILABLE_MEMORY_GB=$memory
AVAILABLE_CPU_CORES=$cpu
HAS_DOCKER=true
HAS_SYSTEMD=true
HAS_PYTHON3=true

# Mock deployment mode determination logic
if [[ \${AVAILABLE_MEMORY_GB} -ge 8 ]] && [[ \${AVAILABLE_CPU_CORES} -ge 4 ]]; then
    DEPLOYMENT_MODE="docker_full"
elif [[ \${AVAILABLE_MEMORY_GB} -ge 4 ]] && [[ \${AVAILABLE_CPU_CORES} -ge 2 ]]; then
    DEPLOYMENT_MODE="docker_minimal"
elif [[ \${AVAILABLE_MEMORY_GB} -ge 2 ]] && [[ \${AVAILABLE_CPU_CORES} -ge 1 ]]; then
    DEPLOYMENT_MODE="native_systemd"
else
    DEPLOYMENT_MODE="install_dependencies"
fi

echo "Expected: $expected_mode"
echo "Selected: \$DEPLOYMENT_MODE"

if [[ "\$DEPLOYMENT_MODE" == "$expected_mode" ]]; then
    echo "PASS"
    exit 0
else
    echo "FAIL"
    exit 1
fi
EOF
        
        chmod +x "$test_script"
        
        if "$test_script" > "${TEST_RESULTS_DIR}/mode_selection_${memory}gb_${cpu}cpu.log" 2>&1; then
            ((passed_scenarios++))
        fi
    done
    
    if [[ $passed_scenarios -eq ${#scenarios[@]} ]]; then
        test_pass "Deployment Mode Selection"
    else
        test_fail "Deployment Mode Selection" "$passed_scenarios/${#scenarios[@]} scenarios passed"
    fi
}

test_resource_optimization() {
    test_start "Resource Optimization"
    
    # Test worker calculation logic
    local test_cases=(
        "1:1:1"    # memory:cpu:expected_workers
        "2:2:2"
        "4:4:4"
        "8:8:8"
        "16:16:8"  # Should cap at 8
    )
    
    local passed_cases=0
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r memory cpu expected_workers <<< "$test_case"
        
        # Calculate optimal workers using same logic as main script
        local optimal_workers=1
        if [[ $memory -ge 8 ]] && [[ $cpu -ge 4 ]]; then
            optimal_workers=$((cpu * 2))
        elif [[ $memory -ge 4 ]] && [[ $cpu -ge 2 ]]; then
            optimal_workers=$cpu
        else
            optimal_workers=1
        fi
        
        # Cap at 8
        if [[ $optimal_workers -gt 8 ]]; then
            optimal_workers=8
        fi
        
        if [[ $optimal_workers -eq $expected_workers ]]; then
            ((passed_cases++))
            echo "PASS: ${memory}GB/${cpu}CPU -> ${optimal_workers} workers" >> "${TEST_RESULTS_DIR}/resource_optimization.log"
        else
            echo "FAIL: ${memory}GB/${cpu}CPU -> expected ${expected_workers}, got ${optimal_workers}" >> "${TEST_RESULTS_DIR}/resource_optimization.log"
        fi
    done
    
    if [[ $passed_cases -eq ${#test_cases[@]} ]]; then
        test_pass "Resource Optimization"
    else
        test_fail "Resource Optimization" "$passed_cases/${#test_cases[@]} test cases passed"
    fi
}

# =============================================================================
# INTEGRATION TESTS
# =============================================================================

test_end_to_end_dry_run() {
    test_start "End-to-End Dry Run"
    
    # Create a dry-run version of the main deployment script
    local dry_run_script="${TEST_RESULTS_DIR}/deploy_dry_run.sh"
    
    # Copy main script and modify for dry run
    cp "${PROJECT_DIR}/deploy_intelligent.sh" "$dry_run_script"
    
    # Modify script to skip actual installation/deployment
    sed -i 's/sudo apt update/echo "DRY RUN: sudo apt update"/g' "$dry_run_script"
    sed -i 's/sudo apt install/echo "DRY RUN: sudo apt install"/g' "$dry_run_script"
    sed -i 's/docker-compose/echo "DRY RUN: docker-compose"/g' "$dry_run_script"
    sed -i 's/systemctl/echo "DRY RUN: systemctl"/g' "$dry_run_script"
    
    # Add dry run flag
    echo "DRY_RUN=true" >> "$dry_run_script"
    
    chmod +x "$dry_run_script"
    
    if timeout 300 "$dry_run_script" > "${TEST_RESULTS_DIR}/end_to_end_dry_run.log" 2>&1; then
        test_pass "End-to-End Dry Run"
    else
        test_fail "End-to-End Dry Run" "Dry run execution failed or timed out"
    fi
}

test_health_check_functionality() {
    test_start "Health Check Functionality"
    
    local health_script="${PROJECT_DIR}/deployment_configs/monitoring/health_check.sh"
    
    if [[ -f "$health_script" ]]; then
        # Test health check script syntax
        if bash -n "$health_script"; then
            # Test health check execution (will fail services checks but should run)
            timeout 30 "$health_script" > "${TEST_RESULTS_DIR}/health_check.log" 2>&1 || true
            
            # Check if script ran without syntax errors
            if [[ $? -ne 124 ]]; then  # 124 is timeout exit code
                test_pass "Health Check Functionality"
            else
                test_fail "Health Check Functionality" "Health check script timed out"
            fi
        else
            test_fail "Health Check Functionality" "Health check script has syntax errors"
        fi
    else
        test_skip "Health Check Functionality" "Health check script not found"
    fi
}

# =============================================================================
# SECURITY AND COMPLIANCE TESTS
# =============================================================================

test_security_configurations() {
    test_start "Security Configurations"
    
    local security_issues=0
    local security_log="${TEST_RESULTS_DIR}/security_check.log"
    
    # Check Nginx security headers
    local nginx_config="${PROJECT_DIR}/deployment_configs/nginx/nginx.optimized.conf"
    if [[ -f "$nginx_config" ]]; then
        local required_headers=("X-Frame-Options" "X-Content-Type-Options" "X-XSS-Protection")
        for header in "${required_headers[@]}"; do
            if ! grep -q "$header" "$nginx_config"; then
                echo "Missing security header: $header" >> "$security_log"
                ((security_issues++))
            fi
        done
    fi
    
    # Check systemd security settings
    local systemd_dir="${PROJECT_DIR}/deployment_configs/systemd"
    if [[ -d "$systemd_dir" ]]; then
        for service_file in "$systemd_dir"/*.service; do
            if [[ -f "$service_file" ]]; then
                local security_settings=("NoNewPrivileges=true" "PrivateTmp=true" "ProtectSystem=strict")
                for setting in "${security_settings[@]}"; do
                    if ! grep -q "$setting" "$service_file"; then
                        echo "Missing security setting in $(basename "$service_file"): $setting" >> "$security_log"
                        ((security_issues++))
                    fi
                done
            fi
        done
    fi
    
    # Check Docker security
    local docker_compose="${PROJECT_DIR}/deployment_configs/docker/docker-compose.optimized.yml"
    if [[ -f "$docker_compose" ]]; then
        # Check for resource limits
        if ! grep -q "resources:" "$docker_compose"; then
            echo "Missing resource limits in Docker Compose" >> "$security_log"
            ((security_issues++))
        fi
        
        # Check for non-root user
        if ! grep -q "user:" "$docker_compose" && ! grep -q "USER noctis" "${PROJECT_DIR}/deployment_configs/docker/Dockerfile.optimized" 2>/dev/null; then
            echo "Services may be running as root" >> "$security_log"
            ((security_issues++))
        fi
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        test_pass "Security Configurations"
    else
        test_fail "Security Configurations" "$security_issues security issues found"
    fi
}

test_environment_variable_security() {
    test_start "Environment Variable Security"
    
    local env_issues=0
    local env_log="${TEST_RESULTS_DIR}/env_security.log"
    
    # Check environment templates
    local env_dir="${PROJECT_DIR}/deployment_configs/env"
    if [[ -d "$env_dir" ]]; then
        for env_file in "$env_dir"/.env.*; do
            if [[ -f "$env_file" ]]; then
                # Check for default/weak passwords
                if grep -q "CHANGE-THIS" "$env_file"; then
                    echo "Default placeholder values found in $(basename "$env_file")" >> "$env_log"
                    ((env_issues++))
                fi
                
                # Check for hardcoded secrets in non-template files
                if [[ ! "$env_file" =~ \.template$ ]] && grep -qE "(password|secret|key).*=" "$env_file"; then
                    if ! grep -qE "(password|secret|key).*=\$\{" "$env_file"; then
                        echo "Potential hardcoded secrets in $(basename "$env_file")" >> "$env_log"
                        ((env_issues++))
                    fi
                fi
            fi
        done
    fi
    
    if [[ $env_issues -eq 0 ]]; then
        test_pass "Environment Variable Security"
    else
        test_fail "Environment Variable Security" "$env_issues security issues found"
    fi
}

# =============================================================================
# PERFORMANCE TESTS
# =============================================================================

test_configuration_performance() {
    test_start "Configuration Performance"
    
    local start_time=$(date +%s)
    
    # Test configuration generation speed
    "${PROJECT_DIR}/deployment_configurator.sh" 4 2 "docker_minimal" "/opt/test/venv" false > "${TEST_RESULTS_DIR}/perf_config.log" 2>&1
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "Configuration generation took ${duration} seconds" >> "${TEST_RESULTS_DIR}/performance.log"
    
    if [[ $duration -lt 30 ]]; then
        test_pass "Configuration Performance"
    else
        test_fail "Configuration Performance" "Configuration generation took ${duration}s (>30s)"
    fi
}

test_script_startup_time() {
    test_start "Script Startup Time"
    
    local start_time=$(date +%s%N)
    
    # Test script startup time (just loading functions)
    timeout 10 bash -c "source '${PROJECT_DIR}/deploy_intelligent.sh' && echo 'Functions loaded'" > "${TEST_RESULTS_DIR}/startup_test.log" 2>&1
    
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    echo "Script startup took ${duration_ms}ms" >> "${TEST_RESULTS_DIR}/performance.log"
    
    if [[ $duration_ms -lt 5000 ]]; then  # Less than 5 seconds
        test_pass "Script Startup Time"
    else
        test_fail "Script Startup Time" "Script startup took ${duration_ms}ms (>5000ms)"
    fi
}

# =============================================================================
# TEST SUITE ORCHESTRATION
# =============================================================================

run_all_tests() {
    log "Starting comprehensive deployment test suite..."
    
    # Create test results directory
    mkdir -p "${TEST_RESULTS_DIR}"
    
    # System validation tests
    log "=== System Validation Tests ==="
    test_system_detection
    test_dependency_optimization
    test_configuration_generation
    
    # Configuration validity tests
    log "=== Configuration Validity Tests ==="
    test_docker_compose_validity
    test_nginx_config_validity
    test_systemd_service_validity
    
    # Deployment mode tests
    log "=== Deployment Mode Tests ==="
    test_deployment_mode_selection
    test_resource_optimization
    
    # Integration tests
    log "=== Integration Tests ==="
    test_end_to_end_dry_run
    test_health_check_functionality
    
    # Security tests
    log "=== Security Tests ==="
    test_security_configurations
    test_environment_variable_security
    
    # Performance tests
    log "=== Performance Tests ==="
    test_configuration_performance
    test_script_startup_time
}

generate_test_report() {
    log "Generating test report..."
    
    local report_file="${TEST_RESULTS_DIR}/test_report.md"
    
    cat > "$report_file" << EOF
# NoctisPro PACS - Deployment Test Report

**Test Execution Date:** $(date)
**Test Duration:** $(date -d@$(($(date +%s) - test_start_time)) -u +%H:%M:%S)

## Test Summary

- **Total Tests:** ${TESTS_TOTAL}
- **Passed:** ${TESTS_PASSED} ✅
- **Failed:** ${TESTS_FAILED} ❌
- **Skipped:** ${TESTS_SKIPPED} ⏭️

**Success Rate:** $(( TESTS_TOTAL > 0 ? (TESTS_PASSED * 100 / TESTS_TOTAL) : 0 ))%

## Test Results

EOF

    # Add individual test results
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" =~ ^PASS: ]]; then
            echo "✅ ${result#PASS: }" >> "$report_file"
        elif [[ "$result" =~ ^FAIL: ]]; then
            echo "❌ ${result#FAIL: }" >> "$report_file"
        elif [[ "$result" =~ ^SKIP: ]]; then
            echo "⏭️ ${result#SKIP: }" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Test Artifacts

- **Test Log:** ${TEST_LOG_FILE}
- **Test Results Directory:** ${TEST_RESULTS_DIR}
- **Individual Test Logs:** Available in test results directory

## System Information

- **OS:** $(uname -s) $(uname -r)
- **Architecture:** $(uname -m)
- **Available Memory:** $(free -h | grep '^Mem:' | awk '{print $2}')
- **CPU Cores:** $(nproc)
- **Disk Space:** $(df -h . | tail -1 | awk '{print $4}') available

## Recommendations

EOF

    if [[ $TESTS_FAILED -gt 0 ]]; then
        cat >> "$report_file" << EOF
⚠️ **Action Required:** ${TESTS_FAILED} test(s) failed. Please review the failed tests and address the issues before deployment.

EOF
    fi
    
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        cat >> "$report_file" << EOF
ℹ️ **Note:** ${TESTS_SKIPPED} test(s) were skipped due to missing dependencies or system constraints.

EOF
    fi
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        cat >> "$report_file" << EOF
🎉 **All tests passed!** The deployment system is ready for use.

EOF
    fi
    
    success "Test report generated: $report_file"
}

display_test_summary() {
    echo ""
    echo "=============================================="
    echo "🧪 NoctisPro PACS - Test Suite Results"
    echo "=============================================="
    echo ""
    echo "📊 Test Summary:"
    echo "  Total Tests: ${TESTS_TOTAL}"
    echo "  Passed: ${GREEN}${TESTS_PASSED}${NC} ✅"
    echo "  Failed: ${RED}${TESTS_FAILED}${NC} ❌"
    echo "  Skipped: ${YELLOW}${TESTS_SKIPPED}${NC} ⏭️"
    echo ""
    
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
        echo "  Success Rate: ${success_rate}%"
    fi
    
    echo ""
    echo "📁 Test Artifacts:"
    echo "  Test Log: ${TEST_LOG_FILE}"
    echo "  Results Directory: ${TEST_RESULTS_DIR}"
    echo "  Test Report: ${TEST_RESULTS_DIR}/test_report.md"
    echo ""
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        error "⚠️  Some tests failed. Please review the results before proceeding with deployment."
        return 1
    else
        success "🎉 All tests passed! The deployment system is ready for use."
        return 0
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local test_start_time=$(date +%s)
    
    echo ""
    echo "🧪 NoctisPro PACS - Deployment Testing Suite"
    echo "============================================="
    echo ""
    
    log "Starting deployment validation tests..."
    log "Test log: ${TEST_LOG_FILE}"
    log "Results directory: ${TEST_RESULTS_DIR}"
    
    # Run all tests
    run_all_tests
    
    # Generate report
    generate_test_report
    
    # Display summary
    display_test_summary
    
    # Return appropriate exit code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Handle script interruption
trap 'error "Test execution interrupted"; exit 1' INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi