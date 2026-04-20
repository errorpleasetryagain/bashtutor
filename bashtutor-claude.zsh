#!/usr/bin/env zsh
# BashTutor Claude — AI backend: Anthropic Claude API
# qq <question>  |  bt <question>  |  bashme <question>
# Requires: ANTHROPIC_API_KEY env var
# Falls back to local patterns if unavailable

[[ -n "${BASHTUTOR_LOADED}" ]] && return 0
export BASHTUTOR_LOADED=1
export BASHTUTOR_VERSION="2.0.0"
export BASHTUTOR_BACKEND="claude"

# ── dirs & config ─────────────────────────────────────────────────────────────
export BASHTUTOR_DIR="${HOME}/.bashtutor"
export BASHTUTOR_CONFIG="${BASHTUTOR_DIR}/config"
export BASHTUTOR_LEVEL="beginner"
export _BT_LAST_CMD=""
export BASHTUTOR_MODEL="${BASHTUTOR_MODEL:-claude-haiku-4-5-20251001}"

mkdir -p "$BASHTUTOR_DIR" 2>/dev/null
[[ -f "$BASHTUTOR_CONFIG" ]] && source "$BASHTUTOR_CONFIG" 2>/dev/null
[[ -z "$BASHTUTOR_LEVEL" ]] && BASHTUTOR_LEVEL="beginner"

# ── colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    _OR=$(printf '\033[38;5;202m')   # orange — commands, prompts
    _DG=$(printf '\033[38;5;22m')    # dark green — success, level
    _GH=$(printf '\033[38;5;240m')   # grey — ghost text
    _CY=$(printf '\033[0;36m')       # cyan — notes, explanations
    _RE=$(printf '\033[0;31m')       # red — warnings
    _B=$(printf '\033[1m')           # bold
    _R=$(printf '\033[0m')           # reset
else
    _OR="" _DG="" _GH="" _CY="" _RE="" _B="" _R=""
fi

_bt_cmd()  { printf "${_OR}${_B}  %s${_R}\n" "$*"; }
_bt_note() { printf "${_CY}  %s${_R}\n" "$*"; }
_bt_warn() { printf "${_RE}  ⚠  %s${_R}\n" "$*"; }
_bt_err()  { printf "${_RE}  ✗ %s${_R}\n" "$*" >&2; }

# ── boot line ─────────────────────────────────────────────────────────────────
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    printf "${_OR}${_B}❯ BashTutor${_R} ${_DG}[claude·%s]${_R}  type ${_OR}qq help${_R} to start\n" "$BASHTUTOR_LEVEL"
else
    printf "${_OR}${_B}❯ BashTutor${_R} ${_RE}[local·%s]${_R}  set ANTHROPIC_API_KEY for AI\n" "$BASHTUTOR_LEVEL"
fi

# ── fish-style predictive ghost text ─────────────────────────────────────────
typeset -g _BT_GHOST=""

