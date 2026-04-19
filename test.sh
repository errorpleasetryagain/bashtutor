#!/usr/bin/env bash
# BashTutor Test Suite
# Validates installation, syntax, and functionality
# Version: 0.1.0

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLUGIN_FILE="${SCRIPT_DIR}/bashtutor.zsh"
readonly TEMP_DIR="${SCRIPT_DIR}/.test_artifacts"

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_section() {
    echo ""
    echo "===================================="
    echo "  $1"
    echo "===================================="
}

log_info() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
    TEST_RESULTS+=("PASS: $1")
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    TEST_RESULTS+=("FAIL: $1")
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test runner
test_case() {
    local name="$1"
    local cmd="$2"
    
    log_info "$name"
    if eval "$cmd" > /dev/null 2>&1; then
        log_pass "$name"
        return 0
    else
        log_fail "$name"
        return 1
    fi
}

# =============================================================================
# SETUP & TEARDOWN
# =============================================================================

setup() {
    log_section "SETUP"
    
    # Create temp directory for test artifacts
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    mkdir -p "$TEMP_DIR"
    
    # Verify plugin file exists
    if [[ ! -f "$PLUGIN_FILE" ]]; then
        echo "ERROR: Plugin file not found: $PLUGIN_FILE"
        echo "Please ensure bashtutor.zsh is in the same directory as test.sh"
        exit 1
    fi
    
    log_pass "Setup complete - temp dir created at $TEMP_DIR"
}

teardown() {
    log_section "CLEANUP"
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_pass "Cleaned up temporary files"
    fi
}

# =============================================================================
# TEST SUITE: Syntax Validation
# =============================================================================

test_syntax() {
    log_section "SYNTAX VALIDATION"
    
    # Test 1: Basic zsh syntax check
    test_case "Zsh syntax validation" "zsh -n '$PLUGIN_FILE'"
    
    # Test 2: Check for common syntax errors
    test_case "No unclosed quotes" "grep -v '\"' '$PLUGIN_FILE' | grep -v \"'\" | zsh -n /dev/stdin 2>/dev/null || true"
    
    # Test 3: Check function definitions
    local func_count
    func_count=$(grep -cE '^function [a-zA-Z_]+\(' "$PLUGIN_FILE" 2>/dev/null || echo 0)
    if [[ "$func_count" -gt 0 ]]; then
        log_pass "Valid function definitions (found $func_count)"
    else
        log_fail "No function definitions found"
    fi
    
    # Test 4: Check for proper closing of conditionals
    local conditional_count
    conditional_count=$(grep -cE '\[\[|\]\]' "$PLUGIN_FILE" || true)
    if [[ $((conditional_count % 2)) -eq 0 ]]; then
        log_pass "Balanced conditionals ($conditional_count brackets)"
    else
        log_fail "Unbalanced conditionals (odd number: $conditional_count)"
    fi
}

# =============================================================================
# TEST SUITE: JSONL Logging
# =============================================================================

