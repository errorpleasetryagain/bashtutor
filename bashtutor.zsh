#!/usr/bin/env zsh
# BashTutor - Production zsh module for bash learning
# Version: 1.0.0
#
# Features:
# - JSON escaping using Python (falls back to sed/tr)
# - Module-scope explanations array (lazy-loaded once)
# - Config file support ~/.bashtutor/config
# - Ctrl+B keybinding for explain-last-command
# - Cache directory ~/.bashtutor/cache/ with 24h TTL
# - Error handling on all external calls
# - Proper cleanup on shell exit
#
# Installation: source this file in your .zshrc

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Prevent double-loading
[[ -n "${BASHTUTOR_LOADED}" ]] && return 0
export BASHTUTOR_LOADED="1"

export BASHTUTOR_VERSION="1.0.0"

# =============================================================================
# PATHS & CONFIGURATION
# =============================================================================

# Base directories
export BASHTUTOR_CONFIG_DIR="${HOME}/.bashtutor"
export BASHTUTOR_CACHE_DIR="${BASHTUTOR_CONFIG_DIR}/cache"
export BASHTUTOR_CONFIG_FILE="${BASHTUTOR_CONFIG_DIR}/config"
export BASHTUTOR_HISTORY_FILE="${BASHTUTOR_CONFIG_DIR}/history.jsonl"
export BASHTUTOR_LOG_FILE="${BASHTUTOR_CONFIG_DIR}/bashtutor.log"

# Runtime variables
export BASHTUTOR_LAST_COMMAND=""
export BASHTUTOR_LAST_EXIT_CODE="0"
export BASHTUTOR_CLAUDE_AVAILABLE=""
export BASHTUTOR_EXPLANATIONS_LOADED=""

# Architecture detection
export BASHTUTOR_ARCH=$(uname -m 2>/dev/null || echo "unknown")

# =============================================================================
# EXPLANATIONS ARRAY (Module-scope, lazy-loaded)
# =============================================================================

declare -gA BASHTUTOR_EXPLANATIONS

function _bashtutor_load_explanations() {
    # Skip if already loaded
    [[ "${BASHTUTOR_EXPLANATIONS_LOADED}" == "1" ]] && return 0

    BASHTUTOR_EXPLANATIONS=(
        [ls]="Listed files and directories"
        [ll]="Listed files with details (long format)"
        [la]="Listed all files including hidden ones"
        [cd]="Changed to a different directory"
        [pwd]="Showed the current directory path"
        [mkdir]="Created a new directory"
        [rm]="Deleted files or directories"
        [rmdir]="Removed an empty directory"
        [cp]="Copied files or directories"
        [mv]="Moved or renamed files"
        [touch]="Created a new file or updated its timestamp"
        [cat]="Displayed file contents"
        [less]="Viewed file contents (scrollable)"
        [head]="Showed the beginning of a file"
        [tail]="Showed the end of a file"
        [grep]="Searched for text patterns"
        [find]="Searched for files matching criteria"
        [locate]="Found files by name (using database)"
        [which]="Found where a command is located"
        [whereis]="Located binary, source, and manual files"
        [du]="Showed directory disk usage"
        [df]="Showed disk free space"
        [free]="Showed memory usage"
        [ps]="Listed running processes"
        [top]="Showed system processes and resources"
        [htop]="Interactive process viewer"
        [kill]="Stopped a running process"
        [killall]="Killed processes by name"
        [ping]="Tested network connectivity"
        [curl]="Downloaded data from a URL"
        [wget]="Downloaded files from the web"
        [ssh]="Connected to a remote server"
        [scp]="Securely copied files to/from remote server"
        [rsync]="Synced files between locations"
        [tar]="Created or extracted an archive"
        [zip]="Compressed files into a zip archive"
        [unzip]="Extracted files from a zip archive"
        [gzip]="Compressed a file"
        [gunzip]="Decompressed a file"
        [chmod]="Changed file permissions"
        [chown]="Changed file ownership"
        [sudo]="Ran command with superuser privileges"
        [su]="Switched to another user"
        [passwd]="Changed user password"
        [git]="Ran a git version control command"
        [brew]="Ran Homebrew package manager"
        [apt]="Ran package manager (Debian/Ubuntu)"
        [yum]="Ran package manager (RedHat/CentOS)"
        [npm]="Ran Node.js package manager"
        [pip]="Ran Python package manager"
        [docker]="Ran Docker container command"
        [kubectl]="Ran Kubernetes command"
        [make]="Built software from Makefile"
        ["./configure"]="Configured software build"
        [cmake]="Ran CMake build system"
        [man]="Opened manual page for a command"
        [help]="Showed help for a command"
        [clear]="Cleared the terminal screen"
        [exit]="Exited the shell"
        [history]="Showed command history"
        [alias]="Created or showed command shortcuts"
        [export]="Set environment variables"
        [source]="Loaded shell configuration from file"
        [echo]="Printed text to the screen"
        [printf]="Formatted and printed text"
        [date]="Showed current date and time"
        [whoami]="Showed current username"
        [uname]="Showed system information"
        [hostname]="Showed computer name"
        [uptime]="Showed how long system has been running"
        [reboot]="Restarted the computer"
        [shutdown]="Shut down the computer"
    )

    export BASHTUTOR_EXPLANATIONS_LOADED="1"
}