function _bt_ghost_update() {
    local prefix="$BUFFER"
    _BT_GHOST=""
    [[ ${#prefix} -lt 1 ]] && { zle -R; return; }
    local match
    match=$(fc -lnr 1 2>/dev/null | grep -m1 "^${(q)prefix}" | sed 's/^[0-9 \t]*//')
    [[ -n "$match" && "$match" != "$prefix" ]] && _BT_GHOST="${match#$prefix}"
    zle -R
}

function _bt_ghost_render() {
    region_highlight=()
    [[ -z "$_BT_GHOST" ]] && return
    local ghost_start=${#BUFFER}
    local ghost_end=$(( ghost_start + ${#_BT_GHOST} ))
    POSTDISPLAY="$_BT_GHOST"
    region_highlight+=("$ghost_start $ghost_end fg=240,bold")
}

function _bt_ghost_accept() {
    [[ -z "$_BT_GHOST" ]] && { zle forward-char; return; }
    BUFFER="${BUFFER}${_BT_GHOST}"
    CURSOR=${#BUFFER}
    POSTDISPLAY=""
    _BT_GHOST=""
    zle -R
}

zle -N _bt_ghost_update
zle -N _bt_ghost_render
zle -N _bt_ghost_accept

autoload -Uz add-zle-hook-widget 2>/dev/null
add-zle-hook-widget line-pre-redraw _bt_ghost_render
add-zle-hook-widget keymap-select _bt_ghost_update

bindkey '^[[C' _bt_ghost_accept   # right arrow accepts
bindkey '^I' _bt_ghost_accept     # Tab accepts

function _bt_self_insert_ghost() {
    zle .self-insert
    _bt_ghost_update
}
zle -N self-insert _bt_self_insert_ghost

function _bt_ghost_clear() {
    POSTDISPLAY=""
    _BT_GHOST=""
}
zle -N _bt_ghost_clear
add-zle-hook-widget line-finish _bt_ghost_clear

# ── ascii cat reactions ───────────────────────────────────────────────────────
function _bt_cat_happy() {
    [[ $(tput cols 2>/dev/null) -gt 60 ]] || return
    printf "${_OR} /\\_/\\ \n${_OR}( o.o )\n${_OR} > ^ < ${_R}\n"
}
function _bt_cat_thinking() {
    [[ $(tput cols 2>/dev/null) -gt 60 ]] || return
    printf "${_OR} /\\_/\\ \n${_OR}( -.- )\n${_OR} > ? < ${_R}\n"
}
function _bt_cat_warn() {
    [[ $(tput cols 2>/dev/null) -gt 60 ]] || return
    printf "${_OR} /\\_/\\ \n${_OR}( o_o )\n${_OR} > ! < ${_R}\n"
}

# ── destructive command warning ───────────────────────────────────────────────
function _bt_preexec() {
    POSTDISPLAY=""
    _BT_GHOST=""
    export _BT_LAST_CMD="$1"
    local cmd="$1"
    # Normalise for matching: strip leading spaces, collapse runs of spaces
    local cmd_n="${cmd## }"
    cmd_n="${cmd_n//  / }"
    case "$cmd_n" in
        rm\ -rf*|rm\ -fr*|dd\ if=*|mkfs*|shred\ *|chmod\ -R\ 777*)
            _bt_cat_warn
            printf "${_RE}${_B}  ⚠  Destructive: %s${_R}\n  Continue? [y/N] " "$cmd"
            read -r _bt_ans
            [[ "$_bt_ans" != [yY] ]] && return 1
            ;;
    esac
    return 0
}

# ── level-aware system prompt ─────────────────────────────────────────────────
function _bt_system_prompt() {
    case "${BASHTUTOR_LEVEL:-beginner}" in
        beginner)
            echo "You are a bash teacher for beginners. Given a plain-English request, respond with EXACTLY two lines:
COMMAND: <the exact bash/zsh command>
EXPLANATION: <one plain-English sentence explaining what it does and why, avoiding jargon>
No markdown, no extra lines, no code blocks." ;;
        intermediate)
            echo "You are a bash assistant. Given a request, respond with EXACTLY two lines:
COMMAND: <the exact bash/zsh command>
NOTE: <a short technical note about flags or behaviour — one line>
No markdown, no extra lines." ;;
        expert)
            echo "You are a bash assistant. Given a request, respond with EXACTLY one line:
COMMAND: <the exact bash/zsh command>
Nothing else." ;;
    esac
}

# ── call Claude API ───────────────────────────────────────────────────────────
function _bt_claude_call() {
    local query="$1"
    [[ -z "${ANTHROPIC_API_KEY:-}" ]] && return 1

    local system_prompt
    system_prompt=$(_bt_system_prompt)

    local escaped_query escaped_system
    escaped_query=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$query" 2>/dev/null) || return 1
    escaped_system=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$system_prompt" 2>/dev/null) || return 1

    local payload
    payload=$(printf '{"model":"%s","max_tokens":256,"system":%s,"messages":[{"role":"user","content":%s}]}' \
        "$BASHTUTOR_MODEL" "$escaped_system" "$escaped_query")

    # Pass API key via curl --config stdin so it never appears in ps aux
    local response
    response=$(printf 'header = "x-api-key: %s"\nheader = "anthropic-version: 2023-06-01"\nheader = "content-type: application/json"\n' \
        "$ANTHROPIC_API_KEY" | \
        curl -sf --config - --request POST \
            --data "$payload" \
            "https://api.anthropic.com/v1/messages" 2>/dev/null) || return 1

    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    print(d['content'][0]['text'].strip())
except:
    sys.exit(1)
" "$response" 2>/dev/null
}

# ── local fallback pattern lookup ─────────────────────────────────────────────
# Compact fallback covering the most common requests
function _bt_local_lookup() {
    local q="${1:l}"
    _BT_CMD="" _BT_NOTE_B="" _BT_NOTE_I=""
    case "$q" in
        *list*file*|*show*file*|*what*here*) _BT_CMD="ls -la"; _BT_NOTE_B="Lists all files including hidden"; _BT_NOTE_I="# -l=details -a=hidden" ;;
        *creat*folder*|*mkdir*) _BT_CMD="mkdir -p folder"; _BT_NOTE_B="Creates a folder"; _BT_NOTE_I="# -p=ok if exists" ;;
        *delet*folder*|*remov*folder*) _BT_CMD="rm -rf folder"; _BT_NOTE_B="Deletes folder and contents — no undo!"; _BT_NOTE_I="# CAREFUL" ;;
        *delet*file*|*remov*file*) _BT_CMD="rm filename"; _BT_NOTE_B="Deletes a file permanently"; _BT_NOTE_I="# no recycle bin" ;;
        *copy*file*) _BT_CMD="cp source dest"; _BT_NOTE_B="Copies a file"; _BT_NOTE_I="# -r for folders" ;;
        *move*|*renam*) _BT_CMD="mv old new"; _BT_NOTE_B="Moves or renames a file"; _BT_NOTE_I="# same command" ;;
        *search*text*|*find*text*|*grep*) _BT_CMD="grep -r 'pattern' ."; _BT_NOTE_B="Searches for text in all files"; _BT_NOTE_I="# -i=case-insensitive -n=line numbers" ;;
        *find*file*) _BT_CMD="find . -name '*.txt'"; _BT_NOTE_B="Finds files by name"; _BT_NOTE_I="# * is wildcard" ;;
        *disk*space*|*free*space*) _BT_CMD="df -h"; _BT_NOTE_B="Shows free disk space"; _BT_NOTE_I="# -h=human readable" ;;
        *folder*size*|*du*) _BT_CMD="du -sh *"; _BT_NOTE_B="Shows folder sizes"; _BT_NOTE_I="# -s=summary -h=human" ;;
        *compress*|*archive*|*tar*) _BT_CMD="tar -czf out.tar.gz folder/"; _BT_NOTE_B="Compresses a folder"; _BT_NOTE_I="# -c=create -z=gzip" ;;
        *extract*|*unpack*) _BT_CMD="tar -xzf archive.tar.gz"; _BT_NOTE_B="Extracts an archive"; _BT_NOTE_I="# -x=extract -z=gzip" ;;
        *permiss*|*chmod*) _BT_CMD="chmod 755 file"; _BT_NOTE_B="Sets read/write/execute permissions"; _BT_NOTE_I="# 7=all 5=read+exec" ;;
        *git*status*|*what*changed*) _BT_CMD="git status"; _BT_NOTE_B="Shows changed files"; _BT_NOTE_I="# -s=short" ;;
        *git*commit*) _BT_CMD="git commit -m 'message'"; _BT_NOTE_B="Saves staged changes"; _BT_NOTE_I="# -am=stage+commit" ;;
        *git*push*) _BT_CMD="git push"; _BT_NOTE_B="Uploads commits to remote"; _BT_NOTE_I="# -u origin main to set upstream" ;;
        *git*pull*) _BT_CMD="git pull"; _BT_NOTE_B="Downloads latest changes"; _BT_NOTE_I="# fetch + merge" ;;
        *git*branch*) _BT_CMD="git checkout -b branch"; _BT_NOTE_B="Creates and switches to new branch"; _BT_NOTE_I="# git branch to list" ;;
        *port*|*listen*) _BT_CMD="lsof -i -P | grep LISTEN"; _BT_NOTE_B="Shows open ports"; _BT_NOTE_I="# -P=port numbers" ;;
        *process*|*running*) _BT_CMD="ps aux"; _BT_NOTE_B="Lists all running processes"; _BT_NOTE_I="# | grep name to filter" ;;
        *kill*process*) _BT_CMD="pkill -f name"; _BT_NOTE_B="Stops a process by name"; _BT_NOTE_I="# kill PID for by ID" ;;
        *download*|*curl*) _BT_CMD="curl -O https://url/file"; _BT_NOTE_B="Downloads a file"; _BT_NOTE_I="# -L=follow redirects" ;;
        *ssh*|*remote*server*) _BT_CMD="ssh user@host"; _BT_NOTE_B="Connects to a remote server"; _BT_NOTE_I="# -i=key file" ;;
        *pipe*|*chain*) _BT_CMD="cmd1 | cmd2"; _BT_NOTE_B="Sends output of cmd1 into cmd2"; _BT_NOTE_I="# stdout → stdin" ;;
        *save*output*|*redirect*) _BT_CMD="command > file.txt"; _BT_NOTE_B="Saves output to a file"; _BT_NOTE_I="# >> to append" ;;
        *for*loop*) _BT_CMD='for f in *; do echo "$f"; done'; _BT_NOTE_B="Loops over items"; _BT_NOTE_I="# $f = current item" ;;
        *alias*) _BT_CMD="alias ll='ls -la'"; _BT_NOTE_B="Creates a command shortcut"; _BT_NOTE_I="# add to ~/.zshrc to persist" ;;
        *reload*config*|*source*zshrc*) _BT_CMD="source ~/.zshrc"; _BT_NOTE_B="Reloads your shell config"; _BT_NOTE_I="# . ~/.zshrc also works" ;;
        *) return 1 ;;
    esac
    return 0
}

