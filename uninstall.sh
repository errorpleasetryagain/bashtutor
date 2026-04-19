#!/usr/bin/env zsh
# BashTutor Uninstall Script
# Removes BashTutor from your system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASHTUTOR_DIR="${HOME}/.bashtutor"
ZSHRC="${HOME}/.zshrc"
FORCE_YES=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            FORCE_YES=1
            shift
            ;;
        -h|--help)
            echo "Usage: uninstall.sh [-y]"
            echo ""
            echo "Options:"
            echo "  -y, --yes    Skip confirmation prompts"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run 'uninstall.sh --help' for usage"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🗑️  BashTutor Uninstaller${NC}"
echo ""

# Confirm unless -y flag is set
if [[ $FORCE_YES -eq 0 ]]; then
    echo -n "Are you sure you want to uninstall BashTutor? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
fi

echo "Cleaning up..."
echo ""

# Track what was cleaned up
REMOVED_ITEMS=()

# Remove ~/.bashtutor directory
if [[ -d "$BASHTUTOR_DIR" ]]; then
    echo "   Removing $BASHTUTOR_DIR..."
    rm -rf "$BASHTUTOR_DIR"
    REMOVED_ITEMS+=("Config directory: $BASHTUTOR_DIR")
else
    echo -e "   ${YELLOW}⚠️${NC}  Config directory not found: $BASHTUTOR_DIR"
fi

# Remove source line from .zshrc
if [[ -f "$ZSHRC" ]]; then
    if grep -q "source.*bashtutor.zsh" "$ZSHRC" 2>/dev/null || \
       grep -q "# BashTutor" "$ZSHRC" 2>/dev/null; then
        echo "   Removing BashTutor from $ZSHRC..."
        # Create backup
        cp "$ZSHRC" "$ZSHRC.backup.$(date +%Y%m%d%H%M%S)"
        # Remove lines containing bashtutor
        sed -i '' '/# BashTutor/d' "$ZSHRC" 2>/dev/null || true
        sed -i '' '/source.*bashtutor.zsh/d' "$ZSHRC" 2>/dev/null || true
        REMOVED_ITEMS+=("Shell configuration: $ZSHRC")
    else
        echo -e "   ${YELLOW}⚠️${NC}  No BashTutor entry found in $ZSHRC"
    fi
else
    echo -e "   ${YELLOW}⚠️${NC}  $ZSHRC not found"
fi

# Report what was cleaned up
echo ""
echo -e "${GREEN}✓ Uninstall complete${NC}"
echo ""

if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
    echo "Cleaned up:"
    for item in "${REMOVED_ITEMS[@]}"; do
        echo "   • $item"
    done
else
    echo "Nothing to clean up."
fi

echo ""
echo -e "${YELLOW}Note:${NC} Restart your terminal or run 'source ~/.zshrc' to complete."
echo ""

exit 0
