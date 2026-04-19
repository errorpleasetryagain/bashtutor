#!/usr/bin/env bash
# BashTutor Installer
# Installs BashTutor as a permanent macOS zsh OS-level plugin
# Version: 1.4.0
#
# Works two ways:
#   1. Run directly from the repo folder: bash install.sh
#   2. Run via curl (self-contained):
#      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)"
#
# Usage:
#   bash install.sh              # install OpenClaw edition (default)
#   bash install.sh --claude     # install Claude API edition
#   bash install.sh --standalone # install Standalone edition (no API key needed)
#   bash install.sh --uninstall  # remove everything

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_VERSION="1.4.0"
readonly BASHTUTOR_DIR="${HOME}/.bashtutor"
readonly REPO_DIR="${HOME}/bashtutor-prod"
readonly ZSHRC="${HOME}/.zshrc"
readonly ZSHRC_BACKUP="${HOME}/.zshrc.bashtutor.bak.$(date +%Y%m%d%H%M%S)"
readonly SOURCE_MARKER="# BashTutor — loaded at OS level (zsh plugin)"
readonly GITHUB_RAW="https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main"
readonly GITHUB_REPO="https://github.com/errorpleasetryagain/bashtutor.git"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to OpenClaw edition
EDITION="openclaw"
PLUGIN_FILE=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --claude)
            EDITION="claude"
            ;;
        --standalone)
            EDITION="standalone"
            ;;
        --uninstall)
            EDITION="uninstall"
            ;;
    esac
done

# =============================================================================
# COLOURS
# =============================================================================

