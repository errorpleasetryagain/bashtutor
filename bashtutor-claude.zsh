#!/usr/bin/env zsh
# ╔══════════════════════════════════════════════════════════════╗
# ║  BashTutor — Claude Edition  🤖                             ║
# ║  Version: 1.1.0                                             ║
# ║  AI backend: Anthropic Claude API                           ║
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
export BASHTUTOR_BACKEND="claude"

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
    _BT_ORANGE=$(printf '\033[38;5;179m')   # khaki
    _BT_GREEN=$(printf '\033[38;5;22m')    # dark green
else
    _BT_RESET="" _BT_BOLD="" _BT_CYAN="" _BT_GREEN=""
    _BT_YELLOW="" _BT_MAGENTA="" _BT_RED="" _BT_BLUE="" _BT_WHITE="" _BT_ORANGE=""
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
export BASHTUTOR_CLAUDE_MODEL="claude-sonnet-4-20250514"
export BASHTUTOR_SEEN_COMMANDS_FILE="${HOME}/.bashtutor/seen_commands"
export BASHTUTOR_LAST_INTERVENTION=0

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
        [lh]="Listed files with sizes in human-friendly format (KB, MB, GB)"
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
        [bzip2]="Compressed a file with better compression than gzip"
        [bunzip2]="Decompressed a .bz2 file"
        [xz]="Compressed a file with very high compression ratio"
        [unxz]="Decompressed an .xz file"
        [7z]="Packed or unpacked a 7-Zip archive"
        [zstd]="Compressed or decompressed a zstd file — fast compression"
        [chmod]="Changed who can read, write, or run a file"
        [chown]="Changed who owns a file"
        [chgrp]="Changed which group owns a file"
        [umask]="Set the default permissions for new files you create"
        [sudo]="Ran a command with admin powers — use carefully"
        [su]="Switched to a different user account"
        [passwd]="Changed a user's password"
        [git]="Ran a git command — for tracking code changes"
        [git-status]="Checked what's changed in your git repository"
        [git-log]="Showed the history of commits with details"
        [git-diff]="Showed what changed between versions"
        [git-branch]="Listed or managed branches in your repository"
        [git-checkout]="Switched to a different branch or version"
        [git-merge]="Combined changes from one branch into another"
        [git-rebase]="Replayed commits from one branch on top of another"
        [git-clone]="Downloaded a full copy of a repository"
        [git-fetch]="Downloaded updates from a remote repository"
        [git-push]="Uploaded your commits to a remote repository"
        [git-pull]="Downloaded and merged updates from a remote repository"
        [git-stash]="Saved your changes temporarily without committing"
        [git-tag]="Created a named marker for a specific commit"
        [git-blame]="Showed who changed each line in a file and when"
        [git-reset]="Undid commits or unstaged files"
        [git-add]="Staged changes to be included in the next commit"
        [git-commit]="Saved your staged changes permanently"
        [git-remote]="Managed connections to remote repositories"
        [brew]="Ran Homebrew — macOS package manager"
        [brew-install]="Installed a package via Homebrew"
        [brew-uninstall]="Removed a package installed via Homebrew"
        [brew-update]="Updated Homebrew itself"
        [brew-upgrade]="Upgraded all installed packages to latest versions"
        [brew-list]="Showed all packages installed via Homebrew"
        [brew-search]="Searched for packages available in Homebrew"
        [brew-info]="Showed detailed information about a Homebrew package"
        [brew-doctor]="Checked Homebrew installation for problems"
        [npm]="Ran Node.js package manager"
        [npm-init]="Created a new Node.js project with a package.json file"
        [npm-install]="Installed packages listed in package.json"
        [npm-run]="Ran a script defined in package.json"
        [npm-start]="Started your Node.js application"
        [npm-list]="Showed all installed npm packages"
        [npm-search]="Searched for packages on the npm registry"
        [npm-update]="Updated packages to their latest versions"
        [npm-audit]="Checked for security vulnerabilities in packages"
        [pip]="Ran Python package manager (Python 2)"
        [pip3]="Ran Python 3 package manager"
        [pip-install]="Installed a Python package"
        [pip-list]="Showed all installed Python packages"
        [pip-freeze]="Saved a list of installed packages to a file"
        [pip-uninstall]="Removed a Python package"
        [pip-search]="Searched for Python packages"
        [python]="Ran a Python program or script (usually Python 2)"
        [python3]="Ran a Python 3 program or script"
        [node]="Ran a Node.js program"
        [docker]="Ran a Docker container command"
        [docker-ps]="Showed all running Docker containers"
        [docker-images]="Showed all Docker images on your system"
        [docker-run]="Started a new Docker container"
        [docker-build]="Built a Docker image from a Dockerfile"
        [docker-stop]="Stopped a running Docker container"
        [docker-rm]="Removed a Docker container"
        [docker-pull]="Downloaded a Docker image from a registry"
        [docker-push]="Uploaded a Docker image to a registry"
        [docker-logs]="Showed output/logs from a Docker container"
        [docker-exec]="Ran a command inside a running container"
        [docker-compose]="Managed multi-container Docker applications"
        [kubectl]="Ran a Kubernetes command"
        [make]="Built software using instructions in a Makefile"
        [cmake]="Generated build system files from CMakeLists.txt"
        [gradle]="Built Java/Kotlin projects with Gradle"
        [mvn]="Built Java projects with Maven"
        [cargo]="Built Rust projects with Cargo"
        [go]="Compiled or ran Go programs"
        [rustc]="Compiled a Rust program"
        [javac]="Compiled a Java program to bytecode"
        [java]="Ran a compiled Java program"
        [deno]="Ran a Deno (modern Node.js alternative) program"
        [ruby]="Ran a Ruby program or script"
        [gem]="Managed Ruby packages"
        [bundle]="Managed Ruby project dependencies"
        [rails]="Ran a Ruby on Rails web application"
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
        [sips]="Manipulated image files — crop, rotate, resize (macOS)"
        [mdls]="Showed detailed metadata about a file (macOS)"
        [mdfind]="Searched for files using Spotlight (macOS)"
        [osascript]="Ran AppleScript commands (macOS)"
        [xattr]="Managed extended file attributes"
        [file]="Showed what type of file something is"
        [stat]="Showed detailed file information — size, permissions, dates"
        [xargs]="Ran a command once for each item from a list"
        [awk]="Processed text — great for working with columns"
        [sed]="Edited text using find-and-replace rules"
        [sort]="Sorted lines alphabetically or numerically"
        [uniq]="Removed duplicate lines"
        [wc]="Counted words, lines, or characters in a file"
        [tr]="Translated or deleted characters"
        [cut]="Cut out specific columns from text"
        [paste]="Joined lines from multiple files side by side"
        [join]="Merged lines from files that have a common key"
        [comm]="Compared two sorted files and showed differences"
        [column]="Aligned text into neat columns"
        [fmt]="Rewrapped text to fit a width limit"
        [split]="Split a file into smaller pieces"
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
        [timeout]="Ran a command and stopped it if it takes too long"
        [watch]="Ran a command repeatedly and showed the output"
        [nice]="Ran a command with lower priority"
        [wait]="Waited for a background job to finish"
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
        [mtr]="Showed network path with live statistics — mix of traceroute and ping"
        [whois]="Looked up domain registration information"
        [dig]="Looked up DNS information for a domain"
        [nslookup]="Queried a DNS server"
        [host]="Found the IP address for a domain name"
        [nc]="Tested network connections — great for checking if ports are open"
        [telnet]="Connected to a remote server on a specific port"
        [tcpdump]="Captured network traffic for analysis"
        [ssh-keygen]="Generated SSH security keys for passwordless login"
        [ssh-copy-id]="Copied your SSH public key to a server"
        [sftp]="Connected to a server for secure file transfer"
        [vim]="Opened a powerful text editor — press :q to exit"
        [nano]="Opened an easier text editor — press Ctrl+X to exit"
        [emacs]="Opened a highly customizable text editor"
        [code]="Opened Visual Studio Code"
        [subl]="Opened Sublime Text editor"
        [openssl]="Ran cryptography and certificate tools"
        [base64]="Encoded or decoded base64 data"
        [md5]="Calculated an MD5 checksum"
        [shasum]="Calculated a SHA checksum"
        [diskutil]="Managed disks and volumes (macOS)"
        [hdiutil]="Worked with disk images (macOS)"
        [defaults]="Read or wrote macOS app preferences"
        [plutil]="Read or wrote property list files (.plist)"
        [launchctl]="Managed macOS background services"
        [pmset]="Managed power settings (macOS)"
        [softwareupdate]="Managed macOS software updates"
        [xcode-select]="Managed Xcode command line tools"
        [security]="Managed certificates and keychains (macOS)"
        [spctl]="Managed system security policies (macOS)"
        [codesign]="Signed code with a digital signature (macOS)"
        [networksetup]="Managed network configuration (macOS)"
        [scutil]="Queried system configuration (macOS)"
        [systemsetup]="Configured system settings (macOS)"
        [mysql]="Opened a MySQL database client"
        [psql]="Opened a PostgreSQL database client"
        [sqlite3]="Opened an SQLite database"
        [mongosh]="Opened a MongoDB database shell"
        [redis-cli]="Opened a Redis cache command-line client"
        [systemctl]="Managed services on Linux systems"
        [systemd]="Managed system services and boot process (Linux)"
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
    _bashtutor_zle_ghost_setup 2>/dev/null || true
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