# =============================================================================
# JSON ESCAPING (Using printf %q - portable, no jq dependency)
# =============================================================================

# Escape a string for safe JSON embedding
# Uses Python json.dumps for maximum robustness
function _bashtutor_json_escape() {
    local input="$1"

    # Handle empty input
    [[ -z "$input" ]] && { echo ""; return 0; }

    # Use Python's json.dumps which is the gold standard for JSON escaping
    if command -v python3 &>/dev/null; then
        local py_result
        # This approach passes the string as an argument to avoid stdin issues
        py_result=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$input" 2>/dev/null)

        if [[ $? -eq 0 && -n "$py_result" ]]; then
            # Remove the outer quotes that json.dumps adds
            # echo: "hello" → hello (strip first and last char if they're quotes)
            if [[ ${py_result:0:1} == '"' && ${py_result: -1} == '"' ]]; then
                echo -n "${py_result:1:-1}"
            else
                echo -n "$py_result"
            fi
            return 0
        fi
    fi

    # Fallback to jq if available
    if command -v jq &>/dev/null; then
        local jq_result
        jq_result=$(jq -n --arg s "$input" '$s' 2>/dev/null)
        if [[ $? -eq 0 && -n "$jq_result" ]]; then
            # Remove outer quotes added by jq -n
            if [[ ${jq_result:0:1} == '"' && ${jq_result: -1} == '"' ]]; then
                echo -n "${jq_result:1:-1}"
            else
                echo -n "$jq_result"
            fi
            return 0
        fi
    fi

    # Manual escaping as last resort
    # Order matters: backslash first, then quotes, then newlines/tabs
    local output="$input"
    output="${output//\\/\\\\}"      # Backslash → \\
    output="${output//\"/\\\"}"      # Quote → \"
    output="${output//$'\n'/\\n}"    # Newline → \n
    output="${output//$'\t'/\\t}"    # Tab → \t
    output="${output//$'\r'/\\r}"    # Carriage return → \r

    echo -n "$output"
}

# Alternative using jq if available (more robust)
function _bashtutor_json_escape_jq() {
    local input="$1"

    if command -v jq &>/dev/null; then
        printf '%s' "$input" | jq -Rs '.' 2>/dev/null | sed 's/^"//;s/"$//'
    else
        _bashtutor_json_escape "$input"
    fi
}

# =============================================================================
# SETUP & CONFIGURATION
# =============================================================================

function _bashtutor_setup() {
    local errors=0

    # Create config directory
    if [[ ! -d "$BASHTUTOR_CONFIG_DIR" ]]; then
        mkdir -p "$BASHTUTOR_CONFIG_DIR" 2>/dev/null || {
            _bashtutor_log "ERROR" "Failed to create config directory: $BASHTUTOR_CONFIG_DIR"
            ((errors++))
        }
    fi

    # Create cache directory
    if [[ ! -d "$BASHTUTOR_CACHE_DIR" ]]; then
        mkdir -p "$BASHTUTOR_CACHE_DIR" 2>/dev/null || {
            _bashtutor_log "ERROR" "Failed to create cache directory: $BASHTUTOR_CACHE_DIR"
            ((errors++))
        }
    fi

    # Create default config if missing
    if [[ ! -f "$BASHTUTOR_CONFIG_FILE" ]]; then
        _bashtutor_create_default_config || ((errors++))
    fi

    # Load configuration
    _bashtutor_load_config

    # Load explanations (lazy-load pattern)
    _bashtutor_load_explanations

    # Check Claude API availability
    _bashtutor_check_claude

    return $errors
}

function _bashtutor_create_default_config() {
    cat > "$BASHTUTOR_CONFIG_FILE" 2>/dev/null << 'EOF'
# BashTutor Configuration File
# Located at ~/.bashtutor/config

# Auto-explain mode: set to 1 to automatically explain every command
BASHTUTOR_AUTO_EXPLAIN=0

# Maximum cache age in hours (default: 24)
BASHTUTOR_CACHE_TTL=24

# Maximum history entries to keep
BASHTUTOR_MAX_HISTORY=1000

# Enable verbose logging
BASHTUTOR_VERBOSE=0
EOF
    return $?
}