# ── display Claude response ───────────────────────────────────────────────────
function _bt_display_ai() {
    local raw="$1"
    local level="${BASHTUTOR_LEVEL:-beginner}"
    local cmd note

    cmd=$(echo "$raw" | grep '^COMMAND:' | sed 's/^COMMAND: *//')
    [[ -z "$cmd" ]] && { _bt_err "Unexpected response format"; echo "$raw"; return 1; }

    _bt_cat_happy
    echo ""
    case "$level" in
        beginner)
            note=$(echo "$raw" | grep '^EXPLANATION:' | sed 's/^EXPLANATION: *//')
            [[ -n "$note" ]] && _bt_note "$note"
            _bt_cmd "$cmd"
            ;;
        intermediate)
            _bt_cmd "$cmd"
            note=$(echo "$raw" | grep '^NOTE:' | sed 's/^NOTE: *//')
            [[ -n "$note" ]] && _bt_note "$note"
            ;;
        expert)
            _bt_cmd "$cmd"
            ;;
    esac
    echo ""
    printf "  Run it? [y/N] "
    read -r _bt_run_ans
    [[ "$_bt_run_ans" == [yY] ]] && eval "$cmd"
}

# ── display local response ────────────────────────────────────────────────────
function _bt_display_local() {
    local level="${BASHTUTOR_LEVEL:-beginner}"
    _bt_cat_happy
    echo ""
    case "$level" in
        beginner)
            [[ -n "$_BT_NOTE_B" ]] && _bt_note "$_BT_NOTE_B"
            _bt_cmd "$_BT_CMD"
            ;;
        intermediate)
            _bt_cmd "$_BT_CMD"
            [[ -n "$_BT_NOTE_I" ]] && _bt_note "$_BT_NOTE_I"
            ;;
        expert)
            _bt_cmd "$_BT_CMD"
            ;;
    esac
    echo ""
    printf "  Run it? [y/N] "
    read -r _bt_run_ans
    [[ "$_bt_run_ans" == [yY] ]] && eval "$_BT_CMD"
}