# Smart suggestions based on command history? (0 = off, 1 = on)
BASHTUTOR_SMART_SUGGEST=0
EOF
}

function _bashtutor_load_config() {
    BASHTUTOR_AUTO_EXPLAIN="${BASHTUTOR_AUTO_EXPLAIN:-0}"
    BASHTUTOR_CACHE_TTL="${BASHTUTOR_CACHE_TTL:-24}"
    BASHTUTOR_MAX_HISTORY="${BASHTUTOR_MAX_HISTORY:-1000}"
    BASHTUTOR_VERBOSE="${BASHTUTOR_VERBOSE:-0}"
    BASHTUTOR_SMART_SUGGEST="${BASHTUTOR_SMART_SUGGEST:-0}"

    [[ -f "$BASHTUTOR_CONFIG_FILE" ]] && source "$BASHTUTOR_CONFIG_FILE" 2>/dev/null || true

    [[ -z "$BASHTUTOR_CACHE_TTL" ]] && BASHTUTOR_CACHE_TTL=24
    [[ -z "$BASHTUTOR_MAX_HISTORY" ]] && BASHTUTOR_MAX_HISTORY=1000
    [[ -z "$BASHTUTOR_SMART_SUGGEST" ]] && BASHTUTOR_SMART_SUGGEST=0
}

function _bashtutor_check_ai() {
    BASHTUTOR_AI_AVAILABLE=""
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        BASHTUTOR_AI_AVAILABLE="1"
    fi
}

# =============================================================================
# SMART EXPLANATION TRIGGER
# =============================================================================

function _bashtutor_is_interesting() {
    local cmd="$1" exit_code="${2:-0}"

    # Always interesting if command failed
    [[ "$exit_code" -ne 0 ]] && return 0

    # Build command signature (base + flags)
    local base_cmd=$(echo "$cmd" | awk '{print $1}' 2>/dev/null)
    local cmd_signature="${base_cmd} $(echo "$cmd" | sed "s/^[^ ]* //" | sed 's/[^ -]*//g' | tr -s ' ')"

    # Check if we've seen this exact command before
    if [[ -f "$BASHTUTOR_SEEN_COMMANDS_FILE" ]]; then
        grep -F "$cmd" "$BASHTUTOR_SEEN_COMMANDS_FILE" &>/dev/null && return 1
    fi

    # Record this as seen
    mkdir -p "$(dirname "$BASHTUTOR_SEEN_COMMANDS_FILE")" 2>/dev/null
    echo "$cmd" >> "$BASHTUTOR_SEEN_COMMANDS_FILE" 2>/dev/null || true

    return 0
}

# =============================================================================
# PROACTIVE INTERVENTION
# =============================================================================