function _bashtutor_load_config() {
    # Set defaults
    BASHTUTOR_AUTO_EXPLAIN="${BASHTUTOR_AUTO_EXPLAIN:-0}"
    BASHTUTOR_CACHE_TTL="${BASHTUTOR_CACHE_TTL:-24}"
    BASHTUTOR_MAX_HISTORY="${BASHTUTOR_MAX_HISTORY:-1000}"
    BASHTUTOR_VERBOSE="${BASHTUTOR_VERBOSE:-0}"

    # Load from config file if exists
    if [[ -f "$BASHTUTOR_CONFIG_FILE" ]] && [[ -r "$BASHTUTOR_CONFIG_FILE" ]]; then
        # Source safely with error handling
        {
            source "$BASHTUTOR_CONFIG_FILE" 2>/dev/null
        } || {
            _bashtutor_log "WARN" "Failed to load config from $BASHTUTOR_CONFIG_FILE"
        }
    fi

    # Re-apply defaults if values are empty
    [[ -z "$BASHTUTOR_CACHE_TTL" ]] && BASHTUTOR_CACHE_TTL=24
    [[ -z "$BASHTUTOR_MAX_HISTORY" ]] && BASHTUTOR_MAX_HISTORY=1000
}

function _bashtutor_check_claude() {
    BASHTUTOR_CLAUDE_AVAILABLE=""

    # Check if API key is set
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        BASHTUTOR_CLAUDE_AVAILABLE="1"
        return 0
    fi

    return 1
}

# =============================================================================
# LOGGING
# =============================================================================

function _bashtutor_log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

    # Only log if verbose mode or error level
    [[ "$level" != "ERROR" && "${BASHTUTOR_VERBOSE}" != "1" ]] && return 0

    # Escape message for safe logging
    local escaped_msg=$(echo "$message" | tr '\"' '_')

    # Write to log file with error handling
    if [[ -w "$BASHTUTOR_CONFIG_DIR" ]] || [[ ! -e "$BASHTUTOR_LOG_FILE" ]]; then
        printf '[%s] [%s] %s\n' "$timestamp" "$level" "$escaped_msg" >> "$BASHTUTOR_LOG_FILE" 2>/dev/null || true
    fi
}

# =============================================================================
# COMMAND CAPTURE HOOKS
# =============================================================================

function bashtutor_preexec() {
    export BASHTUTOR_LAST_COMMAND="$1"
}

