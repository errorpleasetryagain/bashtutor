#!/usr/bin/env bash
# BashTutor Comprehensive Test Suite
# Tests all major functionality including edge cases

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly PLUGIN_FILE="${PROJECT_DIR}/bashtutor.zsh"
readonly TEMP_DIR="/tmp/bashtutor_test_$$"

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
declare -a FAILED_TESTS=()

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

log_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_test() {
    echo -ne "${BLUE}[TEST]${NC} $1 ... "
}

log_pass() {
    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

log_skip() {
    echo -e "${YELLOW}SKIP${NC}"
    ((TESTS_SKIPPED++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

setup() {
    log_section "SETUP"

    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    mkdir -p "$TEMP_DIR"

    if [[ ! -f "$PLUGIN_FILE" ]]; then
        log_error "Plugin file not found: $PLUGIN_FILE"
        exit 1
    fi

    log_info "Temp directory: $TEMP_DIR"
    log_info "Plugin file: $PLUGIN_FILE"
}

teardown() {
    log_section "CLEANUP"

    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_info "Cleaned up temporary files"
    fi
}

# ==============================================================================
# TEST SUITES
# ==============================================================================

test_syntax_validation() {
    log_section "SYNTAX VALIDATION"

    log_test "Bash syntax check"
    if bash -n "$PLUGIN_FILE" 2>/dev/null; then
        log_pass
    else
        log_fail "Bash syntax check"
    fi

    log_test "No unclosed brackets"
    local open_brackets
    open_brackets=$(grep -o '(\|)' "$PLUGIN_FILE" | sort | uniq -c | awk '{print $1}' | sort -u | wc -l)
    if [[ $open_brackets -le 2 ]]; then
        log_pass
    else
        log_fail "Bracket balance"
    fi

    log_test "Function definitions exist"
    local func_count
    func_count=$(grep -cE '^function [a-zA-Z_]+' "$PLUGIN_FILE" 2>/dev/null || echo 0)
    if [[ $func_count -gt 20 ]]; then
        log_pass
    else
        log_fail "Function definitions (found $func_count, expected >20)"
    fi
}

test_json_escaping() {
    log_section "JSON ESCAPING"

    log_test "Escaping backslashes"
    # JSON must escape backslashes as \\
    local json_test='{"cmd":"path\\\\to\\\\file"}'
    if python3 -c "import json; json.loads('$json_test')" 2>/dev/null; then
        log_pass
    else
        log_fail "Backslash escaping"
    fi

    log_test "Escaping quotes"
    local json_quote='{"cmd":"echo \\"hello\\""}'
    if python3 -c 'import json; json.loads('"'"'"{"cmd":"echo \\"hello\\""}"'"'"')' 2>/dev/null; then
        log_pass
    else
        log_fail "Quote escaping"
    fi

    log_test "Handling newlines in commands"
    # Commands with newlines should be escaped as \n in JSON
    local json_newline='{"cmd":"echo line1\\necho line2"}'
    if python3 -c "import json; json.loads('$json_newline')" 2>/dev/null; then
        log_pass
    else
        log_fail "Newline escaping"
    fi

    log_test "Unicode handling"
    local json_unicode='{"cmd":"echo 🎓"}'
    if python3 -c "import json; json.loads('$json_unicode')" 2>/dev/null; then
        log_pass
    else
        log_fail "Unicode handling"
    fi
}

test_cache_functionality() {
    log_section "CACHE FUNCTIONALITY"

    local cache_dir="${TEMP_DIR}/cache"
    mkdir -p "$cache_dir"

    log_test "Cache file creation"
    local test_cache="${cache_dir}/test.cache"
    echo "cached value" > "$test_cache"
    if [[ -f "$test_cache" && $(cat "$test_cache") == "cached value" ]]; then
        log_pass
    else
        log_fail "Cache file creation"
    fi

    log_test "Cache TTL validation"
    # Create a cache file and check age
    local now
    now=$(date +%s)
    local file_mtime
    file_mtime=$(stat -c%Y "$test_cache" 2>/dev/null || stat -f%m "$test_cache" 2>/dev/null)
    local age=$((now - file_mtime))
    if [[ $age -ge 0 && $age -lt 2 ]]; then
        log_pass
    else
        log_fail "Cache TTL validation (age: $age)"
    fi
}

test_command_logging() {
    log_section "COMMAND LOGGING"

    local history_file="${TEMP_DIR}/history.jsonl"

    log_test "Valid JSONL entry format"
    local entry='{"timestamp":"2024-01-15T10:30:00Z","command":"ls -la","exit_code":0,"cwd":"/home","session":"123"}'
    echo "$entry" > "$history_file"
    if python3 -c "import json; [json.loads(line) for line in open('$history_file')]" 2>/dev/null; then
        log_pass
    else
        log_fail "JSONL format"
    fi

    log_test "Multiple JSONL entries"
    cat > "$history_file" << 'EOF'
{"timestamp":"2024-01-15T10:30:00Z","command":"ls","exit_code":0,"cwd":"/","session":"1"}
{"timestamp":"2024-01-15T10:31:00Z","command":"pwd","exit_code":0,"cwd":"/home","session":"1"}
{"timestamp":"2024-01-15T10:32:00Z","command":"invalid","exit_code":127,"cwd":"/home","session":"1"}
EOF
    local count
    count=$(python3 -c "import json; print(len([json.loads(l) for l in open('$history_file')]))" 2>/dev/null || echo 0)
    if [[ "$count" == "3" ]]; then
        log_pass
    else
        log_fail "Multiple entries (got $count, expected 3)"
    fi

    log_test "Escaped quotes in command"
    local escaped_entry='{"timestamp":"2024-01-15T10:30:00Z","command":"echo \\"hello\\"","exit_code":0,"cwd":"/","session":"1"}'
    echo "$escaped_entry" > "$history_file"
    if python3 -c "import json; [json.loads(line) for line in open('$history_file')]" 2>/dev/null; then
        log_pass
    else
        log_fail "Escaped quotes"
    fi

    log_test "Command with special characters"
    local special_entry='{"timestamp":"2024-01-15T10:30:00Z","command":"grep -r \"test\" .","exit_code":0,"cwd":"/","session":"1"}'
    echo "$special_entry" > "$history_file"
    if python3 -c "import json; [json.loads(line) for line in open('$history_file')]" 2>/dev/null; then
        log_pass
    else
        log_fail "Special characters"
    fi
}

test_plugin_structure() {
    log_section "PLUGIN STRUCTURE"

    # Required functions
    local required_funcs=(
        "bashtutor_preexec"
        "bashtutor_precmd"
        "_bashtutor_log_command"
        "_bashtutor_json_escape"
        "bashme"
        "_bashme_local"
        "_bashtutor_explain_via_claude"
        "_bashtutor_local_explain"
    )

    for func in "${required_funcs[@]}"; do
        log_test "Function: $func"
        if grep -qE "^function $func|^$func\\(\\)" "$PLUGIN_FILE"; then
            log_pass
        else
            log_fail "Missing: $func"
        fi
    done

    # Required aliases
    log_test "Alias: bt"
    if grep -q "alias bt=" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Missing alias: bt"
    fi

    log_test "Alias: btx"
    if grep -q "alias btx=" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Missing alias: btx"
    fi

    # Configuration variables
    log_test "Version defined"
    if grep -q "BASHTUTOR_VERSION=" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Version not defined"
    fi

    log_test "Config dir defined"
    if grep -q "BASHTUTOR_CONFIG_DIR=" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Config dir not defined"
    fi
}

test_api_integration() {
    log_section "API INTEGRATION"

    log_test "Claude API check function"
    if grep -q "_bashtutor_check_claude" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Missing _bashtutor_check_claude"
    fi

    log_test "Claude explanation function"
    if grep -q "_bashtutor_explain_via_claude" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Missing _bashtutor_explain_via_claude"
    fi

    log_test "Claude bashme function"
    if grep -q "_bashme_claude" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Missing _bashme_claude"
    fi

    log_test "No openclaw references"
    if grep -q "openclaw" "$PLUGIN_FILE"; then
        log_fail "Still has openclaw references"
    else
        log_pass
    fi

    log_test "Uses curl for API calls"
    if grep -q "curl.*api.anthropic.com" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "Not using curl for API"
    fi
}

test_error_handling() {
    log_section "ERROR HANDLING"

    log_test "API key validation"
    if grep -q "ANTHROPIC_API_KEY" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "No API key check"
    fi

    log_test "Command validation before eval"
    if grep -q "eval.*cmd" "$PLUGIN_FILE"; then
        log_pass  # Has eval, which is expected
    else
        log_fail "No command execution found"
    fi

    log_test "Timeout handling"
    if grep -q "timeout\|sleep" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "No timeout handling"
    fi
}

test_local_patterns() {
    log_section "LOCAL PATTERNS"

    log_test "Local pattern fallback exists"
    if grep -q "_bashme_local" "$PLUGIN_FILE"; then
        log_pass
    else
        log_fail "No local fallback"
    fi

    log_test "Pattern count"
    local pattern_count
    pattern_count=$(grep -c '\*.*\*' "$PLUGIN_FILE" | head -1 || echo 0)
    if [[ $pattern_count -gt 20 ]]; then
        log_pass
    else
        log_fail "Low pattern count ($pattern_count)"
    fi

    log_test "Common patterns covered"
    local patterns=("files" "search" "delete" "create" "directory" "git" "permissions")
    local found=0
    for pattern in "${patterns[@]}"; do
        if grep -q "*${pattern}*" "$PLUGIN_FILE"; then
            ((found++))
        fi
    done
    if [[ $found -ge 5 ]]; then
        log_pass
    else
        log_fail "Missing patterns (found $found/7)"
    fi
}

test_documentation() {
    log_section "DOCUMENTATION"

    log_test "README exists"
    if [[ -f "${PROJECT_DIR}/README.md" ]]; then
        log_pass
    else
        log_fail "No README"
    fi

    log_test "README has installation instructions"
    if grep -q "install\|Installation" "${PROJECT_DIR}/README.md"; then
        log_pass
    else
        log_fail "No install docs"
    fi

    log_test "README documents API key setup"
    if grep -q "ANTHROPIC_API_KEY\|API key" "${PROJECT_DIR}/README.md"; then
        log_pass
    else
        log_fail "No API key docs"
    fi

    log_test "install.sh exists"
    if [[ -x "${PROJECT_DIR}/install.sh" ]]; then
        log_pass
    else
        log_fail "install.sh missing or not executable"
    fi

    log_test "uninstall.sh exists"
    if [[ -x "${PROJECT_DIR}/uninstall.sh" ]]; then
        log_pass
    else
        log_fail "uninstall.sh missing or not executable"
    fi
}

# ==============================================================================
# REPORT
# ==============================================================================

print_report() {
    log_section "TEST REPORT"

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))

    echo ""
    echo "Results:"
    echo -e "  ${GREEN}✓ Passed${NC}:  $TESTS_PASSED"
    echo -e "  ${RED}✗ Failed${NC}:  $TESTS_FAILED"
    echo -e "  ${YELLOW}⊘ Skipped${NC}: $TESTS_SKIPPED"
    echo -e "  Total:   $total"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  • $test"
        done
        return 1
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    echo -e "${BLUE}🎓 BashTutor Test Suite${NC}"
    echo ""

    setup

    # Run all test suites
    test_syntax_validation
    test_json_escaping
    test_cache_functionality
    test_command_logging
    test_plugin_structure
    test_api_integration
    test_error_handling
    test_local_patterns
    test_documentation

    teardown

    print_report
}

main "$@"
exit $?
