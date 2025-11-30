#!/bin/bash
# Claude Code Statusline Uninstaller

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${RED}Uninstalling Claude Code Statusline${NC}"
echo ""

# Remove script
if [[ -f "$HOME/.claude/statusline-command.sh" ]]; then
    rm -f "$HOME/.claude/statusline-command.sh"
    echo -e "${GREEN}✓${NC} Removed statusline-command.sh"
fi

# Remove config
if [[ -f "$HOME/.claude/statusline-config.json" ]]; then
    rm -f "$HOME/.claude/statusline-config.json"
    echo -e "${GREEN}✓${NC} Removed statusline-config.json"
fi

# Remove cache
if [[ -d "$HOME/.cache/claude-statusline" ]]; then
    rm -rf "$HOME/.cache/claude-statusline"
    echo -e "${GREEN}✓${NC} Removed cache directory"
fi

echo ""
echo -e "${YELLOW}Note:${NC} settings.json was not modified."
echo "To fully disable, remove the 'statusLine' entry from ~/.claude/settings.json"
echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