function _bashtutor_check_struggling() {
    local cmd="$1" exit_code="${2:-0}"

    # Cooldown: don't intervene more than once every 30 seconds
    local now=$(date +%s 2>/dev/null || echo 0)
    if [[ $((now - BASHTUTOR_LAST_INTERVENTION)) -lt 30 ]]; then
        return 0
    fi

    local base_cmd=$(echo "$cmd" | awk '{print $1}' 2>/dev/null)

    # Pattern 1: Command not found (typo detection)
    if [[ "$exit_code" -eq 127 ]]; then
        local suggestion=$(_bashtutor_suggest_typo_fix "$base_cmd")
        if [[ -n "$suggestion" ]]; then
            echo ""
            _bt_warn "That command wasn't found — did you mean ${_BT_CYAN}${suggestion}${_BT_RESET}?"
            echo ""
            export BASHTUTOR_LAST_INTERVENTION="$now"
            return 0
        fi
    fi

    # Pattern 2: Repeated failure (same command failed 2+ times in last 5 history entries)
    if [[ "$exit_code" -ne 0 && -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        local recent_failures=$(tail -5 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | \
            grep "\"exit_code\":[^0]" | \
            sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | \
            sed 's/\\"/"/g; s/\\\\/\\/g' | \
            head -1)

        local same_cmd_count=$(tail -5 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | \
            grep -F "$base_cmd" | \
            wc -l | tr -d ' ')

        if [[ "$same_cmd_count" -ge 2 ]]; then
            echo ""
            _bt_warn "That command keeps failing — try ${_BT_CYAN}bashme explain${_BT_RESET} what you need, and I can help"
            echo ""
            export BASHTUTOR_LAST_INTERVENTION="$now"
            return 0
        fi
    fi

    # Pattern 3: Stuck in a directory (ls or pwd 3+ times without cd)
    if [[ -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        local ls_pwd_count=$(tail -10 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | \
            sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | \
            grep -E '^(ls|pwd)' | \
            wc -l | tr -d ' ')

        local last_cd=$(tail -10 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | \
            sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | \
            grep -E '^cd' | \
            wc -l | tr -d ' ')

        if [[ "$ls_pwd_count" -ge 3 && "$last_cd" -eq 0 ]]; then
            echo ""
            _bt_tip "Looks like you might want to move to a different folder — try ${_BT_CYAN}bashme go to my downloads${_BT_RESET}}"
            echo ""
            export BASHTUTOR_LAST_INTERVENTION="$now"
            return 0
        fi
    fi
}

function _bashtutor_suggest_typo_fix() {
    local typed="$1"

    # Build a simple list of common commands to check
    local closest=""
    local closest_score=0

    for cmd_key in "${!BASHTUTOR_EXPLANATIONS[@]}"; do
        # Simple string distance: if first 2-3 chars match, it's a candidate
        if [[ "${cmd_key:0:2}" == "${typed:0:2}" ]]; then
            return 0
            echo "$cmd_key"
        fi
    done

    # No close match found
    return 1
}

# =============================================================================
# IMPROVEMENT 3: HISTORY-BASED LEARNING & SMART SUGGESTIONS
# =============================================================================

function _bashtutor_learn_sequence() {
    local current_cmd="$1"
    [[ -z "$current_cmd" ]] && return 0

    # Get the previous command from history
    local prev_cmd=""
    if [[ -f "$BASHTUTOR_HISTORY_FILE" ]]; then
        # Get the second-to-last entry (last is the current command)
        prev_cmd=$(tail -2 "$BASHTUTOR_HISTORY_FILE" 2>/dev/null | head -1 | \
            sed -n 's/.*"command":"\([^"]*\)".*/\1/p' | \
            sed 's/\\"/"/g; s/\\\\/\\/g')
    fi

    [[ -z "$prev_cmd" ]] && return 0

    # Extract base commands (first word only)
    local prev_base=$(echo "$prev_cmd" | awk '{print $1}')
    local curr_base=$(echo "$current_cmd" | awk '{print $1}')

    # Write the pair to sequences file
    mkdir -p "$(dirname "$BASHTUTOR_SEQUENCES_FILE")" 2>/dev/null
    echo "${prev_base}|||${curr_base}" >> "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null || true

    # Trim sequences file to 500 lines max
    if [[ -f "$BASHTUTOR_SEQUENCES_FILE" ]]; then
        local lines=$(wc -l < "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null | tr -d ' ')
        if [[ "$lines" -gt 500 ]]; then
            local tmp=$(mktemp 2>/dev/null) || return 0
            tail -500 "$BASHTUTOR_SEQUENCES_FILE" > "$tmp" && mv "$tmp" "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null || rm -f "$tmp"
        fi
    fi
}

function _bashtutor_suggest_next() {
    local current_cmd="$1"
    [[ -z "$current_cmd" || ! -f "$BASHTUTOR_SEQUENCES_FILE" ]] && return 1

    local curr_base=$(echo "$current_cmd" | awk '{print $1}')

    # Count how many times each next-command followed this one
    local suggestion=$(grep "^${curr_base}|||" "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null | \
        cut -d'|' -f3 | \
        sort | uniq -c | sort -rn | \
        awk '$1 >= 3 {print $2; exit}')

    [[ -n "$suggestion" ]] && echo "$suggestion"
    return 0
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
# IMPROVEMENT 4: DESTRUCTIVE COMMAND SAFETY NET
# =============================================================================

function _bashtutor_safety_check() {
    local cmd="$1"
    [[ -z "$cmd" ]] && return 0

    local base_cmd=$(echo "$cmd" | awk '{print $1}')

    # Pattern 1: rm -rf or rm -r (recursive delete)
    if [[ "$cmd" =~ ^rm[[:space:]]+-r ]]; then
        local target=$(echo "$cmd" | sed 's/^rm[[:space:]]*-r[^[:space:]]*[[:space:]]*//' | awk '{print $1}')
        echo ""
        _bt_warn "HEADS UP: This will permanently delete ${target} — no undo!"
        echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
        sleep 2
        return 0
    fi

    # Pattern 2: rm on important directories
    if [[ "$cmd" =~ ^rm[[:space:]]+ ]]; then
        local target=$(echo "$cmd" | sed 's/^rm[[:space:]]*//' | awk '{print $1}')
        if [[ "$target" =~ ^(/|~|~/Documents|~/Desktop|/.*) ]]; then
            echo ""
            _bt_warn "HEADS UP: This will permanently delete ${target} — no undo!"
            echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
            sleep 2
            return 0
        fi
    fi

    # Pattern 3: chmod -R 777 (world-writable security risk)
    if [[ "$cmd" =~ chmod[[:space:]]+-R[[:space:]]+777 ]]; then
        local target=$(echo "$cmd" | sed 's/^chmod[[:space:]]*-R[[:space:]]*777[[:space:]]*//' | awk '{print $1}')
        echo ""
        _bt_warn "HEADS UP: This will make everything in ${target} readable by everyone on this computer!"
        echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
        sleep 2
        return 0
    fi

    # Pattern 4: chmod -R on root or home
    if [[ "$cmd" =~ chmod[[:space:]]+-R.*/[[:space:]] ]] || [[ "$cmd" =~ chmod[[:space:]]+-R.*~[[:space:]] ]]; then
        local target=$(echo "$cmd" | sed 's/^chmod[[:space:]]*-R[[:space:]]*[^ ]*[[:space:]]*//' | awk '{print $1}')
        echo ""
        _bt_warn "HEADS UP: This will change permissions on ${target} and everything inside!"
        echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
        sleep 2
        return 0
    fi

    # Pattern 5: dd commands (disk destroyer)
    if [[ "$cmd" =~ ^dd[[:space:]] ]]; then
        echo ""
        _bt_warn "HEADS UP: This writes directly to a disk — one wrong path can wipe a drive!"
        echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
        sleep 2
        return 0
    fi

    # Pattern 6: mkfs (format a drive)
    if [[ "$cmd" =~ ^mkfs[[:space:]] ]]; then
        echo ""
        _bt_warn "HEADS UP: This will FORMAT a drive — all data will be gone!"
        echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
        sleep 2
        return 0
    fi

    # Pattern 7: colon truncate (: > filename)
    if [[ "$cmd" =~ ^:[[:space:]]*\> ]]; then
        local target=$(echo "$cmd" | sed 's/^:[[:space:]]*>[[:space:]]*//' | awk '{print $1}')
        echo ""
        _bt_warn "HEADS UP: This will erase the contents of ${target}!"
        echo "   Running it anyway in 2 seconds... (Ctrl+C to cancel)"
        sleep 2
        return 0
    fi

    return 0
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

    # Smart explanation: only explain if interesting
    if [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" ]]; then
        if _bashtutor_is_interesting "$BASHTUTOR_LAST_COMMAND" "$exit_code"; then
            _bashtutor_explain "$BASHTUTOR_LAST_COMMAND" "$exit_code"
        fi
    fi

    # Proactive intervention: step in if user is struggling
    _bashtutor_check_struggling "$BASHTUTOR_LAST_COMMAND" "$exit_code"

    # Learning: record command sequences
    _bashtutor_learn_sequence "$BASHTUTOR_LAST_COMMAND"

    # Smart suggestions: if command succeeded, suggest what typically comes next
    if [[ "$exit_code" -eq 0 ]]; then
        if [[ "${BASHTUTOR_AUTO_EXPLAIN}" == "1" || "${BASHTUTOR_SMART_SUGGEST}" == "1" ]]; then
            local next_suggestion=$(_bashtutor_suggest_next "$BASHTUTOR_LAST_COMMAND")
            if [[ -n "$next_suggestion" ]]; then
                echo ""
                _bt_tip "You usually run '${next_suggestion}' after this — type '${_BT_CYAN}bt do ${next_suggestion}${_BT_RESET}' or just run it"
                echo ""
            fi
        fi
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
# AI: Claude API inference
# =============================================================================

function _bashtutor_ask_claude() {
    local prompt="$1"
    local timeout_secs="${2:-20}"

    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        return 1
    fi

    # Escape the prompt for JSON
    local escaped_prompt=$(_bashtutor_json_escape "$prompt")

    local result
    result=$(timeout "$timeout_secs" curl -s \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{\"model\":\"${BASHTUTOR_CLAUDE_MODEL}\",\"max_tokens\":256,\"messages\":[{\"role\":\"user\",\"content\":\"${escaped_prompt}\"}]}" \
        "https://api.anthropic.com/v1/messages" 2>/dev/null)

    if [[ -n "$result" ]]; then
        # Extract text from Claude's response JSON
        local text
        text=$(echo "$result" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'content' in d and d['content']:
        print(d['content'][0].get('text','').strip())
except: pass
" 2>/dev/null)
        if [[ -n "$text" ]]; then
            echo "$text"
            return 0
        fi
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

        explanation=$(_bashtutor_ask_claude "$prompt" 10)
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
        _bt_info "BashTutor ${BASHTUTOR_VERSION} — Claude Edition 🤖"
        echo ""
        echo "  ${_BT_BOLD}How to use:${_BT_RESET}"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} ${_BT_WHITE}<what you want to do in plain English>${_BT_RESET}"
        echo ""
        echo "  ${_BT_BOLD}Examples:${_BT_RESET}"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} show files modified today"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} find all pdf files in downloads"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} how much disk space am i using"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} copy everything from desktop to documents"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} run a python script called myscript.py"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} install the requests python package"
        echo ""
        echo "  ${_BT_BOLD}Explain any command:${_BT_RESET}"
        echo "  Paste a command and add ${_BT_YELLOW}what?${_BT_RESET} at the end:"
        echo "  ${_BT_CYAN}bashme${_BT_RESET} find . -name '*.log' -mtime +7 -delete what?"
        echo ""
        echo "  ${_BT_BOLD}Shortcuts:${_BT_RESET}"
        echo "  ${_BT_MAGENTA}bt${_BT_RESET}              same as bashme"
        echo "  ${_BT_MAGENTA}Ctrl+B${_BT_RESET}          explain the last command"
        echo "  ${_BT_MAGENTA}btx${_BT_RESET}             toggle auto-explain on/off"
        echo "  ${_BT_MAGENTA}bth${_BT_RESET}             show recent command history"
        echo ""
        return 0
    fi

    # -------------------------------------------------------------------------
    # WHAT? MODE — explain a command instead of suggesting one
    # Usage: bashme <any command> what?
    # -------------------------------------------------------------------------
    if [[ "$request" == *" what?" || "$request" == *" what" || "$request" == "what?"* ]]; then
        local cmd_to_explain="${request% what?}"
        cmd_to_explain="${cmd_to_explain% what}"
        cmd_to_explain="${cmd_to_explain#what? }"
        cmd_to_explain="${cmd_to_explain#what }"
        cmd_to_explain="$(echo "$cmd_to_explain" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

        echo ""
        echo "${_BT_BOLD}${_BT_WHITE}Explaining:${_BT_RESET} ${_BT_BLUE}${cmd_to_explain}${_BT_RESET}"
        echo ""

        local explanation=""

        if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
            _bt_thinking
            local what_prompt="Explain this command in plain English. No jargon. Be friendly and clear. Use 2-4 short sentences. Break it down piece by piece if it has multiple parts.

Command: ${cmd_to_explain}

Format your answer like:
What it does: [one sentence summary]
How it works: [break down each part simply]
Watch out: [any gotchas or risks, or skip this if none]"

            explanation=$(_bashtutor_ask_claude "$what_prompt" 20)
        fi

        if [[ -n "$explanation" ]]; then
            echo "$explanation" | while IFS= read -r line; do
                echo "  ${_BT_CYAN}${line}${_BT_RESET}"
            done
        else
            local base=$(echo "$cmd_to_explain" | awk '{print $1}')
            local local_exp="${BASHTUTOR_EXPLANATIONS[$base]}"
            if [[ -n "$local_exp" ]]; then
                _bt_explain "$local_exp"
                echo ""
                _bt_tip "Set ANTHROPIC_API_KEY for a full breakdown"
            else
                _bt_warn "Not sure what '$base' does — add your API key for full explanations"
            fi
        fi
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

    local prompt="You are a helpful bash and Python tutor. Give ONLY the command, nothing else — no explanation, no markdown, no code fences.

Rules:
- For shell/file/system tasks: give a zsh/bash command
- For Python tasks (install packages, run scripts, virtual envs, pip): give the correct shell command to do it (e.g. pip3 install X, python3 script.py, python3 -m venv env)
- For 'write a python script that does X': give a python3 one-liner or the python3 command to run an inline script using -c flag
- macOS, zsh shell
- IMPORTANT: Never use bare 'find .' without -maxdepth. Always add -maxdepth 2 or less to avoid scanning the entire home folder. For 'modified today' use: find . -maxdepth 2 -mtime -1 -type f
- Keep commands short, safe, and scoped to the current directory unless the user specifies otherwise

Task: $request${history_context}

Reply with just the command."

    # Try OpenClaw
    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        echo ""
        _bt_thinking

        local result=$(_bashtutor_ask_claude "$prompt" 20)

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

        _bt_warn "Claude didn't respond — using local patterns instead"
    else
        _bt_warn "Claude API key not set — using local patterns"
        echo "  Get a free key at: ${_BT_CYAN}console.anthropic.com${_BT_RESET}"
        echo "  Then add to your ~/.zshrc:"
        echo "    ${_BT_YELLOW}export ANTHROPIC_API_KEY=\"sk-ant-...\"${_BT_RESET}"
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
    # File operations — count/manipulate
    elif [[ "$req_lower" =~ count.*(file|line) ]]; then
        if [[ "$req_lower" =~ line ]]; then
            suggestion="wc -l FILENAME"
        else
            suggestion="ls | wc -l"
        fi
    elif [[ "$req_lower" =~ (empty|erase|clear).*(file) ]]; then
        suggestion="> FILENAME"
    elif [[ "$req_lower" =~ (append|add).*(file|end) ]]; then
        suggestion="echo \"text\" >> FILENAME"
    elif [[ "$req_lower" =~ (follow|watch|tail).*(log) ]]; then
        suggestion="tail -f FILENAME"
    elif [[ "$req_lower" =~ (show|print).*(last|end) ]]; then
        suggestion="tail -100 FILENAME"
    elif [[ "$req_lower" =~ (find|search).*(large|big).*(file) ]]; then
        suggestion="find . -size +100M -type f"
    elif [[ "$req_lower" =~ (find|search).*(recent|modified) ]]; then
        suggestion="find . -mtime -1 -type f"
    elif [[ "$req_lower" =~ (check|test).*(exist|exist) ]]; then
        suggestion="test -f FILENAME && echo \"exists\" || echo \"not found\""
    elif [[ "$req_lower" =~ (type|kind).*(file|file) ]]; then
        suggestion="file FILENAME"
    elif [[ "$req_lower" =~ (encoding|charset).*(file) ]]; then
        suggestion="file -I FILENAME"
    elif [[ "$req_lower" =~ (symlink|link).*(target|point) ]]; then
        suggestion="readlink -f LINK"
    elif [[ "$req_lower" =~ (create|make).*(symlink|link) ]]; then
        suggestion="ln -s TARGET LINK_NAME"
    elif [[ "$req_lower" =~ (bulk|mass|many).*(rename) ]]; then
        suggestion="for f in *.old; do mv \"\$f\" \"\${f%.old}.new\"; done"
    # Python — run a script
    elif [[ "$req_lower" =~ (run|execute).*(python|py).*(script|file) ]]; then
        suggestion="python3 SCRIPT.py"
    elif [[ "$req_lower" =~ (run|execute).*\.py ]]; then
        suggestion="python3 SCRIPT.py"
    # Python — install a package
    elif [[ "$req_lower" =~ (install|add).*(python|pip).*(package|library|module) ]] || \
         [[ "$req_lower" =~ (pip|pip3).*(install) ]] || \
         [[ "$req_lower" =~ install.*python.* ]]; then
        suggestion="pip3 install PACKAGE_NAME"
    # Python — uninstall a package
    elif [[ "$req_lower" =~ (uninstall|remove).*(python|pip).*(package) ]]; then
        suggestion="pip3 uninstall PACKAGE_NAME"
    # Python — list installed packages
    elif [[ "$req_lower" =~ (list|show).*(python|pip).*(package|install) ]]; then
        suggestion="pip3 list"
    # Python — virtual environment
    elif [[ "$req_lower" =~ (create|make|new).*(virtual|venv|env) ]]; then
        suggestion="python3 -m venv env && source env/bin/activate"
    elif [[ "$req_lower" =~ (activate).*(virtual|venv|env) ]]; then
        suggestion="source env/bin/activate"
    elif [[ "$req_lower" =~ (deactivate|exit).*(virtual|venv|env) ]]; then
        suggestion="deactivate"
    # Python — check version
    elif [[ "$req_lower" =~ (python).*(version|which|where) ]]; then
        suggestion="python3 --version && which python3"
    # Python — run a one-liner
    elif [[ "$req_lower" =~ (python).*(print|calculate|convert|quick) ]]; then
        suggestion="python3 -c 'print(YOUR_CODE_HERE)'"
    # Python — requirements
    elif [[ "$req_lower" =~ (install).*(requirements|req) ]]; then
        suggestion="pip3 install -r requirements.txt"
    elif [[ "$req_lower" =~ (save|export|freeze).*(requirements|packages) ]]; then
        suggestion="pip3 freeze > requirements.txt"
    elif [[ "$req_lower" =~ (upgrade|update).*(pip) ]]; then
        suggestion="pip3 install --upgrade pip"
    # Homebrew
    elif [[ "$req_lower" =~ (brew|homebrew).*(install) ]]; then
        suggestion="brew install PACKAGE"
    elif [[ "$req_lower" =~ (brew|homebrew).*(uninstall|remove) ]]; then
        suggestion="brew uninstall PACKAGE"
    elif [[ "$req_lower" =~ (brew|homebrew).*(update|upgrade) ]]; then
        suggestion="brew update && brew upgrade"
    elif [[ "$req_lower" =~ (brew|homebrew).*(list|show) ]]; then
        suggestion="brew list"
    elif [[ "$req_lower" =~ (brew|homebrew).*(search) ]]; then
        suggestion="brew search QUERY"
    elif [[ "$req_lower" =~ (brew|homebrew).*(info) ]]; then
        suggestion="brew info PACKAGE"
    elif [[ "$req_lower" =~ (brew|homebrew).*(doctor) ]]; then
        suggestion="brew doctor"
    # Node.js / npm
    elif [[ "$req_lower" =~ (npm|node).*(init) ]]; then
        suggestion="npm init -y"
    elif [[ "$req_lower" =~ (npm|node).*(install|package) ]]; then
        suggestion="npm install PACKAGE"
    elif [[ "$req_lower" =~ (npm|node).*(dev|development) ]]; then
        suggestion="npm install --save-dev PACKAGE"
    elif [[ "$req_lower" =~ (npm|node).*(list|packages) ]]; then
        suggestion="npm list"
    elif [[ "$req_lower" =~ (npm|node).*(run|script) ]]; then
        suggestion="npm run SCRIPT"
    elif [[ "$req_lower" =~ (npm|node).*(start) ]]; then
        suggestion="npm start"
    elif [[ "$req_lower" =~ (npm|node).*(build) ]]; then
        suggestion="npm run build"
    elif [[ "$req_lower" =~ (npm|node).*(update|upgrade) ]]; then
        suggestion="npm update"
    elif [[ "$req_lower" =~ (npm|node).*(audit|security) ]]; then
        suggestion="npm audit fix"
    # Git (expanded)
    elif [[ "$req_lower" =~ git.*(log|history) ]]; then
        suggestion="git log --oneline -20"
    elif [[ "$req_lower" =~ git.*(diff|different) ]]; then
        suggestion="git diff"
    elif [[ "$req_lower" =~ git.*(branch) ]]; then
        suggestion="git branch -a"
    elif [[ "$req_lower" =~ git.*(create|new).*(branch) ]]; then
        suggestion="git checkout -b BRANCH_NAME"
    elif [[ "$req_lower" =~ git.*(switch|checkout).*(branch) ]]; then
        suggestion="git checkout BRANCH_NAME"
    elif [[ "$req_lower" =~ git.*(merge) ]]; then
        suggestion="git merge BRANCH_NAME"
    elif [[ "$req_lower" =~ git.*(stash) ]]; then
        if [[ "$req_lower" =~ (pop|restore) ]]; then
            suggestion="git stash pop"
        else
            suggestion="git stash"
        fi
    elif [[ "$req_lower" =~ git.*(clone) ]]; then
        suggestion="git clone URL"
    elif [[ "$req_lower" =~ git.*(remote) ]]; then
        suggestion="git remote -v"
    elif [[ "$req_lower" =~ git.*(undo|revert).*(commit) ]]; then
        suggestion="git reset HEAD~1"
    elif [[ "$req_lower" =~ git.*(discard|forget).*(change) ]]; then
        suggestion="git checkout -- ."
    elif [[ "$req_lower" =~ git.*(tag) ]]; then
        suggestion="git tag v1.0.0"
    elif [[ "$req_lower" =~ git.*(blame) ]]; then
        suggestion="git blame FILENAME"
    # Docker
    elif [[ "$req_lower" =~ docker.*(list|show).*(container) ]]; then
        suggestion="docker ps"
    elif [[ "$req_lower" =~ docker.*(all|every).*(container) ]]; then
        suggestion="docker ps -a"
    elif [[ "$req_lower" =~ docker.*(run|start).*(container) ]]; then
        suggestion="docker run -it IMAGE"
    elif [[ "$req_lower" =~ docker.*(stop).*(container) ]]; then
        suggestion="docker stop CONTAINER"
    elif [[ "$req_lower" =~ docker.*(remove|delete).*(container) ]]; then
        suggestion="docker rm CONTAINER"
    elif [[ "$req_lower" =~ docker.*(list|show).*(image) ]]; then
        suggestion="docker images"
    elif [[ "$req_lower" =~ docker.*(pull|download).*(image) ]]; then
        suggestion="docker pull IMAGE"
    elif [[ "$req_lower" =~ docker.*(build).*(image) ]]; then
        suggestion="docker build -t NAME ."
    elif [[ "$req_lower" =~ docker.*(logs|output) ]]; then
        suggestion="docker logs CONTAINER"
    elif [[ "$req_lower" =~ docker.*(exec|into).*(container) ]]; then
        suggestion="docker exec -it CONTAINER bash"
    elif [[ "$req_lower" =~ docker.*(compose|multi).*(container) ]]; then
        if [[ "$req_lower" =~ (down|stop) ]]; then
            suggestion="docker-compose down"
        else
            suggestion="docker-compose up -d"
        fi
    # macOS specific
    elif [[ "$req_lower" =~ (mac|mac).*(specs|info|about|hardware) ]]; then
        suggestion="system_profiler SPHardwareDataType"
    elif [[ "$req_lower" =~ (battery|charge|power) ]]; then
        suggestion="pmset -g batt"
    elif [[ "$req_lower" =~ (wifi|wireless|network).*(connect) ]]; then
        suggestion="networksetup -getairportnetwork en0"
    elif [[ "$req_lower" =~ (port|listening|open) ]]; then
        suggestion="lsof -i -P -n | grep LISTEN"
    elif [[ "$req_lower" =~ (flush|clear).*(dns) ]]; then
        suggestion="sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
    elif [[ "$req_lower" =~ (firewall) ]]; then
        suggestion="sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate"
    elif [[ "$req_lower" =~ (kill|port).*(port|port) ]]; then
        suggestion="lsof -ti:PORT | xargs kill -9"
    elif [[ "$req_lower" =~ (who|using).*(port) ]]; then
        suggestion="lsof -i :PORT"
    elif [[ "$req_lower" =~ (ip|address|ip) ]]; then
        suggestion="ipconfig getifaddr en0"
    elif [[ "$req_lower" =~ (network|interface|interface) ]]; then
        suggestion="ifconfig"
    elif [[ "$req_lower" =~ (public|external).*(ip|address) ]]; then
        suggestion="curl -s ifconfig.me"
    # System info (expanded)
    elif [[ "$req_lower" =~ (cpu|memory|load|running).*(process|process) ]]; then
        suggestion="ps aux --sort=-%cpu | head -10"
    elif [[ "$req_lower" =~ (memory|ram).*(top|most) ]]; then
        suggestion="ps aux | sort -rk 4 | head -10"
    elif [[ "$req_lower" =~ (disk|io|input|output) ]]; then
        suggestion="iostat 1 5"
    elif [[ "$req_lower" =~ (load|system).*(load) ]]; then
        suggestion="uptime"
    fi

    echo ""
    if [[ -n "$suggestion" ]]; then
        echo "${_BT_BOLD}${_BT_WHITE}Best match (local):${_BT_RESET}"
        echo ""
        _bt_cmd "$suggestion"
        echo ""
        _bt_tip "Set ANTHROPIC_API_KEY in ~/.zshrc for smarter AI suggestions"
    else
        _bt_warn "Not sure how to do that with local patterns"
        echo ""
        echo "  Try describing it differently, or set your API key for smarter suggestions."
        echo ""
        echo "  ${_BT_BOLD}Some things I can help with offline:${_BT_RESET}"
        echo "  • show files, find files, delete files"
        echo "  • check disk space, copy, move, rename"
        echo "  • git commands, zip/unzip, search text"
        echo "  • check network, list processes"
        echo "  • python: run scripts, install packages, virtual envs"
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
    echo "${_BT_BOLD}${_BT_CYAN}🎓 BashTutor ${BASHTUTOR_VERSION} — Claude Edition 🤖${_BT_RESET}"
    echo ""

    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        _bt_success "Claude API: connected (${BASHTUTOR_CLAUDE_MODEL})"
    else
        _bt_warn "Claude API: no key set  (local patterns only)"
        echo "    Set ANTHROPIC_API_KEY in ~/.zshrc to enable AI"
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
# GHOST AUTOCOMPLETE (zsh-autosuggestions integration + pure ZLE fallback)
# =============================================================================
#
# How it works:
#   - If zsh-autosuggestions is installed: BashTutor feeds its learned
#     sequences into the suggestion source, so ghost text reflects YOUR habits
#   - If not installed: BashTutor implements its own grey ghost text via ZLE
#   - Either way: grey suggestion appears as you type, press → or Tab to accept
#   - Suggestions come from: your sequence history, then zsh history

# Override zsh-autosuggestions strategy to include BashTutor sequences
function _bashtutor_suggest_from_sequences() {
    local prefix="$1"
    [[ -z "$prefix" ]] && return 1
    [[ ! -f "$BASHTUTOR_SEQUENCES_FILE" ]] && return 1

    local base_prefix
    base_prefix=$(echo "$prefix" | awk '{print $1}' 2>/dev/null)
    [[ -z "$base_prefix" ]] && return 1

    # Find the most common next command after prefix's base command
    local next
    next=$(grep "^${base_prefix}|||" "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null | \
        awk -F'|||' '{print $2}' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')

    [[ -n "$next" ]] && { typeset -g REPLY="$next"; return 0; }
    return 1
}

# Pure ZLE ghost text implementation (no zsh-autosuggestions needed)
# Shows grey suggestion after cursor as you type
function _bashtutor_zle_ghost_setup() {
    # Only set up if zsh-autosuggestions is NOT already handling this
    if (( ${+ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE} )); then
        # zsh-autosuggestions is loaded — hook into it instead
        _bashtutor_hook_autosuggestions
        return 0
    fi

    # Pure ZLE implementation
    autoload -Uz add-zsh-hook 2>/dev/null || return 0

    # Ghost text state
    typeset -g _BT_GHOST_TEXT=""
    typeset -g _BT_GHOST_ACTIVE=0

    # Highlight style for ghost text — grey
    typeset -g ZLE_RPROMPT_INDENT=0

    function _bashtutor_ghost_update() {
        local buf="$BUFFER"
        _BT_GHOST_TEXT=""
        _BT_GHOST_ACTIVE=0

        [[ -z "$buf" ]] && { zle -R; return; }
        [[ ${#buf} -lt 2 ]] && { zle -R; return; }

        local suggestion=""

        # Source 1: BashTutor sequence learning
        if [[ -f "$BASHTUTOR_SEQUENCES_FILE" ]]; then
            local base_cmd
            base_cmd=$(echo "$buf" | awk '{print $1}' 2>/dev/null)
            if [[ -n "$base_cmd" ]]; then
                local seq_match
                seq_match=$(grep "^${base_cmd}|||" "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null | \
                    awk -F'|||' '{print $2}' | sort | uniq -c | sort -rn | \
                    awk 'NR==1 && $1>=2 {print $2}')
                [[ -n "$seq_match" ]] && suggestion="$seq_match"
            fi
        fi

        # Source 2: zsh history (most recent matching entry)
        if [[ -z "$suggestion" ]]; then
            local hist_match
            hist_match=$(fc -l 1 2>/dev/null | \
                awk -v prefix="$buf" 'index($0, prefix)==1 {found=$0} END {print found}' | \
                sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' 2>/dev/null)
            # Only suggest if it's longer than what's typed
            if [[ -n "$hist_match" && "$hist_match" != "$buf" && ${#hist_match} -gt ${#buf} ]]; then
                suggestion="$hist_match"
            fi
        fi

        # Source 3: BashTutor seen_commands (commands user has run before)
        if [[ -z "$suggestion" && -f "$BASHTUTOR_SEEN_COMMANDS_FILE" ]]; then
            local seen_match
            seen_match=$(grep "^${buf}" "$BASHTUTOR_SEEN_COMMANDS_FILE" 2>/dev/null | head -1)
            if [[ -n "$seen_match" && "$seen_match" != "$buf" ]]; then
                suggestion="$seen_match"
            fi
        fi

        if [[ -n "$suggestion" && "$suggestion" != "$buf" ]]; then
            # Show ghost text — the part after what's already typed
            if [[ "$suggestion" == "$buf"* ]]; then
                _BT_GHOST_TEXT="${suggestion#$buf}"
            else
                _BT_GHOST_TEXT=" → $suggestion"
            fi
            _BT_GHOST_ACTIVE=1

            # Display ghost text in grey after cursor using region_highlight
            local ghost_start=${#BUFFER}
            local ghost_end=$(( ghost_start + ${#_BT_GHOST_TEXT} ))

            # Temporarily append ghost text to buffer for display only
            BUFFER="${BUFFER}${_BT_GHOST_TEXT}"
            CURSOR=$ghost_start
            region_highlight=("$ghost_start $ghost_end fg=8,bold")
        else
            _BT_GHOST_TEXT=""
            _BT_GHOST_ACTIVE=0
            region_highlight=()
        fi

        zle -R
    }

    # Accept ghost suggestion with → (right arrow) or Tab
    function _bashtutor_ghost_accept() {
        if [[ $_BT_GHOST_ACTIVE -eq 1 && -n "$_BT_GHOST_TEXT" ]]; then
            # Ghost text is already in BUFFER — just move cursor to end
            CURSOR=${#BUFFER}
            region_highlight=()
            _BT_GHOST_TEXT=""
            _BT_GHOST_ACTIVE=0
            zle -R
        else
            # No ghost text — do normal forward-char or tab-complete
            if [[ "$WIDGET" == "bashtutor-ghost-accept-tab" ]]; then
                zle expand-or-complete
            else
                zle forward-char
            fi
        fi
    }

    # On any keypress — strip ghost text from buffer first, then update
    function _bashtutor_ghost_self_insert() {
        if [[ $_BT_GHOST_ACTIVE -eq 1 && -n "$_BT_GHOST_TEXT" ]]; then
            # Remove ghost text before inserting new character
            BUFFER="${BUFFER%${_BT_GHOST_TEXT}}"
            region_highlight=()
            _BT_GHOST_TEXT=""
            _BT_GHOST_ACTIVE=0
        fi
        zle self-insert
        _bashtutor_ghost_update
    }

    # Escape/delete clears ghost
    function _bashtutor_ghost_clear() {
        if [[ $_BT_GHOST_ACTIVE -eq 1 ]]; then
            BUFFER="${BUFFER%${_BT_GHOST_TEXT}}"
            region_highlight=()
            _BT_GHOST_TEXT=""
            _BT_GHOST_ACTIVE=0
            zle -R
        fi
        zle "$@" 2>/dev/null || true
    }

    # Register ZLE widgets
    zle -N bashtutor-ghost-update _bashtutor_ghost_update
    zle -N bashtutor-ghost-accept _bashtutor_ghost_accept
    zle -N bashtutor-ghost-accept-tab _bashtutor_ghost_accept
    zle -N bashtutor-ghost-self-insert _bashtutor_ghost_self_insert

    # Key bindings
    bindkey '^[[C' bashtutor-ghost-accept        # → right arrow accepts
    bindkey '^[OC' bashtutor-ghost-accept        # → right arrow (alternate)
    bindkey '^I'   bashtutor-ghost-accept-tab    # Tab accepts
    bindkey -M main '^[^[[C' forward-word        # Alt+→ still moves word

    # Hook into ZLE to update ghost on every keypress
    autoload -Uz add-zsh-hook
    add-zsh-hook zle-line-init _bashtutor_ghost_update 2>/dev/null || true

    # Override self-insert for printable chars
    # (We do this carefully to avoid breaking things)
    if zle -l self-insert &>/dev/null; then
        bindkey -M main ' '  bashtutor-ghost-self-insert
        # For letter keys — use zle-keymap-select hook approach instead
        # to avoid having to bind every character individually
        function zle-line-pre-redraw() {
            [[ -n "$KEYS" && "$KEYS" != $'\t' && "$KEYS" != $'\r' ]] && \
                _bashtutor_ghost_update 2>/dev/null || true
        }
        zle -N zle-line-pre-redraw
    fi
}

# Hook into zsh-autosuggestions if it's already loaded
function _bashtutor_hook_autosuggestions() {
    # Add BashTutor as an additional suggestion strategy
    # zsh-autosuggestions checks ZSH_AUTOSUGGEST_STRATEGY array in order
    if (( ${+ZSH_AUTOSUGGEST_STRATEGY} )); then
        # Prepend bashtutor strategy
        ZSH_AUTOSUGGEST_STRATEGY=(bashtutor_sequences "${ZSH_AUTOSUGGEST_STRATEGY[@]}")
    else
        ZSH_AUTOSUGGEST_STRATEGY=(bashtutor_sequences history completion)
    fi

    # Register our strategy function
    # zsh-autosuggestions calls _zsh_autosuggest_strategy_<name> with buffer as $1
    function _zsh_autosuggest_strategy_bashtutor_sequences() {
        local buf="$1"
        [[ -z "$buf" || ! -f "$BASHTUTOR_SEQUENCES_FILE" ]] && return

        local base_cmd
        base_cmd=$(echo "$buf" | awk '{print $1}')
        [[ -z "$base_cmd" ]] && return

        local next
        next=$(grep "^${base_cmd}|||" "$BASHTUTOR_SEQUENCES_FILE" 2>/dev/null | \
            awk -F'|||' '{print $2}' | sort | uniq -c | sort -rn | \
            awk 'NR==1 && $1>=2 {print $2}')

        [[ -n "$next" ]] && typeset -g suggestion="$next"
    }

    # Make it a soft grey (matches standard zsh-autosuggestions style)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="${ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE:-fg=8}"
}

# =============================================================================
# REGISTER HOOKS, KEYBINDINGS & ALIASES
# =============================================================================

autoload -Uz add-zsh-hook 2>/dev/null && {
    add-zsh-hook preexec bashtutor_preexec
    add-zsh-hook precmd bashtutor_precmd
    add-zsh-hook zshaddhistory bashtutor_zshaddhistory
}

# Safety check hook for destructive commands (fires before command runs)
function bashtutor_zshaddhistory() {
    local cmd="$1"
    _bashtutor_safety_check "$cmd"
    return 0  # always return 0 to allow the command to run
}

# Ctrl+B → explain last command
zle -N bashtutor_explain_last 2>/dev/null && \
    bindkey '^B' bashtutor_explain_last 2>/dev/null || true

# Aliases
alias bt='bashme'
alias qq='bashme'
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
    echo "${_BT_ORANGE}${_BT_BOLD}      ╔════════════════════════════════════════════════╗${_BT_RESET}"
    echo "${_BT_ORANGE}${_BT_BOLD}      ║  ██████╗  █████╗ ███████╗██╗  ██╗            ║${_BT_RESET}"
    echo "${_BT_ORANGE}${_BT_BOLD}      ║  ██╔══██╗██╔══██╗██╔════╝██║  ██║            ║${_BT_RESET}"
    echo "${_BT_ORANGE}${_BT_BOLD}      ║  ██████╔╝███████║███████╗███████║            ║${_BT_RESET}"
    echo "${_BT_ORANGE}${_BT_BOLD}      ║  ██╔══██╗██╔══██║╚════██║██╔══██║            ║${_BT_RESET}"
    echo "${_BT_ORANGE}${_BT_BOLD}      ║  ██████╔╝██║  ██║███████║██║  ██║            ║${_BT_RESET}"
    echo "${_BT_ORANGE}${_BT_BOLD}      ║  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝            ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ║  ████████╗██╗   ██╗████████╗ ██████╗ ██████╗  ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ║     ██╔══╝██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗ ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ║     ██║   ██║   ██║   ██║   ██║   ██║██████╔╝ ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ║     ██║   ██║   ██║   ██║   ██║   ██║██╔══██╗ ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ║     ██║   ╚██████╔╝   ██║   ╚██████╔╝██║  ██║ ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ║     ╚═╝    ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ║${_BT_RESET}"
    echo "${_BT_WHITE}${_BT_BOLD}      ║                                                ║${_BT_RESET}"
    echo "${_BT_WHITE}${_BT_BOLD}      ║        Ba\$h Tutor  ~  bash for humans          ║${_BT_RESET}"
    echo "${_BT_GREEN}${_BT_BOLD}      ╚════════════════════════════════════════════════╝${_BT_RESET}"
    echo ""
    echo "      ${_BT_WHITE}v${BASHTUTOR_VERSION}${_BT_RESET}  ${_BT_ORANGE}🤖 Claude Edition${_BT_RESET}"
    echo ""

    if [[ "$BASHTUTOR_AI_AVAILABLE" == "1" ]]; then
        echo "      ${_BT_GREEN}✅ Claude API ready${_BT_RESET}   ${_BT_GREEN}👻 Ghost autocomplete on${_BT_RESET}"
    else
        echo "      ${_BT_YELLOW}⚠️  No API key — running in local mode${_BT_RESET}"
        echo "      ${_BT_GREEN}👻 Ghost autocomplete on${_BT_RESET}"
    fi

    echo ""
    echo "      ${_BT_ORANGE}qq${_BT_RESET} plain english   ${_BT_GREEN}Ctrl+B${_BT_RESET} explain last   ${_BT_WHITE}cmd + what?${_BT_RESET} explain anything"
    echo ""
    export BASHTUTOR_WELCOME_SHOWN="1"
fi