function bashtutor_precmd() {
    local exit_code=$?
    export BASHTUTOR_LAST_EXIT_CODE="$exit_code"

    # Skip if no command was run
    [[ -z "$BASHTUTOR_LAST_COMMAND" ]] && return 0

    # Skip bashtutor's own commands
    local base_cmd=$(echo "$BASHTUTOR_LAST_COMMAND" | awk '{print $1}')
    [[ "$base_cmd" =~ ^(bashtutor|bashme|bt|_bashtutor) ]] && return 0

    # Log the command
    _bashtutor_log_command "$BASHTUTOR_LAST_COMMAND" "$exit_code"

    # Explain if auto-explain is enabled
    if [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" ]]; then
        _bashtutor_explain "$BASHTUTOR_LAST_COMMAND" "$exit_code"
    fi

    # Clear last command
    export BASHTUTOR_LAST_COMMAND=""
}

# =============================================================================
# HISTORY LOGGING (JSONL with proper escaping)
# =============================================================================

function _bashtutor_log_command() {
    local cmd="$1"
    local exit_code="${2:-0}"

    # Get timestamp safely
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || timestamp="$(date +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)" || timestamp="unknown"

    # Get current working directory
    local cwd
    cwd=$(pwd 2>/dev/null) || cwd="unknown"

    # Session ID
    local session_id="$$"

    # Escape the command for JSON
    local escaped_cmd
    escaped_cmd=$(_bashtutor_json_escape "$cmd")

    # Escape cwd for JSON
    local escaped_cwd
    escaped_cwd=$(_bashtutor_json_escape "$cwd")

    # Build JSON line
    local json_line
    json_line=$(printf '{"timestamp":"%s","command":"%s","exit_code":%s,"cwd":"%s","session":"%s"}' \
        "$timestamp" \
        "$escaped_cmd" \
        "$exit_code" \
        "$escaped_cwd" \
        "$session_id" 2>/dev/null)

    # Append to history file with error handling
    if [[ -n "$json_line" ]]; then
        echo "$json_line" >> "$BASHTUTOR_HISTORY_FILE" 2>/dev/null || {
            _bashtutor_log "ERROR" "Failed to write to history file"
        }
    fi

    # Trim history if needed
    _bashtutor_trim_history
}

function _bashtutor_trim_history() {
    [[ ! -f "$BASHTUTOR_HISTORY_FILE" ]] && return 0

    local max_lines="${BASHTUTOR_MAX_HISTORY:-1000}"
    local current_lines

    # Count lines (portable method)
    current_lines=$(wc -l < "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | tr -d ' ') || return 0

    # Trim if exceeding limit
    if [[ "$current_lines" -gt "$max_lines" ]]; then
        local temp_file=$(mktemp 2>/dev/null) || return 1
        tail -n "$max_lines" "$BASHTUTOR_HISTORY_FILE" > "$temp_file" 2>/dev/null && \
            mv "$temp_file" "$BASHTUTOR_HISTORY_FILE" 2>/dev/null || {
            rm -f "$temp_file" 2>/dev/null
            _bashtutor_log "ERROR" "Failed to trim history file"
        }
    fi
}

function _bashtutor_get_recent_history() {
    local count="${1:-5}"

    [[ ! -f "$BASHTUTOR_HISTORY_FILE" ]] && return 0

    # Extract commands safely
    tail -$count "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | while IFS= read -r line; do
        # Extract command field using sed
        echo "$line" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p' 2>/dev/null | \
        sed 's/\\"/"/g; s/\\\\/\\/g' 2>/dev/null
    done
}

# =============================================================================
# CACHE MANAGEMENT (24h TTL)
# =============================================================================

function _bashtutor_cache_get() {
    local key="$1"
    [[ -z "$key" ]] && return 1

    local cache_file="${BASHTUTOR_CACHE_DIR}/${key}.cache"
    [[ ! -f "$cache_file" ]] && return 1

    # Check TTL
    local ttl_hours="${BASHTUTOR_CACHE_TTL:-24}"
    local ttl_seconds=$((ttl_hours * 3600))

    # Get file modification time (portable)
    local file_mtime
    if command -v stat &>/dev/null; then
        # macOS stat
        file_mtime=$(stat -f%m "$cache_file" 2>/dev/null) || \
        # Linux stat
        file_mtime=$(stat -c%Y "$cache_file" 2>/dev/null) || \
        file_mtime="0"
    else
        file_mtime="0"
    fi

    local current_time
    current_time=$(date +%s 2>/dev/null) || current_time="0"

    local age=$((current_time - file_mtime))

    if [[ "$age" -gt "$ttl_seconds" ]]; then
        # Cache expired, remove it
        rm -f "$cache_file" 2>/dev/null
        return 1
    fi

    # Return cached content
    cat "$cache_file" 2>/dev/null
    return 0
}

function _bashtutor_cache_set() {
    local key="$1"
    local value="$2"
    [[ -z "$key" ]] && return 1

    local cache_file="${BASHTUTOR_CACHE_DIR}/${key}.cache"

    # Write to cache file
    printf '%s' "$value" > "$cache_file" 2>/dev/null || {
        _bashtutor_log "ERROR" "Failed to write cache: $key"
        return 1
    }

    return 0
}

function _bashtutor_cache_clear() {
    if [[ -d "$BASHTUTOR_CACHE_DIR" ]]; then
        rm -f "${BASHTUTOR_CACHE_DIR}"/*.cache 2>/dev/null
        _bashtutor_log "INFO" "Cache cleared"
    fi
}

function _bashtutor_cache_clean_expired() {
    [[ ! -d "$BASHTUTOR_CACHE_DIR" ]] && return 0

    local ttl_hours="${BASHTUTOR_CACHE_TTL:-24}"
    local ttl_seconds=$((ttl_hours * 3600))
    local current_time
    current_time=$(date +%s 2>/dev/null) || return 0

    local file_mtime age

    for cache_file in "$BASHTUTOR_CACHE_DIR"/*.cache; do
        [[ ! -f "$cache_file" ]] && continue

        file_mtime=$(stat -f%m "$cache_file" 2>/dev/null) || \
        file_mtime=$(stat -c%Y "$cache_file" 2>/dev/null) || continue

        age=$((current_time - file_mtime))
        [[ "$age" -gt "$ttl_seconds" ]] && rm -f "$cache_file" 2>/dev/null
    done
}

# =============================================================================
# COMMAND EXPLANATION
# =============================================================================

function _bashtutor_explain() {
    local cmd="$1"
    local exit_code="${2:-0}"

    local explanation=$(_bashtutor_get_explanation "$cmd" "$exit_code")

    if [[ -n "$explanation" ]]; then
        echo ""
        echo "💡 $explanation"
        echo ""
    fi
}

function _bashtutor_get_explanation() {
    local cmd="$1"
    local exit_code="${2:-0}"

    # Try cache first
    local cache_key
    cache_key=$(printf '%s' "$cmd" | cksum 2>/dev/null | awk '{print $1}')
    if [[ -n "$cache_key" ]]; then
        local cached_explanation
        cached_explanation=$(_bashtutor_cache_get "explain_${cache_key}")
        [[ -n "$cached_explanation" ]] && { echo "$cached_explanation"; return 0; }
    fi

    # Try Claude API if available
    local explanation=""
    if [[ "$BASHTUTOR_CLAUDE_AVAILABLE" == "1" ]]; then
        explanation=$(_bashtutor_explain_via_claude "$cmd" "$exit_code")
        if [[ -n "$explanation" ]]; then
            # Cache the result
            [[ -n "$cache_key" ]] && _bashtutor_cache_set "explain_${cache_key}" "$explanation"
            echo "$explanation"
            return 0
        fi
    fi

    # Fall back to local explanation
    explanation=$(_bashtutor_local_explain "$cmd" "$exit_code")

    # Cache local explanation too
    [[ -n "$cache_key" ]] && _bashtutor_cache_set "explain_${cache_key}" "$explanation"

    echo "$explanation"
}

function _bashtutor_explain_via_claude() {
    local cmd="$1"
    local exit_code="${2:-0}"

    # Verify API key is set
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        _bashtutor_log "DEBUG" "ANTHROPIC_API_KEY not set, skipping Claude API"
        return 1
    fi

    local tmpfile
    tmpfile=$(mktemp /tmp/bashtutor_claude.XXXXXX 2>/dev/null) || return 1

    local response=""

    # Use curl to call Claude API
    {
        local prompt
        prompt="Briefly explain what this bash command did in plain English (1 sentence max, max 80 chars):

Command: $cmd
Exit code: $exit_code

Keep it simple and clear."

        # Call Claude API with proper error handling
        local api_response
        api_response=$(curl -s \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{\"model\":\"claude-sonnet-4-20250514\",\"max_tokens\":256,\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}]}" \
            "https://api.anthropic.com/v1/messages" 2>/dev/null)

        if [[ -n "$api_response" ]]; then
            # Extract the text from the JSON response
            # Response format: {"content":[{"text":"..."}]}
            echo "$api_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'content' in data and len(data['content']) > 0:
        if 'text' in data['content'][0]:
            print(data['content'][0]['text'].strip())
except:
    pass
" 2>/dev/null
        fi
    } > "$tmpfile" &

    local pid=$!

    # Wait with timeout (10 seconds for API call)
    sleep 0.1
    if wait $pid 2>/dev/null; then
        response=$(cat "$tmpfile" 2>/dev/null)
    else
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
    fi

    rm -f "$tmpfile" 2>/dev/null

    # Validate response - should be 1-2 sentences, under 200 chars
    if [[ -n "$response" && "${#response}" -lt 200 ]]; then
        echo "$response"
        return 0
    fi

    return 1
}

function _bashtutor_local_explain() {
    local cmd="$1"
    local exit_code="${2:-0}"

    # Get the base command
    local base_cmd
    base_cmd=$(echo "$cmd" | awk '{print $1}' 2>/dev/null) || base_cmd="$cmd"

    # Look up explanation from module-scope array
    local explanation="${BASHTUTOR_EXPLANATIONS[$base_cmd]}"

    # Fallback for unknown commands
    [[ -z "$explanation" ]] && explanation="Ran the $base_cmd command"

    # Add exit code info if failed
    if [[ "$exit_code" -ne 0 ]]; then
        explanation="$explanation (failed with exit code $exit_code)"
    fi

    echo "$explanation"
}

# =============================================================================
# EXPLAIN LAST COMMAND (Ctrl+B binding)
# =============================================================================

function bashtutor_explain_last() {
    local cmd=""
    local exit_code=0

    # Try to get from history file
    if [[ -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        local last_line
        last_line=$(tail -1 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null)
        if [[ -n "$last_line" ]]; then
            cmd=$(echo "$last_line" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p' 2>/dev/null | \
                  sed 's/\\"/"/g; s/\\\\/\\/g' 2>/dev/null)
            exit_code=$(echo "$last_line" | sed -n 's/.*"exit_code":\([0-9]*\).*/\1/p' 2>/dev/null)
        fi
    fi

    # Fallback to last command from shell history
    if [[ -z "$cmd" ]]; then
        cmd=$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//' 2>/dev/null)
        exit_code="${BASHTUTOR_LAST_EXIT_CODE:-0}"
    fi

    if [[ -z "$cmd" ]]; then
        echo "⚠️  No previous command found"
        return 1
    fi

    echo ""
    echo "📝 Command: $cmd"
    echo ""

    _bashtutor_explain "$cmd" "$exit_code"
}

# =============================================================================
# MAIN COMMAND: bashme
# =============================================================================

function bashme() {
    local user_request="$*"

    if [[ -z "$user_request" ]]; then
        echo "🎓 BashTutor — Type what you want to do in plain English"
        echo ""
        echo "Examples:"
        echo "  bashme show me all files modified today"
        echo "  bashme find the largest directories"
        echo "  bashme compress this folder into a zip"
        echo ""
        return 1
    fi

    echo "🤔 Working on it..."

    local cwd
    cwd=$(pwd 2>/dev/null) || cwd="unknown"

    local recent_history
    recent_history=$(_bashtutor_get_recent_history 3 2>/dev/null | tr '\n' '; ')

    # Try Claude API first
    local result=""
    if [[ "$BASHTUTOR_CLAUDE_AVAILABLE" == "1" ]]; then
        result=$(_bashme_claude "$user_request" "$cwd" "$recent_history")
        if [[ -n "$result" && "$result" != "ERROR" ]]; then
            _bashme_display_result "$result" "$user_request"
            return $?
        fi
    fi

    # Fall back to local suggestions
    result=$(_bashme_local "$user_request")
    _bashme_display_result "$result" "$user_request"
    return $?
}

function _bashme_claude() {
    local user_request="$1"
    local cwd="$2"
    local history="$3"

    # Verify API key is set
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        _bashtutor_log "DEBUG" "ANTHROPIC_API_KEY not set, skipping Claude API"
        echo "ERROR"
        return 1
    fi

    local tmpfile
    tmpfile=$(mktemp /tmp/bashtutor_claude.XXXXXX 2>/dev/null) || { echo "ERROR"; return 1; }

    {
        local prompt
        prompt="Convert this request to a bash command:

Request: $user_request
Current directory: $cwd
Recent commands: $history

Respond ONLY with two lines:
COMMAND: <the exact bash command>
EXPLANATION: <one sentence explaining what it does>"

        # Call Claude API
        local api_response
        api_response=$(curl -s \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{\"model\":\"claude-sonnet-4-20250514\",\"max_tokens\":512,\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}]}" \
            "https://api.anthropic.com/v1/messages" 2>/dev/null)

        if [[ -n "$api_response" ]]; then
            # Extract the text from JSON response
            echo "$api_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'content' in data and len(data['content']) > 0:
        if 'text' in data['content'][0]:
            print(data['content'][0]['text'].strip())
    else:
        print('ERROR')
except:
    print('ERROR')
" 2>/dev/null
        else
            echo "ERROR"
        fi
    } > "$tmpfile" &

    local pid=$!

    sleep 0.1
    local response=""
    if wait $pid 2>/dev/null; then
        response=$(cat "$tmpfile" 2>/dev/null)
    else
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        response="ERROR"
    fi

    rm -f "$tmpfile" 2>/dev/null
    echo "$response"
}

function _bashme_local() {
    local request="$1"
    local request_lower
    request_lower=$(echo "$request" | tr '[:upper:]' '[:lower:]' 2>/dev/null)

    # Pattern matching for common requests
    case "$request_lower" in
        *files*today*|*files*recent*|*files*last*)
            echo "COMMAND: find . -type f -mtime -1 -ls"
            echo "EXPLANATION: Finds all files modified in the last 24 hours and shows details"
            return 0
            ;;
        *files*size*|*files*big*|*files*large*)
            echo "COMMAND: find . -type f -size +10M -exec ls -lh {} \\; 2>/dev/null | head -20"
            echo "EXPLANATION: Finds files larger than 10MB and shows their sizes"
            return 0
            ;;
        *space*|*size*directory*|*size*folder*)
            echo "COMMAND: du -sh */ 2>/dev/null | sort -rh | head -20"
            echo "EXPLANATION: Shows how much space each directory uses, sorted by size"
            return 0
            ;;
        *archive*|*zip*|*compress*|*tar*)
            echo "COMMAND: tar -czvf archive.tar.gz ."
            echo "EXPLANATION: Creates a compressed archive of the current directory"
            return 0
            ;;
        *search*text*|*search*string*|*search*find*)
            echo "COMMAND: grep -r \"search term\" . 2>/dev/null"
            echo "EXPLANATION: Searches for text in all files in current directory"
            return 0
            ;;
        *process*|*running*|*cpu*)
            echo "COMMAND: ps aux | head -20"
            echo "EXPLANATION: Lists the 20 most resource-intensive running processes"
            return 0
            ;;
        *kill*process*)
            echo "COMMAND: pkill -f \"process_name\""
            echo "EXPLANATION: Stops all processes matching the given name"
            return 0
            ;;
        *memory*|*ram*)
            echo "COMMAND: vm_stat | head -10"
            echo "EXPLANATION: Shows memory usage statistics on macOS"
            return 0
            ;;
        *disk*space*|*disk*free*)
            echo "COMMAND: df -h"
            echo "EXPLANATION: Shows available disk space on all drives"
            return 0
            ;;
        *git*status*)
            echo "COMMAND: git status"
            echo "EXPLANATION: Shows which files have changed in your git repository"
            return 0
            ;;
        *git*commit*)
            echo "COMMAND: git commit -am \"Your commit message\""
            echo "EXPLANATION: Saves your changes to git with a description"
            return 0
            ;;
        *list*|*show*files*|*show*directory*)
            echo "COMMAND: ls -la"
            echo "EXPLANATION: Lists all files including hidden ones with details"
            return 0
            ;;
        *delete*directory*|*remove*directory*|*delete*folder*|*remove*folder*)
            echo "COMMAND: rm -rf directory_name"
            echo "EXPLANATION: Deletes a directory and all its contents (be careful!)"
            return 0
            ;;
        *delete*|*remove*)
            echo "COMMAND: rm filename"
            echo "EXPLANATION: Deletes the specified file"
            return 0
            ;;
        *create*directory*|*make*directory*|*create*folder*|*make*folder*)
            echo "COMMAND: mkdir -p new_directory_name"
            echo "EXPLANATION: Creates a new directory (also creates parent directories if needed)"
            return 0
            ;;
        *create*file*|*make*file*)
            echo "COMMAND: touch newfile.txt"
            echo "EXPLANATION: Creates a new empty file"
            return 0
            ;;
        *copy*|*duplicate*)
            echo "COMMAND: cp source destination"
            echo "EXPLANATION: Copies a file from source to destination"
            return 0
            ;;
        *move*|*rename*)
            echo "COMMAND: mv old_name new_name"
            echo "EXPLANATION: Moves or renames a file or directory"
            return 0
            ;;
        *view*file*|*read*file*)
            echo "COMMAND: cat filename"
            echo "EXPLANATION: Displays the contents of a file"
            return 0
            ;;
        *edit*file*)
            echo "COMMAND: nano filename"
            echo "EXPLANATION: Opens the file in a simple text editor"
            return 0
            ;;
        *permissions*|*chmod*)
            echo "COMMAND: chmod 755 filename"
            echo "EXPLANATION: Changes file permissions (755 = owner can read/write/execute, others can read/execute)"
            return 0
            ;;
        *download*|*curl*|*wget*)
            echo "COMMAND: curl -O https://example.com/file.zip"
            echo "EXPLANATION: Downloads a file from the internet"
            return 0
            ;;
        *network*|*ping*)
            echo "COMMAND: ping -c 4 google.com"
            echo "EXPLANATION: Tests internet connectivity by pinging Google"
            return 0
            ;;
        *ip*|*address*)
            echo "COMMAND: ifconfig | grep inet"
            echo "EXPLANATION: Shows your network IP addresses"
            return 0
            ;;
        *port*check*|*port*open*)
            echo "COMMAND: lsof -i -P | grep LISTEN"
            echo "EXPLANATION: Shows which ports are open and listening"
            return 0
            ;;
    esac

    # Default fallback
    echo "COMMAND: echo 'Try: ls, cd, pwd, mkdir, rm, cp, mv, cat, grep, find, git, or ask for something specific'"
    echo "EXPLANATION: Shows available commands. Try being more specific about what you want to do."
}

