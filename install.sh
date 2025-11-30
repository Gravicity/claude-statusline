#!/bin/bash
# Claude Code Statusline Installer
# Interactive setup with configuration options

set -e

# ============================================
# COLORS & STYLING (matching statusline)
# ============================================
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Theme colors (RGB)
PURPLE='\033[1;38;2;139;92;246m'      # Opus
ORANGE='\033[1;38;2;255;140;0m'       # Sonnet
TEAL='\033[1;38;2;0;188;212m'         # Haiku
SLATE='\033[1;38;2;148;163;184m'      # Muted

# Health colors
GREEN='\033[1;38;2;34;197;94m'
YELLOW='\033[1;38;2;234;179;8m'
RED='\033[1;38;2;239;68;68m'

# Standard
CYAN='\033[1;36m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'

# Box drawing
BOX_TL="╭" BOX_TR="╮" BOX_BL="╰" BOX_BR="╯" BOX_H="─" BOX_V="│"

# ============================================
# PATHS
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude"
SCRIPT_NAME="statusline-command.sh"
CONFIG_NAME="statusline-config.json"
SETTINGS_FILE="$HOME/.claude/settings.json"

# ============================================
# DEFAULTS
# ============================================
PLAN="api"
TRACKING_ENABLED=true
GIT_REPOS_ONLY=true
CREATE_UMBRELLA=false
PULSE_ANIMATION=true
COST_CYCLING=true

# ============================================
# VISUAL HELPERS
# ============================================

# Animated pulse (like statusline) - purple theme
print_pulse() {
    local width=${1:-40}
    local frame=$((RANDOM % 20))
    local orb_pos=$((frame + 2))
    local pulse=""

    for ((i=0; i<orb_pos && i<width; i++)); do
        local dist=$((orb_pos - i))
        if ((dist > 6)); then
            pulse+="\033[38;2;139;92;246m─\033[0m"
        elif ((dist == 6)); then
            pulse+="\033[38;2;139;92;246m┉\033[0m"
        else
            local prog=$((6 - dist))
            local r=$((139 + (34-139) * prog / 6))
            local g=$((92 + (197-92) * prog / 6))
            local b=$((246 + (94-246) * prog / 6))
            pulse+="\033[38;2;${r};${g};${b}m━\033[0m"
        fi
    done

    pulse+="\033[1;38;2;34;197;94m◉\033[0m"

    # Fade ahead
    local remaining=$((width - orb_pos - 1))
    local fade_chars=("╸" "╍" "┈")
    for ((i=0; i<remaining; i++)); do
        if ((i < 3)); then
            local prog=$((i * 100 / 3))
            local r=$((34 + (139-34) * prog / 100))
            local g=$((197 + (92-197) * prog / 100))
            local b=$((94 + (246-94) * prog / 100))
            pulse+="\033[38;2;${r};${g};${b}m${fade_chars[$i]}\033[0m"
        else
            pulse+="\033[38;2;139;92;246m─\033[0m"
        fi
    done

    echo -e "$pulse"
}

print_header() {
    clear
    echo ""
    echo -e "  ${PURPLE}╭─${RESET}${BOLD}${WHITE} Claude Code Statusline ${RESET}${DIM}v2.0${RESET}"
    echo -e "  ${PURPLE}│${RESET}"
    echo -e "  ${PURPLE}│${RESET}  $(print_pulse 44)"
    echo -e "  ${PURPLE}│${RESET}"
    echo ""
}

print_step() {
    local step="$1"
    local total="$2"
    local title="$3"
    echo ""
    echo -e "  ${PURPLE}[${ORANGE}${step}${PURPLE}/${TEAL}${total}${PURPLE}]${RESET} ${BOLD}${title}${RESET}"
}

print_success() {
    echo -e "  ${GREEN}✓${RESET} $1"
}

print_info() {
    echo -e "  ${BLUE}→${RESET} $1"
}

print_warn() {
    echo -e "  ${YELLOW}!${RESET} $1"
}

print_error() {
    echo -e "  ${RED}✗${RESET} $1"
}

print_option() {
    local num="$1"
    local text="$2"
    local desc="$3"
    echo -e "      ${SLATE}${num})${RESET} ${WHITE}${text}${RESET} ${DIM}${desc}${RESET}"
}