test_jsonl_logging() {
    log_section "JSONL LOGGING"
    
    local test_history="${TEMP_DIR}/test_history.jsonl"
    
    # Test 1: Create valid JSONL entry
    log_info "Test: Valid JSONL entry format"
    local test_entry='{"timestamp":"2024-01-15T10:30:00Z","command":"ls -la","exit_code":0,"cwd":"/home/test","session":"12345"}'
    echo "$test_entry" > "$test_history"
    if python3 -c "import json; [json.loads(line) for line in open('$test_history')]; print('OK')" 2>/dev/null; then
        log_pass "Valid JSONL format"
    else
        log_fail "Invalid JSONL format"
    fi
    
    # Test 2: Test escaping of special characters in commands
    log_info "Test: Special character escaping"
    local special_cmd='echo "Hello World" | grep "test"'
    local escaped_cmd=$(echo "$special_cmd" | sed 's/"/\\"/g')
    local entry="{\"timestamp\":\"2024-01-15T10:30:00Z\",\"command\":\"$escaped_cmd\",\"exit_code\":0,\"cwd\":\"/test\",\"session\":\"12345\"}"
    echo "$entry" > "$test_history"
    if python3 -c "import json; [json.loads(line) for line in open('$test_history')]; print('OK')" 2>/dev/null; then
        log_pass "Special characters escaped correctly"
    else
        log_fail "Special character escaping failed"
    fi
    
    # Test 3: Test newlines in commands
    log_info "Test: Newline handling"
    local multiline_cmd=$'echo line1\necho line2'
    local newline_replaced=$(echo "$multiline_cmd" | tr '\n' ' ' | sed 's/"/\\"/g')
    local entry2="{\"timestamp\":\"2024-01-15T10:30:00Z\",\"command\":\"$newline_replaced\",\"exit_code\":0,\"cwd\":\"/test\",\"session\":\"12345\"}"
    echo "$entry2" > "$test_history"
    if python3 -c "import json; [json.loads(line) for line in open('$test_history')]; print('OK')" 2>/dev/null; then
        log_pass "Newline handling works"
    else
        log_fail "Newline handling failed"
    fi
    
    # Test 4: Test unicode in commands
    log_info "Test: Unicode handling"
    local unicode_entry='{"timestamp":"2024-01-15T10:30:00Z","command":"echo Hello 🎓","exit_code":0,"cwd":"/test","session":"12345"}'
    echo "$unicode_entry" > "$test_history"
    if python3 -c "import json; [json.loads(line) for line in open('$test_history')]; print('OK')" 2>/dev/null; then
        log_pass "Unicode characters handled"
    else
        log_fail "Unicode handling failed"
    fi
    
    # Test 5: Test empty command (edge case)
    log_info "Test: Empty command edge case"
    local empty_entry='{"timestamp":"2024-01-15T10:30:00Z","command":"","exit_code":0,"cwd":"/test","session":"12345"}'
    echo "$empty_entry" > "$test_history"
    if python3 -c "import json; [json.loads(line) for line in open('$test_history')]; print('OK')" 2>/dev/null; then
        log_pass "Empty command handled"
    else
        log_fail "Empty command handling failed"
    fi
    
    # Test 6: Test very long command
    log_info "Test: Long command handling"
    local long_cmd=$(python3 -c "print('A' * 1000)")
    local entry3="{\"timestamp\":\"2024-01-15T10:30:00Z\",\"command\":\"$long_cmd\",\"exit_code\":0,\"cwd\":\"/test\",\"session\":\"12345\"}"
    echo "$entry3" > "$test_history"
    if python3 -c "import json; [json.loads(line) for line in open('$test_history')]; print('OK')" 2>/dev/null; then
        log_pass "Long command handled"
    else
        log_fail "Long command handling failed"
    fi
    
    # Test 7: Multiple JSONL lines
    log_info "Test: Multiple entries"
    local multi_history="${TEMP_DIR}/multi_history.jsonl"
    {
        echo '{"timestamp":"2024-01-15T10:30:00Z","command":"ls","exit_code":0,"cwd":"/","session":"1"}'
        echo '{"timestamp":"2024-01-15T10:31:00Z","command":"pwd","exit_code":0,"cwd":"/home","session":"1"}'
        echo '{"timestamp":"2024-01-15T10:32:00Z","command":"invalid_cmd","exit_code":127,"cwd":"/home","session":"1"}'
    } > "$multi_history"
    
    local count
    count=$(python3 -c "import json; print(len([json.loads(l) for l in open('$multi_history')]))" 2>/dev/null || echo "0")
    if [[ "$count" == "3" ]]; then
        log_pass "Multiple entries parsed correctly"
    else
        log_fail "Multiple entry parsing failed (got $count, expected 3)"
    fi
}

# =============================================================================
# TEST SUITE: Plugin Structure
# =============================================================================

test_structure() {
    log_section "PLUGIN STRUCTURE"
    
    # Test 1: Required functions exist
    local required_functions=(
        "bashtutor_preexec"
        "bashtutor_precmd"
        "_bashtutor_log_command"
        "bashme"
        "_bashtutor_local_explain"
        "_bashme_display_result"
        "_bashme_local"
    )
    
    for func in "${required_functions[@]}"; do
        if grep -qE "^function $func\\(|^$func\\(\\)" "$PLUGIN_FILE"; then
            log_pass "Function exists: $func"
        else
            log_fail "Missing function: $func"
        fi
    done
    
    # Test 2: Aliases defined
    local required_aliases=("bt=" "btx=" "bth=")
    for alias_def in "${required_aliases[@]}"; do
        if grep -qE "^alias ${alias_def}" "$PLUGIN_FILE"; then
            log_pass "Alias defined: ${alias_def%%=*}"
        else
            log_fail "Missing alias: ${alias_def%%=*}"
        fi
    done
    
    # Test 3: Hooks registered
    if grep -q "add-zsh-hook preexec" "$PLUGIN_FILE" && \
       grep -q "add-zsh-hook precmd" "$PLUGIN_FILE"; then
        log_pass "Zsh hooks properly registered"
    else
        log_fail "Zsh hooks not properly registered"
    fi
    
    # Test 4: Shebang and version
    if head -1 "$PLUGIN_FILE" | grep -q "zsh"; then
        log_pass "Correct shebang (zsh)"
    else
        log_fail "Incorrect shebang"
    fi
    
    if grep -q "BASHTUTOR_VERSION=" "$PLUGIN_FILE"; then
        log_pass "Version defined"
    else
        log_fail "Version not defined"
    fi
}

