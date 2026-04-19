#!/usr/bin/env bash
# BashTutor Installer
# Installs BashTutor as a permanent macOS zsh OS-level plugin
# Version: 1.3.0
#
# Works two ways:
#   1. Run directly from the repo folder: bash install.sh
#   2. Run via curl (self-contained):
#      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/errorpleasetryagain/bashtutor/main/install.sh)"
#
# Usage:
#   bash install.sh              # install OpenClaw edition (default)
#   bash install.sh --claude     # install Claude API edition
#   bash install.sh --uninstall  # remove everything

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_VERSION="1.3.0"
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
            info "Updating existing install..."
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

    # Fallback: download files directly via curl
    info "git not found — downloading files directly..."
    mkdir -p "$REPO_DIR"
    curl -fsSL "${GITHUB_RAW}/bashtutor-openclaw.zsh" -o "${REPO_DIR}/bashtutor-openclaw.zsh" || die "Download failed"
    curl -fsSL "${GITHUB_RAW}/bashtutor-claude.zsh"   -o "${REPO_DIR}/bashtutor-claude.zsh"   || die "Download failed"
    ok "Downloaded BashTutor"
    SCRIPT_DIR="$REPO_DIR"
}

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall() {
    info "Uninstalling BashTutor..."

    if [[ -f "$ZSHRC" ]] && grep -qF "$SOURCE_MARKER" "$ZSHRC" 2>/dev/null; then
        cp "$ZSHRC" "${ZSHRC}.uninstall.bak.$(date +%Y%m%d%H%M%S)"
        grep -v "$SOURCE_MARKER" "$ZSHRC" | grep -v "source.*\.bashtutor/bashtutor\.zsh" > "${ZSHRC}.tmp" && \
            mv "${ZSHRC}.tmp" "$ZSHRC"
        ok "Removed from ~/.zshrc"
    else
        warn "BashTutor not found in ~/.zshrc"
    fi

    if [[ -d "$BASHTUTOR_DIR" ]]; then
        rm -rf "$BASHTUTOR_DIR"
        ok "Removed ~/.bashtutor/"
    else
        warn "~/.bashtutor/ not found"
    fi

    echo ""
    ok "BashTutor uninstalled. Restart your terminal to finish."
    echo ""
    exit 0
}

# =============================================================================
# CHECKS
# =============================================================================

check_platform() {
    info "Checking your system..."

    [[ "$(uname -s)" == "Darwin" ]] || die "BashTutor only supports macOS right now."

    # Check zsh exists
    if ! command -v zsh &>/dev/null; then
        die "zsh not found. Install it with: brew install zsh"
    fi

    # Check current shell — warn if not zsh but don't block
    local shell_name="${SHELL##*/}"
    if [[ "$shell_name" != "zsh" ]]; then
        warn "Your default shell is ${SHELL} — BashTutor needs zsh."
        echo ""
        echo "  Switch to zsh with:"
        echo -e "  ${CYAN}chsh -s \$(which zsh)${NC}"
        echo "  Then open a new terminal and re-run this installer."
        echo ""
        die "Please switch to zsh first."
    fi

    local zsh_version
    zsh_version=$(zsh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    ok "macOS with zsh ${zsh_version} — good to go"
}

check_plugin_file() {
    if [[ "$EDITION" == "claude" ]]; then
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-claude.zsh"
    else
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-openclaw.zsh"
    fi

    # Fall back to generic name
    if [[ ! -f "$PLUGIN_FILE" ]]; then
        PLUGIN_FILE="${SCRIPT_DIR}/bashtutor.zsh"
    fi

    [[ -f "$PLUGIN_FILE" ]] || die "Plugin file not found. Try re-running the installer."

    if command -v zsh &>/dev/null; then
        zsh -n "$PLUGIN_FILE" 2>/dev/null || die "Syntax error in plugin file — try re-downloading"
    fi
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
    fi
}

# =============================================================================
# INSTALL
# =============================================================================

create_dirs() {
    info "Setting up ~/.bashtutor/ ..."
    mkdir -p "${BASHTUTOR_DIR}/cache"
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
    info "Wiring into your shell..."

    [[ -f "$ZSHRC" ]] || touch "$ZSHRC"

    if grep -qF "$SOURCE_MARKER" "$ZSHRC" 2>/dev/null; then
        warn "Already in ~/.zshrc — updating"
        grep -v "$SOURCE_MARKER" "$ZSHRC" | grep -v "source.*\.bashtutor/bashtutor\.zsh" > "${ZSHRC}.tmp" && \
            mv "${ZSHRC}.tmp" "$ZSHRC"
    else
        cp "$ZSHRC" "$ZSHRC_BACKUP"
        info "Backed up ~/.zshrc to ${ZSHRC_BACKUP##*/}"
    fi

    cat >> "$ZSHRC" << EOF

${SOURCE_MARKER}
[[ -f "\${HOME}/.bashtutor/bashtutor.zsh" ]] && source "\${HOME}/.bashtutor/bashtutor.zsh"
EOF

    ok "Added to ~/.zshrc — BashTutor will load every time a terminal opens"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    [[ "$EDITION" == "uninstall" ]] && uninstall

    echo ""
    echo -e "${ORANGE}${BOLD}  Ba\$h Tutor${NC}${WHITE}${BOLD}  ~  bash for humans${NC}"
    echo -e "${GREEN}  ── Installer v${SCRIPT_VERSION} ──────────────────────────${NC}"
    echo -e "${CYAN}  Installing at OS level — loads in every terminal${NC}"
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

    echo ""
    echo -e "${BOLD}${GREEN}🎉 Done! BashTutor is installed.${NC}"
    echo ""
    echo "  Activate it now:"
    echo ""
    echo -e "  ${CYAN}source ~/.zshrc${NC}"
    echo ""
    echo "  Then try:"
    echo ""
    echo -e "  ${ORANGE}${BOLD}qq${NC} show files modified today"
    echo -e "  ${ORANGE}${BOLD}qq${NC} help"
    echo -e "  ${CYAN}Ctrl+B${NC}  — explain the last command"
    echo ""
    echo "  To remove:"
    echo -e "  ${CYAN}bash ~/bashtutor-prod/install.sh --uninstall${NC}"
    echo ""
}

main "$@"