# Preview what statusline will look like
print_preview() {
    echo -e "  ${DIM}Preview:${RESET}"
    echo -e "  ${PURPLE}╭─${PURPLE}Opus${PURPLE}─${PURPLE}4.5${PURPLE}─${RESET}🧠${PURPLE}─${GREEN}32%${PURPLE}─${RESET}📚${PURPLE}─${GREEN}2${PURPLE}─${RESET}💰${PURPLE}12.50/hr${RESET}"
    echo -e "  ${PURPLE}│${RESET} 📁 ${CYAN}~/my-project${RESET}"
    echo -e "  ${PURPLE}│${RESET} ${BLUE}⊛ main${RESET} ${GREEN}↑2${RESET} ${GREEN}●3${RESET} ${YELLOW}~5${RESET} ${SLATE}?7${RESET} ${GREEN}12m${RESET}"
    echo -e "  ${PURPLE}│${RESET} ⧗ ${PURPLE}45m${RESET} 💬 ${CYAN}12${RESET} ${PURPLE}+156${RED}-23${RESET} ${PURPLE}※ a1b2c3${RESET}"
    echo -e "  ${PURPLE}╰─${RESET}$(print_pulse 38) ${GREEN}🛡 94%${RESET}"
    echo ""
}

print_complete() {
    echo ""
    echo -e "  ${GREEN}╭─ ✓ Installation Complete!${RESET}"
    echo -e "  ${GREEN}│${RESET}"
    echo -e "  ${GREEN}│${RESET}  ${DIM}Installed:${RESET}"
    echo -e "  ${GREEN}│${RESET}    ${SLATE}•${RESET} ${CYAN}~/.claude/statusline-command.sh${RESET}"
    echo -e "  ${GREEN}│${RESET}    ${SLATE}•${RESET} ${CYAN}~/.claude/statusline-config.json${RESET}"
    [[ "$CREATE_UMBRELLA" == "true" ]] && echo -e "  ${GREEN}│${RESET}    ${SLATE}•${RESET} ${CYAN}.claude/statusline-project.json${RESET}"
    echo -e "  ${GREEN}│${RESET}"
    echo -e "  ${GREEN}╰─${RESET} ${YELLOW}Restart Claude Code to see your statusline${RESET}"
    echo ""
}

# ============================================
# CHECKS
# ============================================

check_dependencies() {
    local missing=()

    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v bc >/dev/null 2>&1 || missing+=("bc")
    command -v git >/dev/null 2>&1 || missing+=("git")

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo -e "  Install with:"
        if [[ "$(uname)" == "Darwin" ]]; then
            echo -e "    ${CYAN}brew install ${missing[*]}${RESET}"
        else
            echo -e "    ${CYAN}sudo apt install ${missing[*]}${RESET}"
        fi
        exit 1
    fi

    print_success "Dependencies: ${GREEN}jq${RESET}, ${GREEN}bc${RESET}, ${GREEN}git${RESET}"
}

# ============================================
# PROMPTS
# ============================================

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    if [[ "$default" == "y" ]]; then
        prompt="$prompt ${SLATE}[Y/n]${RESET}: "
    else
        prompt="$prompt ${SLATE}[y/N]${RESET}: "
    fi

    echo -ne "      $prompt"
    read -r response
    response="${response:-$default}"

    [[ "$response" =~ ^[Yy] ]]
}

ask_choice() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "      ${DIM}$prompt${RESET}"
    local i=1
    for opt in "${options[@]}"; do
        print_option "$i" "$opt" ""
        ((i++))
    done

    echo -ne "      ${SLATE}Choice [1]:${RESET} "
    local choice
    read -r choice
    choice="${choice:-1}"

    echo "${options[$((choice-1))]}"
}

# ============================================
# SETUP
# ============================================

interactive_setup() {
    print_step 1 6 "Claude Plan"
    echo -e "      ${DIM}Affects cost calculations${RESET}"
    local plan_choice
    plan_choice=$(ask_choice "Select your plan:" "api - Pay per use" "max5x - Pro 5x" "max20x - Pro 20x")
    case "$plan_choice" in
        "api"*) PLAN="api" ;;
        "max5x"*) PLAN="max5x" ;;
        "max20x"*) PLAN="max20x" ;;
    esac
    print_success "Plan: ${ORANGE}$PLAN${RESET}"

    print_step 2 6 "Cost Tracking"
    if ask_yes_no "Track costs per project?"; then
        TRACKING_ENABLED=true
        print_success "Cost tracking ${GREEN}enabled${RESET}"
    else
        TRACKING_ENABLED=false
        print_info "Cost tracking ${SLATE}disabled${RESET}"
    fi

    if [[ "$TRACKING_ENABLED" == "true" ]]; then
        print_step 3 6 "Auto-Create Settings"
        echo -e "      ${DIM}Where to auto-create project configs${RESET}"
        if ask_yes_no "Only in git repos? ${DIM}(recommended)${RESET}"; then
            GIT_REPOS_ONLY=true
            print_success "Git repos only"
        else
            GIT_REPOS_ONLY=false
            print_warn "Will create in any folder"
        fi

        print_step 4 6 "Umbrella Project"
        echo -e "      ${DIM}Track costs across sub-projects in current dir${RESET}"
        if ask_yes_no "Create umbrella project here?" "n"; then
            CREATE_UMBRELLA=true
            print_success "Will create umbrella config"
        fi
    else
        print_step 3 6 "Skipped ${DIM}(tracking disabled)${RESET}"
        print_step 4 6 "Skipped ${DIM}(tracking disabled)${RESET}"
    fi

    print_step 5 6 "Display Options"
    if ask_yes_no "Enable pulse animation?"; then
        PULSE_ANIMATION=true
    else
        PULSE_ANIMATION=false
    fi
    if ask_yes_no "Enable cost cycling? ${DIM}(/hr → session → project)${RESET}"; then
        COST_CYCLING=true
    else
        COST_CYCLING=false
    fi
    print_success "Animation: $([ "$PULSE_ANIMATION" == "true" ] && echo "${GREEN}on${RESET}" || echo "${SLATE}off${RESET}"), Cycling: $([ "$COST_CYCLING" == "true" ] && echo "${GREEN}on${RESET}" || echo "${SLATE}off${RESET}")"

    print_step 6 6 "Install"
}

