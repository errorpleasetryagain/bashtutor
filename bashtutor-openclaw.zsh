#!/usr/bin/env zsh
# ╔══════════════════════════════════════════════════════════════╗
# ║  BashTutor — OpenClaw Edition  🦀                           ║
# ║  Version: 1.1.0                                             ║
# ║  AI backend: openclaw infer model run                       ║
# ║  Teach bash through doing, not memorising                   ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Installation: source this file in your ~/.zshrc
# Usage:
#   bashme show files modified today    → get a bash command
#   bt show files modified today        → same, shorter
#   Ctrl+B                              → explain last command
#   bashtutor_toggle                    → turn auto-explain on/off
#   bashtutor_history                   → see recent commands

# =============================================================================
# GUARD: prevent double-loading
# =============================================================================

[[ -n "${BASHTUTOR_LOADED}" ]] && return 0
export BASHTUTOR_LOADED="1"
export BASHTUTOR_VERSION="1.1.0"
export BASHTUTOR_BACKEND="openclaw"

# =============================================================================
# COLOURS & JOY
# =============================================================================

# Colours (only if terminal supports them)
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    _BT_RESET=$(tput sgr0)
    _BT_BOLD=$(tput bold)
    _BT_CYAN=$(tput setaf 6)
    _BT_GREEN=$(tput setaf 2)
    _BT_YELLOW=$(tput setaf 3)
    _BT_MAGENTA=$(tput setaf 5)
    _BT_RED=$(tput setaf 1)
    _BT_BLUE=$(tput setaf 4)
    _BT_WHITE=$(tput setaf 7)
else
    _BT_RESET="" _BT_BOLD="" _BT_CYAN="" _BT_GREEN=""
    _BT_YELLOW="" _BT_MAGENTA="" _BT_RED="" _BT_BLUE="" _BT_WHITE=""
fi

# Print helpers
_bt_info()    { echo "${_BT_CYAN}${_BT_BOLD}🐚 $*${_BT_RESET}"; }
_bt_success() { echo "${_BT_GREEN}${_BT_BOLD}✅ $*${_BT_RESET}"; }
_bt_warn()    { echo "${_BT_YELLOW}⚠️  $*${_BT_RESET}"; }
_bt_error()   { echo "${_BT_RED}❌ $*${_BT_RESET}" >&2; }
_bt_tip()     { echo "${_BT_MAGENTA}💡 $*${_BT_RESET}"; }
_bt_cmd()     { echo "${_BT_BLUE}${_BT_BOLD}$ $*${_BT_RESET}"; }
_bt_explain() { echo "${_BT_CYAN}📖 $*${_BT_RESET}"; }

# Fun loading spinners
_bt_thinking() {
    echo "${_BT_YELLOW}🤔 Thinking...${_BT_RESET}"
}

# =============================================================================
# PATHS & CONFIGURATION
# =============================================================================

export BASHTUTOR_CONFIG_DIR="${HOME}/.bashtutor"
export BASHTUTOR_CACHE_DIR="${BASHTUTOR_CONFIG_DIR}/cache"
export BASHTUTOR_CONFIG_FILE="${BASHTUTOR_CONFIG_DIR}/config"
export BASHTUTOR_HISTORY_FILE="${BASHTUTOR_CONFIG_DIR}/history.jsonl"
export BASHTUTOR_LOG_FILE="${BASHTUTOR_CONFIG_DIR}/bashtutor.log"

export BASHTUTOR_LAST_COMMAND=""
export BASHTUTOR_LAST_EXIT_CODE="0"
export BASHTUTOR_AI_AVAILABLE=""
export BASHTUTOR_EXPLANATIONS_LOADED=""
export BASHTUTOR_ARCH=$(uname -m 2>/dev/null || echo "unknown")

# =============================================================================
# LOCAL EXPLANATIONS (60+ commands, lazy-loaded once)
# =============================================================================

declare -gA BASHTUTOR_EXPLANATIONS