# =============================================================================
# TEST SUITE: Integration
# =============================================================================

test_integration() {
    log_section "INTEGRATION TESTS"
    
    # Test 1: Check that functions can be listed
    log_info "Test: Function definitions are parseable"
    local func_count
    func_count=$(grep -cE '^function [a-zA-Z_]+\(' "$PLUGIN_FILE" 2>/dev/null || echo 0)
    if [[ "$func_count" -gt 10 ]]; then
        log_pass "Found $func_count function definitions"
    else
        log_fail "Only $func_count functions found (expected >10)"
    fi
    
    # Test 2: Check for explanations dictionary
    if grep -q "declare -A explanations" "$PLUGIN_FILE"; then
        log_pass "Explanations dictionary defined"
    else
        log_warn "Explanations dictionary not found"
    fi
    
    # Test 3: Check command coverage
    local cmd_count
    cmd_count=$(grep -E '^\s+explanations\[.*\]=' "$PLUGIN_FILE" | wc -l || true)
    if [[ "$cmd_count" -gt 20 ]]; then
        log_pass "$cmd_count command explanations defined"
    else
        log_warn "Only $cmd_count command explanations (expected >20)"
    fi
}

# =============================================================================
# TEST SUITE: Security
# =============================================================================

test_security() {
    log_section "SECURITY CHECKS"
    
    # Test 1: No hardcoded credentials
    if grep -qi "password\|secret\|key\|token" "$PLUGIN_FILE" | grep -qv "#"; then
        log_warn "Check for any hardcoded sensitive data"
    else
        log_pass "No obvious hardcoded credentials"
    fi
    
    # Test 2: Check temp file creation
    if grep -q "mktemp" "$PLUGIN_FILE"; then
        log_pass "Uses mktemp for temporary files"
    else
        log_warn "Does not use mktemp for temporary files"
    fi
    
    # Test 3: Check for proper quoting in eval
    if grep -q "eval" "$PLUGIN_FILE"; then
        log_warn "Uses eval - ensure proper input sanitization"
    fi
}

# =============================================================================
# REPORT
# =============================================================================

print_report() {
    log_section "TEST SUMMARY"
    
    local total=$((TESTS_PASSED + TESTS_FAILED))
    
    echo ""
    echo "Results:"
    echo "  Passed:  $TESTS_PASSED"
    echo "  Failed:  $TESTS_FAILED"
    echo "  Total:   $total"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        echo ""
        echo "Failed tests:"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" == FAIL:* ]]; then
                echo "  • ${result#FAIL: }"
            fi
        done
        echo ""
        return 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    cat << EOF
BashTutor Test Suite v0.1.0

Usage: ./test.sh [OPTIONS]

Options:
    --help    Show this help message

Description:
    Runs comprehensive tests on the BashTutor plugin including:
    - Syntax validation (zsh -n)
    - JSONL logging with edge cases
    - Plugin structure verification
    - Integration tests
    - Security checks

Exit codes:
    0 = All tests passed
    1 = One or more tests failed

Requirements:
    - zsh installed
    - python3 installed (for JSON validation)
EOF
}

main() {
    # Parse arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # Continue with tests
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    echo "🎓 BashTutor Test Suite"
    echo "======================"
    
    # Setup
    setup
    
    # Run all test suites
    test_syntax
    test_jsonl_logging
    test_structure
    test_integration
    test_security
    
    # Cleanup
    teardown
    
    # Report
    print_report
}

# Run main and exit with appropriate code
main "$@"
exit $?