create_config() {
    local config_path="$INSTALL_DIR/$CONFIG_NAME"

    cat > "$config_path" << EOF
{
  "version": 1,
  "plan": "$PLAN",
  "tracking": {
    "enabled": $TRACKING_ENABLED,
    "git_repos_only": $GIT_REPOS_ONLY,
    "auto_create_umbrella": false
  },
  "display": {
    "pulse_animation": $PULSE_ANIMATION,
    "cost_cycling": $COST_CYCLING
  },
  "health_colors": {
    "good": [34, 197, 94],
    "warn": [234, 179, 8],
    "crit": [239, 68, 68]
  },
  "thresholds": {
    "context_warn": 50,
    "context_crit": 75,
    "memory_warn": 4,
    "memory_crit": 8,
    "staleness_warn": 100,
    "staleness_crit": 500
  }
}
EOF

    print_success "Config saved"
}

create_umbrella() {
    [[ "$CREATE_UMBRELLA" != "true" ]] && return

    local umbrella_dir="$PWD/.claude"
    local umbrella_config="$umbrella_dir/statusline-project.json"

    if [[ -f "$umbrella_config" ]]; then
        print_warn "Umbrella already exists"
        return
    fi

    mkdir -p "$umbrella_dir"

    local folder_name=$(basename "$PWD")
    cat > "$umbrella_config" << EOF
{
  "name": "$folder_name",
  "icon": "🌌",
  "color": null,
  "git": null,
  "parent": null
}
EOF

    print_success "Umbrella project created"
}

install_script() {
    mkdir -p "$INSTALL_DIR"

    if [[ -f "$SCRIPT_DIR/$SCRIPT_NAME" ]]; then
        cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
    else
        print_error "Script not found: $SCRIPT_DIR/$SCRIPT_NAME"
        exit 1
    fi

    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    print_success "Script installed"
}

update_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
            print_info "Settings already configured"
        else
            if ask_yes_no "Add to settings.json?"; then
                local updated=$(jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline-command.sh"}}' "$SETTINGS_FILE")
                echo "$updated" > "$SETTINGS_FILE"
                print_success "Settings updated"
            fi
        fi
    else
        if ask_yes_no "Create settings.json?"; then
            mkdir -p "$(dirname "$SETTINGS_FILE")"
            cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
EOF
            print_success "Settings created"
        fi
    fi
}

# ============================================
# MAIN
# ============================================

case "${1:-}" in
    --defaults)
        print_header
        check_dependencies
        install_script
        create_config
        print_complete
        ;;
    --update)
        print_header
        check_dependencies
        install_script
        print_success "Script updated ${DIM}(config preserved)${RESET}"
        echo ""
        ;;
    --uninstall)
        print_header
        rm -f "$INSTALL_DIR/$SCRIPT_NAME"
        rm -f "$INSTALL_DIR/$CONFIG_NAME"
        rm -rf "$HOME/.cache/claude-statusline"
        print_success "Uninstalled"
        print_info "Remove 'statusLine' from settings.json manually"
        echo ""
        ;;
    --help|-h)
        echo ""
        echo -e "  ${BOLD}Claude Code Statusline Installer${RESET}"
        echo ""
        echo -e "  ${DIM}Usage:${RESET} ./install.sh [option]"
        echo ""
        echo -e "  ${DIM}Options:${RESET}"
        echo -e "    ${SLATE}(none)${RESET}      Interactive installation"
        echo -e "    ${SLATE}--defaults${RESET}  Install with defaults"
        echo -e "    ${SLATE}--update${RESET}    Update script only"
        echo -e "    ${SLATE}--uninstall${RESET} Remove everything"
        echo -e "    ${SLATE}--help${RESET}      Show this help"
        echo ""
        ;;
    --preview)
        print_header
        print_preview
        ;;
    *)
        print_header
        check_dependencies
        print_preview
        interactive_setup
        install_script
        create_config
        create_umbrella
        update_settings
        print_complete
        ;;
esac