# ── qq ────────────────────────────────────────────────────────────────────────
function qq() {
    local query="$*"

    if [[ "$1" == "level" && -n "$2" ]]; then
        case "$2" in
            beginner|intermediate|expert)
                BASHTUTOR_LEVEL="$2"
                echo "BASHTUTOR_LEVEL=$2" > "$BASHTUTOR_CONFIG"
                printf "${_DG}  Level: %s${_R}\n" "$2"
                return 0 ;;
            *)
                _bt_err "Level must be: beginner, intermediate, or expert"
                return 1 ;;
        esac
    fi

    [[ "$query" == "help" || -z "$query" ]] && { _bt_help; return 0; }

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        _bt_cat_thinking
        printf "${_CY}  Asking Claude...${_R}\n"
        local ai_response
        ai_response=$(_bt_claude_call "$query")
        if [[ -n "$ai_response" ]]; then
            _bt_display_ai "$ai_response"
            return $?
        fi
        _bt_warn "Claude unavailable — using local patterns"
    fi

    _bt_local_lookup "$query" || {
        _bt_cat_thinking
        printf "\n${_CY}  Hmm, not sure about '${_OR}%s${_CY}'.${_R}\n" "$query"
        printf "${_CY}  Try rephrasing — for example:${_R}\n"
        printf "${_GH}    • use a verb + object  (e.g. 'compress folder', 'delete file')${_R}\n"
        printf "${_GH}    • name the tool        (e.g. 'git undo last commit')${_R}\n"
        printf "${_GH}    • describe the goal    (e.g. 'show open ports', 'find large files')${_R}\n"
        printf "${_CY}  Or run: ${_OR}man <command>${_CY} for manual pages.${_R}\n\n"
        return 1
    }
    _bt_display_local
}