function _bashtutor_load_explanations() {
    [[ "${BASHTUTOR_EXPLANATIONS_LOADED}" == "1" ]] && return 0

    BASHTUTOR_EXPLANATIONS=(
        [ls]="Listed the files and folders here"
        [ll]="Listed files with full details — size, date, permissions"
        [la]="Listed everything including hidden files (ones starting with .)"
        [cd]="Moved into a different folder"
        [pwd]="Showed you where you are right now"
        [mkdir]="Created a new folder"
        [rm]="Deleted something — gone for good, no recycle bin"
        [rmdir]="Removed an empty folder"
        [cp]="Made a copy of a file or folder"
        [mv]="Moved or renamed a file"
        [touch]="Created an empty file, or updated its 'last modified' time"
        [cat]="Printed a file's contents to the screen"
        [less]="Opened a file to scroll through — press Q to quit"
        [head]="Showed just the top few lines of a file"
        [tail]="Showed just the bottom few lines of a file"
        [grep]="Searched for text inside files"
        [find]="Searched for files by name, size, or date"
        [locate]="Found files quickly using a pre-built index"
        [which]="Showed where a command lives on your system"
        [whereis]="Found the command, its manual page, and source"
        [du]="Showed how much disk space a folder is using"
        [df]="Showed how much space is left on your drives"
        [ps]="Listed all the programs currently running"
        [top]="Live view of what's using your CPU and memory"
        [htop]="Fancy live view of system resources — press Q to quit"
        [kill]="Stopped a running program by its ID number"
        [killall]="Stopped all programs with a given name"
        [ping]="Checked if a server is reachable"
        [curl]="Fetched data from a URL — great for APIs"
        [wget]="Downloaded a file from the internet"
        [ssh]="Opened a secure terminal connection to another machine"
        [scp]="Securely copied a file to or from another machine"
        [rsync]="Synced files between two places — only copies what changed"
        [tar]="Packed or unpacked an archive file (.tar, .tar.gz)"
        [zip]="Compressed files into a .zip archive"
        [unzip]="Unpacked a .zip archive"
        [gzip]="Compressed a single file"
        [gunzip]="Decompressed a .gz file"
        [chmod]="Changed who can read, write, or run a file"
        [chown]="Changed who owns a file"
        [sudo]="Ran a command with admin powers — use carefully"
        [su]="Switched to a different user account"
        [passwd]="Changed a user's password"
        [git]="Ran a git command — for tracking code changes"
        [brew]="Ran Homebrew — macOS package manager"
        [npm]="Ran Node.js package manager"
        [pip]="Ran Python package manager"
        [pip3]="Ran Python 3 package manager"
        [python]="Ran a Python program or script"
        [python3]="Ran a Python 3 program or script"
        [node]="Ran a Node.js program"
        [docker]="Ran a Docker container command"
        [kubectl]="Ran a Kubernetes command"
        [make]="Built software using instructions in a Makefile"
        [man]="Opened the manual page for a command"
        [clear]="Cleared the terminal screen"
        [exit]="Closed this terminal session"
        [history]="Showed your recent command history"
        [alias]="Created a shortcut for a longer command"
        [export]="Set an environment variable for this session"
        [source]="Loaded and ran a shell script in the current session"
        [echo]="Printed text to the screen"
        [date]="Showed the current date and time"
        [whoami]="Showed your current username"
        [uname]="Showed info about your operating system"
        [hostname]="Showed your computer's network name"
        [uptime]="Showed how long your computer has been on"
        [open]="Opened a file or folder in its default app (macOS)"
        [pbcopy]="Copied something to your clipboard (macOS)"
        [pbpaste]="Pasted from your clipboard (macOS)"
        [caffeinate]="Kept your Mac from sleeping"
        [say]="Made your Mac speak text out loud"
        [screencapture]="Took a screenshot (macOS)"
        [xargs]="Ran a command once for each item from a list"
        [awk]="Processed text — great for working with columns"
        [sed]="Edited text using find-and-replace rules"
        [sort]="Sorted lines alphabetically or numerically"
        [uniq]="Removed duplicate lines"
        [wc]="Counted words, lines, or characters in a file"
        [tr]="Translated or deleted characters"
        [cut]="Cut out specific columns from text"
        [paste]="Joined lines from multiple files side by side"
        [diff]="Compared two files and showed what's different"
        [patch]="Applied a diff patch to a file"
        [ln]="Created a link (shortcut) to a file"
        [readlink]="Showed where a link points to"
        [env]="Showed or set environment variables"
        [printenv]="Printed the value of an environment variable"
        [set]="Showed all shell variables"
        [unset]="Removed a variable from the environment"
        [jobs]="Showed background jobs running in this terminal"
        [bg]="Sent a paused job to run in the background"
        [fg]="Brought a background job back to the foreground"
        [nohup]="Ran a command that keeps going even after you log out"
        [sleep]="Paused for a number of seconds"
        [time]="Measured how long a command takes to run"
        [watch]="Ran a command repeatedly and showed the output"
        [cron]="Scheduled commands to run automatically"
        [crontab]="Edited your scheduled tasks list"
        [at]="Scheduled a one-off command to run later"
        [reboot]="Restarted the computer"
        [shutdown]="Turned the computer off"
        [ifconfig]="Showed network interface information (older Macs)"
        [ip]="Showed network information (Linux)"
        [netstat]="Showed network connections"
        [lsof]="Listed open files and the programs using them"
        [nmap]="Scanned a network for open ports"
        [traceroute]="Showed the path data takes to reach a server"
        [dig]="Looked up DNS information for a domain"
        [nslookup]="Queried a DNS server"
        [host]="Found the IP address for a domain name"
        [openssl]="Ran cryptography and certificate tools"
        [base64]="Encoded or decoded base64 data"
        [md5]="Calculated an MD5 checksum"
        [shasum]="Calculated a SHA checksum"
        [diskutil]="Managed disks and volumes (macOS)"
        [hdiutil]="Worked with disk images (macOS)"
        [defaults]="Read or wrote macOS app preferences"
        [launchctl]="Managed macOS background services"
        [pmset]="Managed power settings (macOS)"
        [softwareupdate]="Managed macOS software updates"
        [xcode-select]="Managed Xcode command line tools"
    )

    export BASHTUTOR_EXPLANATIONS_LOADED="1"
}