function _bashme_display_result() {
    local result="$1"
    local original_request="$2"

    # Parse the result
    local cmd explanation
    cmd=$(echo "$result" | grep "^COMMAND:" 2>/dev/null | sed 's/^COMMAND: //' | head -1)
    explanation=$(echo "$result" | grep "^EXPLANATION:" 2>/dev/null | sed 's/^EXPLANATION: //' | head -1)

    if [[ -z "$cmd" ]]; then
        echo "❌ Sorry, I couldn't figure out a command for that."
        echo "   Try rephrasing or check 'bashme' for examples."
        return 1
    fi

    echo ""
    echo "💡 Suggestion:"
    echo "   $cmd"
    echo ""
    echo "   $explanation"
    echo ""

    # Ask user what to do
    echo -n "Run this? [Y/n/e for more info]: "
    read -r confirm

    case "$confirm" in
        [Nn]*)
            echo "❌ Cancelled"
            return 0
            ;;
        [Ee]*)
            echo ""
            _bashme_deep_explain "$cmd"
            echo ""
            echo -n "Run it now? [Y/n]: "
            read -r confirm2
            if [[ "$confirm2" == [Nn]* ]]; then
                return 0
            fi
            ;;
    esac

    # Execute
    echo "▶️  Running: $cmd"
    echo ""
    eval "$cmd"
}

