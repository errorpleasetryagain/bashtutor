#!/usr/bin/env bash
# BashTutor Installer
# Installs BashTutor as a permanent macOS zsh OS-level plugin
# Version: 1.2.0
#
# What this does:
#   1. Checks you're on macOS with zsh
#   2. Creates ~/.bashtutor/ (your permanent home for BashTutor)
#   3. Copies the plugin there
#   4. Adds one line to ~/.zshrc so it loads every time a terminal opens
#   5. Activates it in your current terminal right now
#
# Usage:
#   bash install.sh              # install OpenClaw edition (default)
#   bash install.sh --claude     # install Claude API edition
#   bash install.sh --uninstall  # remove everything

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_VERSION="1.2.0"
readonly BASHTUTOR_DIR="${HOME}/.bashtutor"
readonly ZSHRC="${HOME}/.zshrc"
readonly ZSHRC_BACKUP="${HOME}/.zshrc.bashtutor.bak.$(date +%Y%m%d%H%M%S)"
readonly SOURCE_MARKER="# BashTutor — loaded at OS level (zsh plugin)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to OpenClaw edition
EDITION="openclaw"
PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-openclaw.zsh"

# Parse args
for arg in "$@"; do
    case "$arg" in
        --claude)
            EDITION="claude"
            PLUGIN_FILE="${SCRIPT_DIR}/bashtutor-claude.zsh"
            ;;
        --uninstall)
            EDITION="uninstall"
            ;;
    esac
done

# Fall back to bashtutor.zsh if edition-specific file doesn't exist
if [[ "$EDITION" != "uninstall" && ! -f "$PLUGIN_FILE" ]]; then
    PLUGIN_FILE="${SCRIPT_DIR}/bashtutor.zsh"
fi

# =============================================================================
# COLOURS
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}${BOLD}✅ $*${NC}"; }
info() { echo -e "${CYAN}🐚 $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()  { echo -e "${RED}❌ $*${NC}" >&2; }
die()  { err "$1"; exit 1; }

# =============================================================================
# UNINSTALL
# =============================================================================

uninstall() {
    info "Uninstalling BashTutor..."

    # Remove source line from .zshrc
    if [[ -f "$ZSHRC" ]] && grep -qF "$SOURCE_MARKER" "$ZSHRC" 2>/dev/null; then
        cp "$ZSHRC" "${ZSHRC}.uninstall.bak.$(date +%Y%m%d%H%M%S)"
        # Remove the marker line and the source line after it
        grep -v "$SOURCE_MARKER" "$ZSHRC" | grep -v "source.*\.bashtutor/bashtutor\.zsh" > "${ZSHRC}.tmp" && \
            mv "${ZSHRC}.tmp" "$ZSHRC"
        ok "Removed from ~/.zshrc"
    else
        warn "BashTutor not found in ~/.zshrc"
    fi

    # Remove plugin directory
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

    local shell_name="${SHELL##*/}"
    [[ "$shell_name" == "zsh" ]] || die "BashTutor needs zsh. Your shell is: ${SHELL}. Switch to zsh in System Settings → Users & Groups."

    local zsh_version
    zsh_version=$(zsh --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    ok "macOS with zsh ${zsh_version} — good to go"
}

check_plugin_file() {
    [[ -f "$PLUGIN_FILE" ]] || die "Plugin file not found: $PLUGIN_FILE
Make sure install.sh is in the same folder as bashtutor-openclaw.zsh"

    # Syntax check
    if command -v zsh &>/dev/null; then
        zsh -n "$PLUGIN_FILE" 2>/dev/null || die "Syntax error in plugin file — try re-downloading from GitHub"
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
            warn "ANTHROPIC_API_KEY not set — add it to ~/.zshrc to enable AI:"
            echo "     export ANTHROPIC_API_KEY=\"sk-ant-...\""
            echo "     Get a free key at: https://console.anthropic.com"
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

    # Create ~/.zshrc if it doesn't exist
    [[ -f "$ZSHRC" ]] || touch "$ZSHRC"

    # Already installed?
    if grep -qF "$SOURCE_MARKER" "$ZSHRC" 2>/dev/null; then
        warn "Already in ~/.zshrc — updating the source line"
        # Remove old lines and re-add cleanly
        grep -v "$SOURCE_MARKER" "$ZSHRC" | grep -v "source.*\.bashtutor/bashtutor\.zsh" > "${ZSHRC}.tmp" && \
            mv "${ZSHRC}.tmp" "$ZSHRC"
    else
        # Back up .zshrc first
        cp "$ZSHRC" "$ZSHRC_BACKUP"
        info "Backed up ~/.zshrc to ${ZSHRC_BACKUP##*/}"
    fi

    # Add the source line
    cat >> "$ZSHRC" << EOF

${SOURCE_MARKER}
[[ -f "\${HOME}/.bashtutor/bashtutor.zsh" ]] && source "\${HOME}/.bashtutor/bashtutor.zsh"
EOF

    ok "Added to ~/.zshrc — BashTutor will now load every time a terminal opens"
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    cat << EOF

${BOLD}BashTutor Installer v${SCRIPT_VERSION}${NC}

Usage:
  bash install.sh              Install OpenClaw edition (default)
  bash install.sh --claude     Install Claude API edition
  bash install.sh --uninstall  Remove BashTutor completely

After installing:
  Restart your terminal OR run: source ~/.zshrc

Then try:
  bashme show files modified today
  bt find all pdfs in downloads
  Ctrl+B  (explain last command)

EOF
}

main() {
    # Handle uninstall
    [[ "$EDITION" == "uninstall" ]] && uninstall

    echo ""
    echo -e "${BOLD}${CYAN}🎓 BashTutor Installer v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}   Installing at OS level — loads in every terminal automatically${NC}"
    echo ""

    check_platform
    check_plugin_file
    check_ai
    create_dirs
    copy_plugin
    create_config
    wire_into_zshrc

    echo ""
    echo -e "${BOLD}${GREEN}🎉 Done! BashTutor is installed at OS level.${NC}"
    echo ""
    echo "  Now activate it in this terminal:"
    echo ""
    echo -e "  ${CYAN}source ~/.zshrc${NC}"
    echo ""
    echo "  Then try it:"
    echo ""
    echo -e "  ${CYAN}bashme show files modified today${NC}"
    echo -e "  ${CYAN}bt find all pdfs in my downloads${NC}"
    echo -e "  ${CYAN}Ctrl+B${NC}  — explain the last command"
    echo ""
    echo "  To remove BashTutor at any time:"
    echo -e "  ${CYAN}bash install.sh --uninstall${NC}"
    echo ""
}

main "$@"