ORANGE='\033[38;5;202m'
GREEN='\033[38;5;22m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}${BOLD}✅ $*${NC}"; }
info() { echo -e "${CYAN}🐚 $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()  { echo -e "${RED}❌ $*${NC}" >&2; }
die()  { err "$1"; exit 1; }

# =============================================================================
# CURL MODE — download files if not running from repo folder
# =============================================================================

is_curl_install() {
    # If the plugin file doesn't exist next to this script, we're running via curl
    local check_file="${SCRIPT_DIR}/bashtutor-openclaw.zsh"
    [[ ! -f "$check_file" ]]
}

download_files() {
    info "Downloading BashTutor from GitHub..."

    # Try git clone first (cleanest)
    if command -v git &>/dev/null; then
        if [[ -d "$REPO_DIR/.git" ]]; then
            info "Updating existing download..."
            git -C "$REPO_DIR" fetch origin 2>/dev/null && \
                git -C "$REPO_DIR" reset --hard origin/main 2>/dev/null && \
                ok "Updated to latest version"
        else
            rm -rf "$REPO_DIR" 2>/dev/null || true
            git clone --depth 1 "$GITHUB_REPO" "$REPO_DIR" 2>/dev/null && \
                ok "Downloaded BashTutor"
        fi
        SCRIPT_DIR="$REPO_DIR"
        return 0
    fi

    # Fallback: download files directly via curl (git is not required)
    info "git is not installed — downloading files directly with curl instead..."
    if ! command -v curl &>/dev/null; then
        die "Neither git nor curl is installed. Please install one of them and try again.
  macOS:  brew install git
  Ubuntu: sudo apt install git
  Fedora: sudo dnf install git"
    fi
    mkdir -p "$REPO_DIR"
    curl -fsSL "${GITHUB_RAW}/bashtutor-openclaw.zsh"  -o "${REPO_DIR}/bashtutor-openclaw.zsh"  || die "Download failed. Check your internet connection and try again."
    curl -fsSL "${GITHUB_RAW}/bashtutor-claude.zsh"    -o "${REPO_DIR}/bashtutor-claude.zsh"    || die "Download failed. Check your internet connection and try again."
    curl -fsSL "${GITHUB_RAW}/bashtutor-standalone.zsh" -o "${REPO_DIR}/bashtutor-standalone.zsh" || die "Download failed. Check your internet connection and try again."
    ok "Downloaded BashTutor"
    SCRIPT_DIR="$REPO_DIR"
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall() {
    info "Uninstalling BashTutor..."

    # Remove ~/.bashtutor/ directory
    if [[ -d "$BASHTUTOR_DIR" ]]; then
        rm -rf "$BASHTUTOR_DIR"
        ok "Removed ~/.bashtutor/ directory"
    else
        warn "~/.bashtutor/ was not found — nothing to remove there"
    fi

    # Remove all BashTutor lines from ~/.zshrc
    if [[ -f "$ZSHRC" ]]; then
        if grep -qF "$SOURCE_MARKER" "$ZSHRC" 2>/dev/null || \
           grep -q "source.*\.bashtutor/bashtutor\.zsh" "$ZSHRC" 2>/dev/null; then
            cp "$ZSHRC" "${ZSHRC}.uninstall.bak.$(date +%Y%m%d%H%M%S)"
            # Remove the marker line, the source line, and any blank line left before them
            local _tmp; _tmp=$(mktemp)
            grep -v "$SOURCE_MARKER" "$ZSHRC" \
                | grep -v "source.*\.bashtutor/bashtutor\.zsh" \
                > "$_tmp" && mv "$_tmp" "$ZSHRC"
            ok "Removed BashTutor lines from ~/.zshrc"
        else
            warn "No BashTutor lines found in ~/.zshrc — nothing to remove there"
        fi
    else
        warn "~/.zshrc not found — nothing to remove there"
    fi

    echo ""
    ok "BashTutor has been removed. Open a new terminal window to finish."
    echo ""
    exit 0
}

# =============================================================================
# CHECKS
# =============================================================================

check_zsh() {
    # Check zsh is installed before anything else
    if ! command -v zsh &>/dev/null; then
        err "zsh is not installed on this system."
        echo ""
        echo "  BashTutor is a zsh plugin and requires zsh to work."
        echo "  Install zsh using one of these commands:"
        echo ""
        echo "    macOS:            brew install zsh"
        echo "    Ubuntu / Debian:  sudo apt install zsh"
        echo "    Fedora / RHEL:    sudo dnf install zsh"
        echo "    Arch Linux:       sudo pacman -S zsh"
        echo ""
        echo "  After installing zsh, re-run this installer."
        echo ""
        exit 1
    fi
}

check_platform() {
    info "Checking your system..."

    [[ "$(uname -s)" == "Darwin" ]] || die "BashTutor only supports macOS right now."

    # Check current shell — warn if not zsh but don't block
    local shell_name="${SHELL##*/}"
    if [[ "$shell_name" != "zsh" ]]; then
        warn "Your default shell is ${SHELL} — BashTutor needs zsh."
        echo ""
        echo "  Switch to zsh with:"
        echo -e "  ${CYAN}chsh -s \$(which zsh)${NC}"
        echo "  Then open a new terminal and re-run this installer."
        echo ""
        die "Please switch to zsh first, then re-run this installer."
    fi

    local zsh_version
    zsh_version=$(zsh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    ok "macOS with zsh ${zsh_version} — good to go"
}

check_plugin_file() {
    if [[ "$EDITION" == "claude" ]]; then
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-claude.zsh"
    elif [[ "$EDITION" == "standalone" ]]; then
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-standalone.zsh"
    else
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-openclaw.zsh"
    fi

    # Fall back to generic name
    if [[ ! -f "$PLUGIN_FILE" ]]; then
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor.zsh"
    fi

    [[ -f "$PLUGIN_FILE" ]] || die "Plugin file not found. Try re-running the installer."

    zsh -n "$PLUGIN_FILE" 2>/dev/null || die "The downloaded plugin file has a syntax error — try re-running the installer to get a fresh copy."
    ok "Plugin file found and valid"
}

check_ai() {
    if [[ "$EDITION" == "openclaw" ]]; then
        if command -v openclaw &>/dev/null; then
            ok "OpenClaw detected — AI features ready"
        else
            warn "OpenClaw not found — BashTutor will use local patterns until you install it"
        fi
    elif [[ "$EDITION" == "claude" ]]; then
        if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
            ok "ANTHROPIC_API_KEY found — Claude AI ready"
        else
            warn "ANTHROPIC_API_KEY not set — add it to enable AI:"
            echo ""
            echo -e "  ${CYAN}echo 'export ANTHROPIC_API_KEY=\"sk-ant-...\"' >> ~/.zshrc${NC}"
            echo -e "  Get a free key at: ${CYAN}https://console.anthropic.com${NC}"
            echo ""
        fi
    elif [[ "$EDITION" == "standalone" ]]; then
        ok "Standalone edition — no API key needed"
    fi
}

# =============================================================================
# INSTALL
# =============================================================================

create_dirs() {
    info "Setting up ~/.bashtutor/ ..."
    mkdir -p "${BASHTUTOR_DIR}/cache"
    chmod 700 "$BASHTUTOR_DIR"
    ok "Created ~/.bashtutor/"
}

copy_plugin() {
    info "Installing plugin..."
    cp "$PLUGIN_FILE" "${BASHTUTOR_DIR}/bashtutor.zsh"
    chmod 644 "${BASHTUTOR_DIR}/bashtutor.zsh"
    ok "Installed to ~/.bashtutor/bashtutor.zsh"
}

create_config() {
    local config="${BASHTUTOR_DIR}/config"
    if [[ -f "$config" ]]; then
        warn "Config already exists — keeping your settings"
        return
    fi

    cat > "$config" << 'EOF'
# BashTutor Configuration
# Edit these to change how BashTutor behaves

# Auto-explain commands? (0 = off, 1 = on — only explains new/failed commands)
BASHTUTOR_AUTO_EXPLAIN=0

# Remember AI answers for how long? (hours)
BASHTUTOR_CACHE_TTL=24

# How many commands to keep in history
BASHTUTOR_MAX_HISTORY=1000

# Suggest next commands based on your habits? (0 = off, 1 = on)
BASHTUTOR_SMART_SUGGEST=0

# Show debug info? (0 = off, 1 = on)
BASHTUTOR_VERBOSE=0
EOF
    ok "Created default config at ~/.bashtutor/config"
}

wire_into_zshrc() {
    [[ -f "$ZSHRC" ]] || touch "$ZSHRC"

    if grep -qF "$SOURCE_MARKER" "$ZSHRC" 2>/dev/null; then
        # Already wired in — updating
        info "Updating shell configuration..."
        local _tmp; _tmp=$(mktemp)
        grep -v "$SOURCE_MARKER" "$ZSHRC" | grep -v "source.*\.bashtutor/bashtutor\.zsh" > "$_tmp" && \
            mv "$_tmp" "$ZSHRC"
    else
        info "Wiring into your shell..."
        cp "$ZSHRC" "$ZSHRC_BACKUP"
        info "Backed up ~/.zshrc to ${ZSHRC_BACKUP##*/}"
    fi

    cat >> "$ZSHRC" << EOF

${SOURCE_MARKER}
[[ -f "\${HOME}/.bashtutor/bashtutor.zsh" ]] && source "\${HOME}/.bashtutor/bashtutor.zsh"
EOF

    ok "Added to ~/.zshrc — BashTutor will load every time a terminal opens"
}

post_install_check() {
    local target="${BASHTUTOR_DIR}/bashtutor.zsh"
    if [[ ! -f "$target" ]]; then
        warn "Post-install check skipped — plugin file not found at ${target}"
        return
    fi

    local syntax_output
    syntax_output=$(zsh -n "$target" 2>&1)
    if [[ $? -eq 0 ]]; then
        ok "Syntax check passed — plugin loaded without errors"
    else
        err "Syntax check failed: ${syntax_output}"
        echo ""
        echo "  The plugin was installed but may not work correctly."
        echo "  Try re-running the installer to get a fresh copy, or report this"
        echo "  at: https://github.com/errorpleasetryagain/bashtutor/issues"
        echo ""
    fi
}

# =============================================================================
# EDITION DISPLAY NAME
# =============================================================================

edition_display_name() {
    case "$EDITION" in
        claude)     echo "Claude API" ;;
        standalone) echo "Standalone" ;;
        *)          echo "OpenClaw"   ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    [[ "$EDITION" == "uninstall" ]] && uninstall

    # Check zsh exists before anything else
    check_zsh

    # Detect update vs fresh install for messaging
    local is_update=0
    if [[ -f "${BASHTUTOR_DIR}/bashtutor.zsh" ]]; then
        is_update=1
    fi

    local edition_name
    edition_name=$(edition_display_name)

    echo ""
    echo -e "${ORANGE}${BOLD}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${ORANGE}${BOLD}  ║   Ba\$h Tutor  ~  bash for humans        ║${NC}"
    echo -e "${GREEN}${BOLD}  ║   Installer v${SCRIPT_VERSION}                        ║${NC}"
    echo -e "${GREEN}${BOLD}  ╚══════════════════════════════════════════╝${NC}"
    echo ""
    if [[ $is_update -eq 1 ]]; then
        echo -e "${CYAN}  Updating BashTutor...${NC}"
    else
        echo -e "${CYAN}  Installing at OS level — loads in every terminal automatically${NC}"
    fi
    echo -e "${WHITE}  Edition: ${BOLD}${edition_name}${NC}"
    echo ""

    # If running via curl, download files first
    if is_curl_install; then
        download_files
    fi

    check_platform
    check_plugin_file
    check_ai
    create_dirs
    copy_plugin
    create_config
    wire_into_zshrc

    # Post-install syntax check
    post_install_check

    echo ""
    echo -e "${ORANGE}${BOLD}  ╔══════════════════════════════════════════╗${NC}"
    if [[ $is_update -eq 1 ]]; then
        echo -e "${ORANGE}${BOLD}  ║   🎉  BashTutor updated!                 ║${NC}"
    else
        echo -e "${ORANGE}${BOLD}  ║   🎉  BashTutor is installed!            ║${NC}"
    fi
    echo -e "${GREEN}${BOLD}  ║   Edition: ${edition_name}$(printf '%*s' $((28 - ${#edition_name})) '')║${NC}"
    echo -e "${GREEN}${BOLD}  ╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${ORANGE}${BOLD}  ┌──────────────────────────────────────────┐${NC}"
    echo -e "${ORANGE}${BOLD}  │  ► Open a NEW terminal window to start   │${NC}"
    echo -e "${ORANGE}${BOLD}  │    (or run:  source ~/.zshrc )            │${NC}"
    echo -e "${ORANGE}${BOLD}  └──────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}  ── Then try these ───────────────────────────${NC}"
    echo ""
    echo -e "  ${ORANGE}${BOLD}qq${NC} show files modified today"
    echo -e "  ${ORANGE}${BOLD}qq${NC} find all pdfs in downloads"
    echo -e "  ${ORANGE}${BOLD}qq${NC} help"
    echo -e "  ${CYAN}Ctrl+B${NC}     explain the last command you ran"
    echo ""
    echo -e "${WHITE}${BOLD}  ── To remove ────────────────────────────────${NC}"
    echo ""
    echo -e "  ${CYAN}bash ~/bashtutor-prod/install.sh --uninstall${NC}"
    echo ""
    printf '\033[38;5;240m  Designed by Adam J. Turton\033[0m\n'
    echo -e "${GREEN}  ─────────────────────────────────────────────${NC}"
    echo ""
}

main "$@"