# =============================================================================
# JSON ESCAPING (3-layer fallback: Python → jq → manual)
# =============================================================================

function _bashtutor_json_escape() {
    local input="$1"
    [[ -z "$input" ]] && { echo ""; return 0; }

    # Layer 1: Python (most robust)
    if command -v python3 &>/dev/null; then
        local result
        result=$(python3 -c "import json,sys; s=json.dumps(sys.argv[1]); print(s[1:-1])" "$input" 2>/dev/null)
        [[ $? -eq 0 && -n "$result" ]] && { echo -n "$result"; return 0; }
    fi

    # Layer 2: jq
    if command -v jq &>/dev/null; then
        local result
        result=$(printf '%s' "$input" | jq -Rs '.[:-1]' 2>/dev/null | sed 's/^"//' 2>/dev/null)
        [[ $? -eq 0 && -n "$result" ]] && { echo -n "$result"; return 0; }
    fi

    # Layer 3: manual
    local output="$input"
    output="${output//\\/\\\\}"
    output="${output//\"/\\\"}"
    output="${output//$'\n'/\\n}"
    output="${output//$'\t'/\\t}"
    output="${output//$'\r'/\\r}"
    echo -n "$output"
}

# =============================================================================
# SETUP & CONFIG
# =============================================================================

function _bashtutor_setup() {
    mkdir -p "$BASHTUTOR_CONFIG_DIR" "$BASHTUTOR_CACHE_DIR" 2>/dev/null

    [[ ! -f "$BASHTUTOR_CONFIG_FILE" ]] && _bashtutor_create_default_config

    _bashtutor_load_config
    _bashtutor_load_explanations
    _bashtutor_check_ai
}

function _bashtutor_create_default_config() {
    cat > "$BASHTUTOR_CONFIG_FILE" 2>/dev/null << 'EOF'
# BashTutor Configuration
# Edit these to change how BashTutor behaves

# Auto-explain every command? (0 = off, 1 = on)
BASHTUTOR_AUTO_EXPLAIN=0

# How long to remember AI answers (hours)
BASHTUTOR_CACHE_TTL=24

# How many commands to keep in history
BASHTUTOR_MAX_HISTORY=1000

# Show extra debug info? (0 = off, 1 = on)
BASHTUTOR_VERBOSE=0
EOF
}

function _bashtutor_load_config() {
    BASHTUTOR_AUTO_EXPLAIN="${BASHTUTOR_AUTO_EXPLAIN:-0}"
    BASHTUTOR_CACHE_TTL="${BASHTUTOR_CACHE_TTL:-24}"
    BASHTUTOR_MAX_HISTORY="${BASHTUTOR_MAX_HISTORY:-1000}"
    BASHTUTOR_VERBOSE="${BASHTUTOR_VERBOSE:-0}"

    [[ -f "$BASHTUTOR_CONFIG_FILE" ]] && source "$BASHTUTOR_CONFIG_FILE" 2>/dev/null || true

    [[ -z "$BASHTUTOR_CACHE_TTL" ]] && BASHTUTOR_CACHE_TTL=24
    [[ -z "$BASHTUTOR_MAX_HISTORY" ]] && BASHTUTOR_MAX_HISTORY=1000
}