# ── explain last command (Ctrl+B) ─────────────────────────────────────────────
typeset -gA BASHTUTOR_EXPLANATIONS
BASHTUTOR_EXPLANATIONS=(
    ls "Listed files and directories" ll "Listed files with details"
    la "Listed all files including hidden" cd "Changed directory"
    pwd "Showed current directory" mkdir "Created a directory"
    rm "Deleted files or directories" cp "Copied files"
    mv "Moved or renamed files" touch "Created or updated a file"
    cat "Printed file contents" less "Opened file for scrolling"
    head "Showed start of file" tail "Showed end of file"
    grep "Searched for text patterns" find "Found files by criteria"
    chmod "Changed file permissions" chown "Changed file ownership"
    sudo "Ran with admin privileges" ssh "Connected to remote server"
    curl "Fetched URL data" wget "Downloaded a file"
    tar "Archived or extracted files" git "Ran git command"
    npm "Ran npm command" pip3 "Installed Python package"
    docker "Ran Docker command" brew "Ran Homebrew"
    ps "Listed running processes" kill "Stopped a process"
    df "Showed disk space" du "Showed directory sizes"
    ping "Tested network connectivity" export "Set environment variable"
    source "Reloaded shell config" history "Showed command history"
    which "Found command location" date "Showed date and time"
    whoami "Showed username" uname "Showed system info"
    sed "Edited text with patterns" sort "Sorted lines"
    rsync "Synced files between locations" nano "Opened file in editor"
)

function _bt_explain_last() {
    local cmd="${_BT_LAST_CMD:-$(fc -ln -1 2>/dev/null | sed 's/^ *//')}"
    if [[ -z "$cmd" ]]; then
        printf "\n${_RE}  No previous command${_R}\n"
        zle redisplay 2>/dev/null
        return
    fi
    local base="${cmd%% *}"
    local expl="${BASHTUTOR_EXPLANATIONS[$base]}"

    if [[ -z "$expl" && -n "${ANTHROPIC_API_KEY:-}" && "${BASHTUTOR_LEVEL}" != "expert" ]]; then
        expl=$(echo "Explain in one sentence what this shell command did: $cmd" | \
            _bt_claude_call "Explain in one sentence what this shell command did: $cmd" 2>/dev/null | \
            grep -v '^COMMAND:' | head -1)
    fi
    [[ -z "$expl" ]] && expl="Ran: $base"

    printf "\n${_CY}  ❯ %s${_R}\n${_OR}  %s${_R}\n\n" "$cmd" "$expl"
    zle redisplay 2>/dev/null
}
zle -N _bt_explain_last
bindkey '^B' _bt_explain_last

# ── help screen ───────────────────────────────────────────────────────────────
function _bt_help() {
    local ai_status
    [[ -n "${ANTHROPIC_API_KEY:-}" ]] && ai_status="${_DG}claude${_R}" || ai_status="${_RE}local fallback${_R}"
    printf "\n${_OR}${_B}❯ BashTutor${_R}  Level: ${_DG}%s${_R}  AI: %s\n\n" "$BASHTUTOR_LEVEL" "$ai_status"
    printf "${_B}Usage:${_R}\n"
    printf "  qq <question>           ask in plain English\n"
    printf "  bt <question>           same, shorter alias\n"
    printf "  bashme <question>       same\n"
    printf "  qq level beginner       set response level\n"
    printf "  qq level intermediate\n"
    printf "  qq level expert\n"
    printf "\n${_B}Keybindings:${_R}\n"
    printf "  Ctrl+B                  explain last command\n"
    printf "  Right arrow / Tab       accept ghost suggestion\n"
    printf "\n${_B}Examples:${_R}\n"
    printf "  qq list all files including hidden\n"
    printf "  qq find files modified today\n"
    printf "  qq compress a folder to tar.gz\n"
    printf "  qq git save changes and push\n"
    printf "  qq run a script in the background\n"
    printf "  qq show open ports\n"
    printf "  qq docker list running containers\n"
    printf "  qq kill process on port 3000\n"
    printf "  qq search text in all files recursively\n"
    printf "  qq create a python virtual environment\n"
    printf "  qq ssh tunnel to remote server\n"
    printf "  qq git undo last commit\n"
    printf "  qq download a file from url\n"
    printf "\n${_B}Levels:${_R}\n"
    printf "  ${_DG}beginner${_R}      plain English + command\n"
    printf "  ${_DG}intermediate${_R}  command + brief note\n"
    printf "  ${_DG}expert${_R}        command only\n\n"
}

# ── hooks & aliases ───────────────────────────────────────────────────────────
autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook preexec _bt_preexec

alias bt='qq'
alias bashme='qq'