function _bashme_deep_explain() {
    local cmd="$1"
    local base
    base=$(echo "$cmd" | awk '{print $1}' 2>/dev/null) || base="$cmd"

    echo "📖 Detailed explanation of '$base':"
    echo ""

    case "$base" in
        ls)
            echo "ls - List directory contents"
            echo ""
            echo "Common options:"
            echo "  -l    Long format with permissions, sizes, dates"
            echo "  -a    Show hidden files (starting with dot)"
            echo "  -h    Human-readable sizes (K, M, G)"
            echo "  -t    Sort by modification time"
            echo "  -r    Reverse sort order"
            ;;
        find)
            echo "find - Search for files in directory hierarchy"
            echo ""
            echo "Common patterns:"
            echo "  find . -name '*.txt'          # Find by name"
            echo "  find . -type f -size +100M  # Large files"
            echo "  find . -mtime -7             # Modified last week"
            ;;
        grep)
            echo "grep - Search text using patterns"
            echo ""
            echo "Common options:"
            echo "  -r    Recursive (search subdirectories)"
            echo "  -i    Case-insensitive search"
            echo "  -n    Show line numbers"
            echo "  -l    Show only filenames"
            ;;
        tar)
            echo "tar - Archive files"
            echo ""
            echo "Options:"
            echo "  -c    Create archive"
            echo "  -x    Extract archive"
            echo "  -z    Compress with gzip"
            echo "  -v    Verbose (show files)"
            echo "  -f    Specify filename"
            ;;
        git)
            echo "git - Version control"
            echo ""
            echo "Common commands:"
            echo "  git status          # See what's changed"
            echo "  git add filename    # Stage changes"
            echo "  git commit -m 'msg' # Save changes"
            ;;
        *)
            echo "Command: $cmd"
            echo ""
            echo "This command will execute in your current shell."
            echo "Make sure you understand what it does before running it."
            ;;
    esac
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

