#!/usr/bin/env bash
# BashTutor Installer
# Idempotent installation script for macOS with zsh
# Version: 0.1.0

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_VERSION="0.1.0"
readonly BASHTUTOR_DIR="${HOME}/.bashtutor"
readonly SOURCE_ZSHRC="${HOME}/.zshrc"
readonly ZSHRC_BACKUP="${HOME}/.zshrc.bashtutor.bak.$(date +%Y%m%d%H%M%S)"

# Source file location (relative to install.sh or absolute)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_PLUGIN="${SCRIPT_DIR}/bashtutor.zsh"

# Source line marker for idempotency
readonly SOURCE_MARKER="# BashTutor plugin - https://github.com/adamturton/bashtutor"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    log_error "$1"
    exit 1
}

# =============================================================================
# VALIDATION
# =============================================================================

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64)
            echo "Intel (x86_64)"
            ;;
        arm64)
            echo "Apple Silicon (ARM64)"
            ;;
        *)
            echo "Unknown ($arch)"
            ;;
    esac
}

validate_platform() {
    log_info "Detecting platform..."
    
    # Check for macOS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        die "BashTutor currently only supports macOS. Detected: $(uname -s)"
    fi
    
    # Check for zsh
    if [[ "${SHELL##*/}" != "zsh" ]]; then
        die "BashTutor requires zsh. Current shell: ${SHELL:-unknown}"
    fi
    
    # Verify zsh version (should be 5.0+)
    local zsh_version
    zsh_version=$(zsh --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    log_info "zsh version: $zsh_version"
    
    local arch
    arch=$(detect_architecture)
    log_info "Architecture: $arch"
}

validate_source_file() {
    log_info "Validating source plugin..."
    
    if [[ ! -f "$SOURCE_PLUGIN" ]]; then
        die "Source file not found: $SOURCE_PLUGIN
        Please ensure bashtutor.zsh is in the same directory as install.sh"
    fi
    
    log_info "Source file found: $SOURCE_PLUGIN"
    
    # Test zsh syntax
    log_info "Testing zsh syntax..."
    if ! zsh -n "$SOURCE_PLUGIN" 2>/dev/null; then
        die "Syntax error detected in $SOURCE_PLUGIN"
    fi
    
    log_success "Syntax validation passed"
}

# =============================================================================
# INSTALLATION
# =============================================================================

create_directories() {
    log_info "Creating directories..."
    
    # Create main directory
    if [[ -d "$BASHTUTOR_DIR" ]]; then
        log_warn "Directory already exists: $BASHTUTOR_DIR"
    else
        mkdir -p "$BASHTUTOR_DIR"
        log_success "Created: $BASHTUTOR_DIR"
    fi
    
    # Create subdirectories
    local subdirs=("cache" "history")
    for subdir in "${subdirs[@]}"; do
        local full_path="${BASHTUTOR_DIR}/${subdir}"
        if [[ -d "$full_path" ]]; then
            log_warn "Directory already exists: $full_path"
        else
            mkdir -p "$full_path"
            log_success "Created: $full_path"
        fi
    done
}

copy_plugin() {
    log_info "Installing plugin..."
    
    local dest="${BASHTUTOR_DIR}/bashtutor.zsh"
    
    if [[ -f "$dest" ]]; then
        log_warn "Plugin already exists, updating..."
    fi
    
    cp "$SOURCE_PLUGIN" "$dest"
    log_success "Installed: $dest"
}

create_config() {
    log_info "Creating default configuration..."
    
    local config_file="${BASHTUTOR_DIR}/config"
    
    if [[ -f "$config_file" ]]; then
        log_warn "Config already exists, skipping: $config_file"
        return 0
    fi
    
    cat > "$config_file" << 'EOF'
# BashTutor Configuration
# This file is sourced by bashtutor.zsh

# Auto-explain mode: set to 1 to automatically explain every command
# BASHTUTOR_AUTO_EXPLAIN=0

# Maximum OpenClaw wait time (seconds)
# BASHTUTOR_OPENCLAW_TIMEOUT=5

# History file retention (days, 0 = unlimited)
# BASHTUTOR_HISTORY_RETENTION_DAYS=0
EOF
    
    log_success "Created: $config_file"
}

add_source_line() {
    log_info "Configuring shell..."
    
    if [[ ! -f "$SOURCE_ZSHRC" ]]; then
        log_warn "~/.zshrc not found, creating..."
        touch "$SOURCE_ZSHRC"
    fi
    
    # Check if already sourced (idempotent)
    if grep -qF "$SOURCE_MARKER" "$SOURCE_ZSHRC" 2>/dev/null; then
        log_warn "BashTutor already configured in ~/.zshrc"
        return 0
    fi
    
    # Backup .zshrc
    cp "$SOURCE_ZSHRC" "$ZSHRC_BACKUP"
    log_info "Backed up ~/.zshrc to $ZSHRC_BACKUP"
    
    # Add source line
    cat >> "$SOURCE_ZSHRC" << EOF

${SOURCE_MARKER}
[[ -f "${BASHTUTOR_DIR}/bashtutor.zsh" ]] && source "${BASHTUTOR_DIR}/bashtutor.zsh"
EOF
    
    log_success "Added source line to ~/.zshrc"
}

# =============================================================================
# UNINSTALLATION
# =============================================================================

uninstall() {
    log_info "Uninstalling BashTutor..."
    
    local found_something=false
    
    # Remove source line from .zshrc
    if [[ -f "$SOURCE_ZSHRC" ]]; then
        if grep -qF "$SOURCE_MARKER" "$SOURCE_ZSHRC" 2>/dev/null; then
            log_info "Removing source line from ~/.zshrc..."
            # Create backup
            cp "$SOURCE_ZSHRC" "${SOURCE_ZSHRC}.uninstall.bak.$(date +%Y%m%d%H%M%S)"
            # Remove the source line and preceding marker comment
            sed -i.bashtutor.tmp "/${SOURCE_MARKER//\//\\/}/d" "$SOURCE_ZSHRC" 2>/dev/null || \
                sed -i "/${SOURCE_MARKER//\//\\/}/d" "$SOURCE_ZSHRC" 2>/dev/null || \
                grep -vF "$SOURCE_MARKER" "$SOURCE_ZSHRC" > "${SOURCE_ZSHRC}.tmp" && mv "${SOURCE_ZSHRC}.tmp" "$SOURCE_ZSHRC"
            # Clean up temp files
            rm -f "${SOURCE_ZSHRC}.bashtutor.tmp" "${SOURCE_ZSHRC}.tmp" 2>/dev/null
            log_success "Removed source line from ~/.zshrc"
            found_something=true
        fi
    fi
    
    # Remove plugin directory
    if [[ -d "$BASHTUTOR_DIR" ]]; then
        log_info "Removing directory: $BASHTUTOR_DIR"
        rm -rf "$BASHTUTOR_DIR"
        log_success "Removed: $BASHTUTOR_DIR"
        found_something=true
    fi
    
    if [[ "$found_something" == false ]]; then
        log_warn "BashTutor doesn't appear to be installed"
    else
        log_success "Uninstallation complete!"
        echo ""
        echo "Please restart your terminal or run: source ~/.zshrc"
    fi
    
    exit 0
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    cat << EOF
BashTutor Installer v${SCRIPT_VERSION}

Usage: ./install.sh [OPTIONS]

Options:
    --uninstall    Remove BashTutor from the system
    --help         Show this help message

Description:
    Installs BashTutor, a zsh plugin that teaches bash through doing.
    Designed for dyslexic learning patterns.

The installer will:
    - Detect macOS and zsh
    - Create ~/.bashtutor/ with cache and history subdirectories
    - Install bashtutor.zsh to ~/.bashtutor/
    - Add source line to ~/.zshrc (idempotent)
    - Create default configuration file
    - Report system architecture
    - Validate syntax before installing

After installation, restart your terminal or run: source ~/.zshrc
EOF
}

main() {
    # Parse arguments
    case "${1:-}" in
        --uninstall)
            uninstall
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # Continue with installation
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    echo "🎓 BashTutor Installer v${SCRIPT_VERSION}"
    echo "===================================="
    echo ""
    
    # Validate
    validate_platform
    validate_source_file
    
    # Install
    create_directories
    copy_plugin
    create_config
    add_source_line
    
    # Done
    echo ""
    echo "===================================="
    log_success "BashTutor installed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal OR run: source ~/.zshrc"
    echo ""
    echo "  2. (RECOMMENDED) Set your Anthropic API key for AI-powered explanations:"
    echo "     export ANTHROPIC_API_KEY=\"sk-ant-...\""
    echo "     Get a free key at: https://console.anthropic.com/"
    echo ""
    echo "  3. Try it out:"
    echo "     bashme show files modified today"
    echo ""
    echo "Commands:"
    echo "  bashme <request>         Get bash command from plain English"
    echo "  bashtutor_toggle         Toggle auto-explanations"
    echo "  bashtutor_history        View command history"
    echo "  bashtutor_help           Show all commands"
    echo ""
    echo "Without ANTHROPIC_API_KEY, BashTutor uses local pattern matching"
    echo "which works fine for common commands."
    echo ""
}

main "$@"