function _bashtutor_check_ai() {
    BASHTUTOR_AI_AVAILABLE=""
    if command -v openclaw &>/dev/null; then
        BASHTUTOR_AI_AVAILABLE="1"
    fi
}

# =============================================================================
# LOGGING
# =============================================================================

function _bashtutor_log() {
    local level="$1" message="$2"
    [[ "$level" != "ERROR" && "${BASHTUTOR_VERBOSE}" != "1" ]] && return 0
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    printf '[%s] [%s] %s\n' "$ts" "$level" "$message" >> "$BASHTUTOR_LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# HOOKS: capture every command
# =============================================================================

function bashtutor_preexec() {
    export BASHTUTOR_LAST_COMMAND="$1"
}

function bashtutor_precmd() {
    local exit_code=$?
    export BASHTUTOR_LAST_EXIT_CODE="$exit_code"

    [[ -z "$BASHTUTOR_LAST_COMMAND" ]] && return 0

    local base_cmd=$(echo "$BASHTUTOR_LAST_COMMAND" | awk '{print $1}')
    [[ "$base_cmd" =~ ^(bashtutor|bashme|bt|_bashtutor) ]] && return 0

    _bashtutor_log_command "$BASHTUTOR_LAST_COMMAND" "$exit_code"

    if [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" ]]; then
        _bashtutor_explain "$BASHTUTOR_LAST_COMMAND" "$exit_code"
    fi

    export BASHTUTOR_LAST_COMMAND=""
}

# =============================================================================
# HISTORY (JSONL format, safe escaping)
# =============================================================================

function _bashtutor_log_command() {
    local cmd="$1" exit_code="${2:-0}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
    local cwd=$(pwd 2>/dev/null || echo "unknown")
    local escaped_cmd=$(_bashtutor_json_escape "$cmd")
    local escaped_cwd=$(_bashtutor_json_escape "$cwd")

    printf '{"timestamp":"%s","command":"%s","exit_code":%s,"cwd":"%s","session":"%s"}\n' \
        "$timestamp" "$escaped_cmd" "$exit_code" "$escaped_cwd" "$$" \
        >> "$BASHTUTOR_HISTORY_FILE" 2>/dev/null || true

    _bashtutor_trim_history
}

function _bashtutor_trim_history() {
    [[ ! -f "$BASHTUTOR_HISTORY_FILE" ]] && return 0
    local max="${BASHTUTOR_MAX_HISTORY:-1000}"
    local lines=$(wc -l < "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | tr -d ' ')
    if [[ "$lines" -gt "$max" ]]; then
        local tmp=$(mktemp 2>/dev/null) || return 0
        tail -n "$max" "$BASHTUTOR_HISTORY_FILE" > "$tmp" && mv "$tmp" "$BASHTUTOR_HISTORY_FILE" 2>/dev/null || rm -f "$tmp"
    fi
}

function _bashtutor_get_recent_history() {
    local count="${1:-5}"
    [[ ! -f "$BASHTUTOR_HISTORY_FILE" ]] && return 0
    tail -$count "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | \
        sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | \
        sed 's/\\"/"/g; s/\\\\/\\/g'
}

# =============================================================================
# CACHE (24h TTL)
# =============================================================================

function _bashtutor_cache_key() {
    printf '%s' "$1" | cksum 2>/dev/null | awk '{print $1}'
}

function _bashtutor_cache_get() {
    local key="$1"
    local f="${BASHTUTOR_CACHE_DIR}/${key}.cache"
    [[ ! -f "$f" ]] && return 1

    local ttl_secs=$(( ${BASHTUTOR_CACHE_TTL:-24} * 3600 ))
    local mtime=$(stat -f%m "$f" 2>/dev/null || stat -c%Y "$f" 2>/dev/null || echo 0)
    local now=$(date +%s 2>/dev/null || echo 0)

    if [[ $(( now - mtime )) -gt $ttl_secs ]]; then
        rm -f "$f" 2>/dev/null
        return 1
    fi
    cat "$f" 2>/dev/null
}

function _bashtutor_cache_set() {
    local key="$1" value="$2"
    printf '%s' "$value" > "${BASHTUTOR_CACHE_DIR}/${key}.cache" 2>/dev/null || true
}

function _bashtutor_cache_clear() {
    rm -f "${BASHTUTOR_CACHE_DIR}"/*.cache 2>/dev/null
    _bt_success "Cache cleared"
}

# =============================================================================
# AI: OpenClaw inference
# =============================================================================

function _bashtutor_ask_openclaw() {
    local prompt="$1"
    local timeout_secs="${2:-15}"

    if [[ -z "$BASHTUTOR_AI_AVAILABLE" ]]; then
        return 1
    fi

    # Run with timeout
    local result
    result=$(timeout "$timeout_secs" openclaw infer model run --prompt "$prompt" 2>/dev/null)
    local rc=$?

    if [[ $rc -eq 0 && -n "$result" ]]; then
        echo "$result"
        return 0
    fi

    return 1
}

# =============================================================================
# EXPLANATION ENGINE
# =============================================================================

function _bashtutor_explain() {
    local cmd="$1" exit_code="${2:-0}"
    local explanation=$(_bashtutor_get_explanation "$cmd" "$exit_code")

    if [[ -n "$explanation" ]]; then
        echo ""
        _bt_explain "$explanation"
        echo ""
    fi
}

function _bashtutor_get_explanation() {
    local cmd="$1" exit_code="${2:-0}"

    # Check cache first
    local cache_key=$(_bashtutor_cache_key "explain_${cmd}")
    if [[ -n "$cache_key" ]]; then
        local cached=$(_bashtutor_cache_get "$cache_key")
        [[ -n "$cached" ]] && { echo "$cached"; return 0; }
    fi

    # Try OpenClaw
    local explanation=""
    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        local prompt="Explain this bash command in one plain sentence (max 80 characters). No jargon. Be friendly and clear.

Command: $cmd
Exit code: $exit_code (0 = success, anything else = failed)"

        explanation=$(_bashtutor_ask_openclaw "$prompt" 10)
    fi

    # Fall back to local
    [[ -z "$explanation" ]] && explanation=$(_bashtutor_local_explain "$cmd" "$exit_code")

    # Cache it
    [[ -n "$cache_key" && -n "$explanation" ]] && _bashtutor_cache_set "$cache_key" "$explanation"

    echo "$explanation"
}

function _bashtutor_local_explain() {
    local cmd="$1" exit_code="${2:-0}"
    local base_cmd=$(echo "$cmd" | awk '{print $1}' 2>/dev/null)
    local explanation="${BASHTUTOR_EXPLANATIONS[$base_cmd]}"

    [[ -z "$explanation" ]] && explanation="Ran the '${base_cmd}' command"

    if [[ "$exit_code" -ne 0 ]]; then
        explanation="${explanation} — but something went wrong (exit code ${exit_code})"
    fi

    echo "$explanation"
}

# =============================================================================
# EXPLAIN LAST COMMAND (Ctrl+B)
# =============================================================================

function bashtutor_explain_last() {
    local cmd="" exit_code=0

    if [[ -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        local last=$(tail -1 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null)
        if [[ -n "$last" ]]; then
            cmd=$(echo "$last" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | sed 's/\\"/"/g; s/\\\\/\\/g')
            exit_code=$(echo "$last" | sed -n 's/.*"exit_code":\([0-9]*\).*/\1/p')
        fi
    fi

    [[ -z "$cmd" ]] && cmd=$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')
    [[ -z "$cmd" ]] && { _bt_warn "No previous command found"; return 1; }

    echo ""
    echo "${_BT_BOLD}${_BT_WHITE}Last command:${_BT_RESET} ${_BT_BLUE}$cmd${_BT_RESET}"
    _bashtutor_explain "$cmd" "${exit_code:-0}"
}

# =============================================================================
# MAIN COMMAND: bashme
# =============================================================================

function bashme() {
    local request="$*"

    if [[ -z "$request" ]]; then
        echo ""
        _bt_info "BashTutor ${BASHTUTOR_VERSION} — OpenClaw Edition 🦀"
        echo ""
        echo "  ${_BT_BOLD}How to use:${_BT_RESET}"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} ${_BT_WHITE}<what you want to do in plain English>${_BT_RESET}"
        echo ""
        echo "  ${_BT_BOLD}Examples:${_BT_RESET}"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} show files modified today"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} find all pdf files in downloads"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} how much disk space am i using"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} copy everything from desktop to documents"
        echo ""
        echo "  ${_BT_BOLD}Shortcuts:${_BT_RESET}"
        echo "  ${_BT_MAGENTA}bt${_BT_RESET}              same as bashme"
        echo "  ${_BT_MAGENTA}Ctrl+B${_BT_RESET}          explain the last command"
        echo "  ${_BT_MAGENTA}btx${_BT_RESET}             toggle auto-explain on/off"
        echo "  ${_BT_MAGENTA}bth${_BT_RESET}             show recent command history"
        echo ""
        return 0
    fi

    # Build prompt with history context
    local history_context=""
    if [[ -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        local recent=$(_bashtutor_get_recent_history 3)
        [[ -n "$recent" ]] && history_context="
Recent commands for context:
$recent"
    fi

    local prompt="You are a helpful bash tutor. Give ONLY the bash command, nothing else — no explanation, no markdown, no code fences.

Task: $request
macOS: yes
Shell: zsh${history_context}

Reply with just the command."

    # Try OpenClaw
    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        echo ""
        _bt_thinking

        local result=$(_bashtutor_ask_openclaw "$prompt" 20)

        if [[ -n "$result" ]]; then
            # Strip markdown fences if OpenClaw wraps output
            result=$(echo "$result" | sed 's/^```[a-z]*//; s/^```//' | sed '/^$/d' | head -5)

            echo ""
            echo "${_BT_BOLD}${_BT_WHITE}Here's the command:${_BT_RESET}"
            echo ""
            _bt_cmd "$result"
            echo ""
            _bt_tip "Press ${_BT_BOLD}Ctrl+B${_BT_RESET} after running it to get an explanation"
            echo ""

            # Copy to clipboard on macOS
            if command -v pbcopy &>/dev/null; then
                echo "$result" | pbcopy 2>/dev/null && \
                    echo "${_BT_YELLOW}  (copied to clipboard — just paste it!)${_BT_RESET}" && \
                    echo ""
            fi
            return 0
        fi

        _bt_warn "OpenClaw didn't respond — using local patterns instead"
    else
        _bt_warn "OpenClaw not found — using local patterns"
        echo "  Install it from: ${_BT_CYAN}docs.openclaw.ai${_BT_RESET}"
        echo ""
    fi

    # Local fallback — pattern matching
    _bashtutor_local_suggest "$request"
}

# =============================================================================
# LOCAL PATTERN SUGGESTIONS (offline fallback)
# =============================================================================

function _bashtutor_local_suggest() {
    local request="$1"
    local req_lower=$(echo "$request" | tr '[:upper:]' '[:lower:]')

    local suggestion=""

    # File listing
    if [[ "$req_lower" =~ (show|list|see).*(file|folder|director) ]]; then
        if [[ "$req_lower" =~ (detail|size|date|long) ]]; then
            suggestion="ls -la"
        elif [[ "$req_lower" =~ (hidden|all) ]]; then
            suggestion="ls -a"
        else
            suggestion="ls -l"
        fi
    elif [[ "$req_lower" =~ (modified|changed|recent).*(today|last) ]]; then
        suggestion="find . -maxdepth 1 -newer \$(date -v-1d +%Y%m%d) -type f 2>/dev/null || find . -maxdepth 1 -mtime -1 -type f"
    elif [[ "$req_lower" =~ (find|search).*(file|folder) ]]; then
        if [[ "$req_lower" =~ pdf ]]; then
            suggestion="find ~/Downloads -name '*.pdf' -type f"
        elif [[ "$req_lower" =~ (name|called) ]]; then
            suggestion="find . -name '*FILENAME*' -type f"
        else
            suggestion="find . -type f -name '*SEARCH*'"
        fi
    # Disk / space
    elif [[ "$req_lower" =~ (disk|space|storage|how much) ]]; then
        if [[ "$req_lower" =~ (folder|director|here) ]]; then
            suggestion="du -sh *"
        else
            suggestion="df -h"
        fi
    # Copy / move
    elif [[ "$req_lower" =~ (copy|cp).*(folder|director) ]]; then
        suggestion="cp -r SOURCE DESTINATION"
    elif [[ "$req_lower" =~ copy ]]; then
        suggestion="cp SOURCE DESTINATION"
    elif [[ "$req_lower" =~ (move|rename) ]]; then
        suggestion="mv SOURCE DESTINATION"
    # Delete
    elif [[ "$req_lower" =~ (delete|remove|rm).*(folder|director) ]]; then
        suggestion="rm -rf FOLDER  # ⚠️  no undo — be careful!"
    elif [[ "$req_lower" =~ (delete|remove) ]]; then
        suggestion="rm FILENAME"
    # Create
    elif [[ "$req_lower" =~ (create|make|new).*(folder|director) ]]; then
        suggestion="mkdir -p FOLDERNAME"
    elif [[ "$req_lower" =~ (create|make|new).*(file) ]]; then
        suggestion="touch FILENAME"
    # Process / running
    elif [[ "$req_lower" =~ (running|process|cpu|memory|ram) ]]; then
        suggestion="ps aux | head -20"
    elif [[ "$req_lower" =~ (kill|stop|quit).*(process|app|program) ]]; then
        suggestion="kill -9 PID  # replace PID with the process ID number"
    # Network
    elif [[ "$req_lower" =~ (download|fetch|get).*(file|url|http) ]]; then
        suggestion="curl -O URL"
    elif [[ "$req_lower" =~ (internet|network|online|connected) ]]; then
        suggestion="ping -c 3 google.com"
    # Git
    elif [[ "$req_lower" =~ git.*(status|what) ]]; then
        suggestion="git status"
    elif [[ "$req_lower" =~ git.*(save|commit) ]]; then
        suggestion="git add . && git commit -m 'your message here'"
    elif [[ "$req_lower" =~ git.*(push|upload|send) ]]; then
        suggestion="git push"
    elif [[ "$req_lower" =~ git.*(pull|update|download) ]]; then
        suggestion="git pull"
    # Zip/archive
    elif [[ "$req_lower" =~ (zip|compress|archive) ]]; then
        suggestion="zip -r archive.zip FOLDER/"
    elif [[ "$req_lower" =~ (unzip|extract|uncompress) ]]; then
        suggestion="unzip archive.zip"
    # Permissions
    elif [[ "$req_lower" =~ (permission|executable|run|chmod) ]]; then
        suggestion="chmod +x FILENAME"
    # History
    elif [[ "$req_lower" =~ (history|previous|last.*command) ]]; then
        suggestion="history | tail -20"
    # Current location
    elif [[ "$req_lower" =~ (where.*(am i|are we)|current.*(folder|director|path)|location) ]]; then
        suggestion="pwd"
    # Text search
    elif [[ "$req_lower" =~ (search|find|grep).*(text|word|string|in) ]]; then
        suggestion="grep -r 'SEARCH_TERM' ."
    # File size
    elif [[ "$req_lower" =~ (size|big|large|small).*(file) ]]; then
        suggestion="ls -lhS | head -10  # largest files first"
    fi

    echo ""
    if [[ -n "$suggestion" ]]; then
        echo "${_BT_BOLD}${_BT_WHITE}Best match (local):${_BT_RESET}"
        echo ""
        _bt_cmd "$suggestion"
        echo ""
        _bt_tip "For better results, start OpenClaw and try again"
    else
        _bt_warn "Not sure how to do that with local patterns"
        echo ""
        echo "  Try describing it differently, or start OpenClaw for smarter suggestions."
        echo ""
        echo "  ${_BT_BOLD}Some things I can help with offline:${_BT_RESET}"
        echo "  • show files, find files, delete files"
        echo "  • check disk space, copy, move, rename"
        echo "  • git commands, zip/unzip, search text"
        echo "  • check network, list processes"
    fi
    echo ""
}

# =============================================================================
# PUBLIC COMMANDS
# =============================================================================

function bashtutor_toggle() {
    if [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" ]]; then
        export BASHTUTOR_AUTO_EXPLAIN="0"
        echo ""
        _bt_info "Auto-explain is now OFF"
        echo "  (Press Ctrl+B any time to explain a command manually)"
        echo ""
    else
        export BASHTUTOR_AUTO_EXPLAIN="1"
        echo ""
        _bt_success "Auto-explain is now ON — I'll explain every command you run"
        echo ""
    fi
}

function bashtutor_history() {
    echo ""
    echo "${_BT_BOLD}${_BT_CYAN}📜 Recent commands:${_BT_RESET}"
    echo ""

    if [[ ! -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        _bt_warn "No history yet — run some commands first"
        echo ""
        return 0
    fi

    local i=1
    tail -10 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | while IFS= read -r line; do
        local cmd=$(echo "$line" | sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | sed 's/\\"/"/g')
        local exit_code=$(echo "$line" | sed -n 's/.*"exit_code":\([0-9]*\).*/\1/p')
        local ts=$(echo "$line" | sed -n 's/.*"timestamp":"\([^"]*\)".*/\1/p')

        local status_icon="✅"
        [[ "$exit_code" != "0" ]] && status_icon="❌"

        printf "  ${_BT_YELLOW}%2d.${_BT_RESET} %s ${_BT_BLUE}%s${_BT_RESET}  ${_BT_WHITE}%s${_BT_RESET}\n" \
            "$i" "$status_icon" "$cmd" "$ts"
        ((i++))
    done
    echo ""
}

function bashtutor_status() {
    echo ""
    echo "${_BT_BOLD}${_BT_CYAN}🎓 BashTutor ${BASHTUTOR_VERSION} — OpenClaw Edition${_BT_RESET}"
    echo ""

    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        _bt_success "OpenClaw: connected"
    else
        _bt_warn "OpenClaw: not found  (local patterns only)"
    fi

    local auto_status="off"
    [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" ]] && auto_status="${_BT_GREEN}on${_BT_RESET}"

    echo "  Auto-explain:  $auto_status"
    echo "  Architecture:  $BASHTUTOR_ARCH"
    echo "  Config:        $BASHTUTOR_CONFIG_FILE"
    echo "  History:       $BASHTUTOR_HISTORY_FILE"
    echo "  Cache:         $BASHTUTOR_CACHE_DIR"
    echo ""
    echo "  ${_BT_BOLD}Commands:${_BT_RESET}  bashme / bt / Ctrl+B / btx / bth / bashtutor_status"
    echo ""
}

function bashtutor_clear_cache() {
    _bashtutor_cache_clear
}

# =============================================================================
# CLEANUP
# =============================================================================

function _bashtutor_cleanup() {
    _bashtutor_cache_clean_expired 2>/dev/null || true
}

function _bashtutor_cache_clean_expired() {
    [[ ! -d "$BASHTUTOR_CACHE_DIR" ]] && return 0
    local ttl_secs=$(( ${BASHTUTOR_CACHE_TTL:-24} * 3600 ))
    local now=$(date +%s 2>/dev/null || echo 0)
    for f in "$BASHTUTOR_CACHE_DIR"/*.cache; do
        [[ ! -f "$f" ]] && continue
        local mtime=$(stat -f%m "$f" 2>/dev/null || stat -c%Y "$f" 2>/dev/null || echo 0)
        [[ $(( now - mtime )) -gt $ttl_secs ]] && rm -f "$f" 2>/dev/null
    done
}

trap '_bashtutor_cleanup' EXIT 2>/dev/null || true

# =============================================================================
# REGISTER HOOKS, KEYBINDINGS & ALIASES
# =============================================================================

autoload -Uz add-zsh-hook 2>/dev/null && {
    add-zsh-hook preexec bashtutor_preexec
    add-zsh-hook precmd bashtutor_precmd
}

# Ctrl+B → explain last command
zle -N bashtutor_explain_last 2>/dev/null && \
    bindkey '^B' bashtutor_explain_last 2>/dev/null || true

# Aliases
alias bt='bashme'
alias btx='bashtutor_toggle'
alias bth='bashtutor_history'
alias bts='bashtutor_status'

# =============================================================================
# BOOT
# =============================================================================

_bashtutor_setup

# Welcome message (once per session)
if [[ -z "${BASHTUTOR_WELCOME_SHOWN}" ]]; then
    echo ""
    echo "${_BT_BOLD}${_BT_CYAN}🎓 BashTutor ${BASHTUTOR_VERSION}${_BT_RESET} ${_BT_WHITE}— OpenClaw Edition 🦀${_BT_RESET}"

    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        echo "   ${_BT_GREEN}✅ OpenClaw ready${_BT_RESET}"
    else
        echo "   ${_BT_YELLOW}⚠️  OpenClaw not found — running in local mode${_BT_RESET}"
    fi

    echo "   Type ${_BT_BOLD}${_BT_CYAN}bashme${_BT_RESET} to get started, or ${_BT_BOLD}${_BT_MAGENTA}Ctrl+B${_BT_RESET} to explain your last command"
    echo ""
    export BASHTUTOR_WELCOME_SHOWN="1"
fi