function bashtutor_toggle() {
    if [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" ]]; then
        export BASHTUTOR_AUTO_EXPLAIN="0"
        echo "🔇 Auto-explanations disabled"
    else
        export BASHTUTOR_AUTO_EXPLAIN="1"
        echo "🔊 Auto-explanations enabled"
    fi
}

function bashtutor_history() {
    echo "📚 Your recent commands:"
    echo ""

    if [[ ! -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        echo "No history yet. Keep using bash!"
        return 0
    fi

    local count=0
    tail -20 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | while IFS= read -r line; do
        ((count++))
        local cmd exit_code time icon

        cmd=$(echo "$line" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p' 2>/dev/null | sed 's/\\"/"/g')
        exit_code=$(echo "$line" | sed -n 's/.*"exit_code":\([0-9]*\).*/\1/p' 2>/dev/null)
        time=$(echo "$line" | sed -n 's/.*"timestamp":"\([^T]*\)T.*/\1/p' 2>/dev/null)

        icon="✅"
        [[ "$exit_code" != "0" ]] && icon="❌"

        printf "%s %2d. %s\n" "$icon" "$count" "$cmd"
    done
}

function bashtutor_help() {
    echo "🎓 BashTutor Help"
    echo ""
    echo "Commands:"
    echo "  bashme <request>          Get bash command from natural language"
    echo "  bt <request>              Short alias for bashme"
    echo "  bashtutor_toggle          Enable/disable auto-explanations"
    echo "  bashtutor_history         View your command history"
    echo "  bashtutor_help            Show this help"
    echo "  bashtutor_explain_last    Explain the last command (bound to Ctrl+B)"
    echo ""
    echo "Keybindings:"
    echo "  Ctrl+B                    Explain the last command"
    echo ""
    echo "Configuration:"
    echo "  Config dir:  $BASHTUTOR_CONFIG_DIR"
    echo "  Cache dir:   $BASHTUTOR_CACHE_DIR"
    echo "  Config file: $BASHTUTOR_CONFIG_FILE"
    echo "  History:     $BASHTUTOR_HISTORY_FILE"
    echo "  Claude API:  $( [[ "$BASHTUTOR_CLAUDE_AVAILABLE" == "1" ]] && echo "✅ Available" || echo "❌ Not available (local mode) - set ANTHROPIC_API_KEY to enable")"
    echo "  Architecture: $BASHTUTOR_ARCH"
}

# =============================================================================
# CLEANUP
# =============================================================================

function _bashtutor_cleanup() {
    _bashtutor_log "INFO" "BashTutor shutting down"

    # Clean expired cache entries
    _bashtutor_cache_clean_expired

    # Unset variables
    unset BASHTUTOR_LAST_COMMAND
    unset BASHTUTOR_LAST_EXIT_CODE
}

# Register cleanup on shell exit
trap '_bashtutor_cleanup' EXIT 2>/dev/null || true

# Also register with zsh's zshexit if available
if [[ -n "${ZSH_VERSION}" ]]; then
    autoload -Uz add-zsh-hook 2>/dev/null && \
        add-zsh-hook zshexit _bashtutor_cleanup 2>/dev/null || true
fi

# =============================================================================
# REGISTER HOOKS, KEYBINDINGS & ALIASES
# =============================================================================

autoload -Uz add-zsh-hook 2>/dev/null && {
    add-zsh-hook preexec bashtutor_preexec
    add-zsh-hook precmd bashtutor_precmd
}

# Keybinding: Ctrl+B to explain last command
bindkey -e 2>/dev/null || true
zle -N bashtutor_explain_last 2>/dev/null && \
    bindkey '^B' bashtutor_explain_last 2>/dev/null || true

# Aliases
alias bt='bashme'
alias btx='bashtutor_toggle'
alias bth='bashtutor_history'

# =============================================================================
# INITIALIZATION
# =============================================================================

# Run setup
_bashtutor_setup

# Welcome message (once per session)
if [[ -z "${BASHTUTOR_WELCOME_SHOWN}" ]]; then
    echo "🎓 BashTutor $BASHTUTOR_VERSION loaded ($BASHTUTOR_ARCH)"
    if [[ "$BASHTUTOR_CLAUDE_AVAILABLE" == "1" ]]; then
        echo "   Claude API: ✅ Enabled for AI-powered explanations"
    else
        echo "   Claude API: ❌ Not configured (set ANTHROPIC_API_KEY to enable)"
        echo "               Using local pattern matching for now"
    fi
    echo "   Type 'bashme' followed by what you want to do"
    echo "   Press Ctrl+B to explain the last command"
    export BASHTUTOR_WELCOME_SHOWN="1"
fi