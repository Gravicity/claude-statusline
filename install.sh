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

# Detect truecolor support
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    # Theme colors (RGB)
    PURPLE='\033[1;38;2;139;92;246m'      # Opus
    ORANGE='\033[1;38;2;255;140;0m'       # Sonnet
    TEAL='\033[1;38;2;0;188;212m'         # Haiku
    SLATE='\033[1;38;2;148;163;184m'      # Muted
    # Health colors
    GREEN='\033[1;38;2;34;197;94m'
    YELLOW='\033[1;38;2;234;179;8m'
    RED='\033[1;38;2;239;68;68m'
else
    # 256-color fallback
    PURPLE='\033[1;38;5;141m'
    ORANGE='\033[1;38;5;208m'
    TEAL='\033[1;38;5;44m'
    SLATE='\033[1;38;5;248m'
    GREEN='\033[1;38;5;35m'
    YELLOW='\033[1;38;5;220m'
    RED='\033[1;38;5;196m'
fi

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
MASTER_CONFIG="$HOME/.claude/statusline-project.json"

# ============================================
# DEFAULTS
# ============================================
PLAN="api"
TRACKING_ENABLED=true
AUTO_CREATE_MODE="claude_folder"  # never, git_only, claude_folder, git_and_claude, always
CREATE_MASTER=true
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
    echo -e "  ${PURPLE}│${RESET} 📁 ${CYAN}my-project${RESET}"
    echo -e "  ${PURPLE}│${RESET} ${BLUE}⚙ main${RESET} ${GREEN}↑2${RESET} ${GREEN}●3${RESET} ${YELLOW}~5${RESET} ${SLATE}?7${RESET} ${GREEN}12m${RESET}"
    echo -e "  ${PURPLE}│${RESET} ⏱ ${PURPLE}45m${RESET} 💬${CYAN}12${RESET} ${PURPLE}+156${RED}-23${RESET} ${PURPLE}※a1b2c3${RESET}"
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
    [[ -f "$MASTER_CONFIG" ]] && echo -e "  ${GREEN}│${RESET}    ${SLATE}•${RESET} ${CYAN}~/.claude/statusline-project.json${RESET} ${DIM}(MASTER)${RESET}"
    [[ "$CREATE_UMBRELLA" == "true" ]] && echo -e "  ${GREEN}│${RESET}    ${SLATE}•${RESET} ${CYAN}.claude/statusline-project.json${RESET} ${DIM}(umbrella)${RESET}"
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
    print_step 1 7 "Claude Plan"
    echo -e "      ${DIM}Affects cost calculations${RESET}"
    local plan_choice
    plan_choice=$(ask_choice "Select your plan:" "api - Pay per use" "max5x - Pro 5x" "max20x - Pro 20x")
    case "$plan_choice" in
        "api"*) PLAN="api" ;;
        "max5x"*) PLAN="max5x" ;;
        "max20x"*) PLAN="max20x" ;;
    esac
    print_success "Plan: ${ORANGE}$PLAN${RESET}"

    print_step 2 7 "Cost Tracking"
    if ask_yes_no "Track costs per project?"; then
        TRACKING_ENABLED=true
        print_success "Cost tracking ${GREEN}enabled${RESET}"
    else
        TRACKING_ENABLED=false
        print_info "Cost tracking ${SLATE}disabled${RESET}"
    fi

    if [[ "$TRACKING_ENABLED" == "true" ]]; then
        print_step 3 7 "MASTER Root"
        echo -e "      ${DIM}Global tracker at ~/.claude/ - catches all projects without a parent${RESET}"
        if [[ -f "$MASTER_CONFIG" ]]; then
            print_info "MASTER already exists: ${CYAN}$MASTER_CONFIG${RESET}"
            CREATE_MASTER=false
        else
            echo -e "      ${DIM}Tracks total Claude usage across ALL projects${RESET}"
            echo -e "      ${DIM}Skip if you want isolated project groups instead${RESET}"
            if ask_yes_no "Create MASTER root? ${DIM}(recommended)${RESET}"; then
                CREATE_MASTER=true
                print_success "Will create MASTER root"
            else
                CREATE_MASTER=false
                print_info "Skipped - projects won't roll up to global tracker"
            fi
        fi

        print_step 4 7 "Auto-Create Settings"
        echo -e "      ${DIM}When to auto-create statusline project configs${RESET}"
        echo -e "      ${DIM}(Projects are 'born' into the tree when conditions are met)${RESET}"
        local mode_choice
        mode_choice=$(ask_choice "Auto-create mode:" \
            "claude_folder - When .claude/ folder exists (default)" \
            "git_only - Only in git repositories" \
            "git_and_claude - Both git repo AND .claude/ required" \
            "never - Manual only (use --init)")
        case "$mode_choice" in
            "claude_folder"*) AUTO_CREATE_MODE="claude_folder" ;;
            "git_only"*) AUTO_CREATE_MODE="git_only" ;;
            "git_and_claude"*) AUTO_CREATE_MODE="git_and_claude" ;;
            "never"*) AUTO_CREATE_MODE="never" ;;
        esac
        print_success "Auto-create: ${ORANGE}$AUTO_CREATE_MODE${RESET}"

        print_step 5 7 "Umbrella Project"
        echo -e "      ${DIM}Track costs across sub-projects in current dir${RESET}"
        if ask_yes_no "Create umbrella project here?" "n"; then
            CREATE_UMBRELLA=true
            print_success "Will create umbrella config"
        fi
    else
        print_step 3 7 "Skipped ${DIM}(tracking disabled)${RESET}"
        print_step 4 7 "Skipped ${DIM}(tracking disabled)${RESET}"
        print_step 5 7 "Skipped ${DIM}(tracking disabled)${RESET}"
        CREATE_MASTER=false
    fi

    print_step 6 7 "Display Options"
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

    print_step 7 7 "Install"
}

create_config() {
    local config_path="$INSTALL_DIR/$CONFIG_NAME"

    cat > "$config_path" << EOF
{
  "version": 1,
  "plan": "$PLAN",
  "tracking": {
    "enabled": $TRACKING_ENABLED,
    "auto_create_mode": "$AUTO_CREATE_MODE",
    "auto_create_umbrella": false
  },
  "display": {
    "pulse_animation": $PULSE_ANIMATION,
    "cost_cycling": $COST_CYCLING,
    "path_cycling": true,
    "path_style": 0
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

create_master() {
    [[ "$CREATE_MASTER" != "true" ]] && return
    [[ -f "$MASTER_CONFIG" ]] && return  # Already exists

    cat > "$MASTER_CONFIG" << 'EOF'
{
  "name": "Claude Master Statusline",
  "icon": "🏠",
  "color": "#8B5CF6",
  "git": null,
  "parent": null,
  "costs": {
    "sessions": {},
    "total": 0,
    "session_count": 0,
    "projects": {}
  }
}
EOF

    print_success "MASTER root created: ${CYAN}~/.claude/statusline-project.json${RESET}"
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

    local target="$INSTALL_DIR/$SCRIPT_NAME"

    # Backup existing script before overwriting
    if [[ -f "$target" ]]; then
        local backup="${target}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$target" "$backup"
        print_info "Backed up existing script to ${DIM}$(basename "$backup")${RESET}"
    fi

    if [[ -f "$SCRIPT_DIR/$SCRIPT_NAME" ]]; then
        cp "$SCRIPT_DIR/$SCRIPT_NAME" "$target"
    else
        print_error "Script not found: $SCRIPT_DIR/$SCRIPT_NAME"
        exit 1
    fi

    chmod +x "$target"
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
# PROJECT INIT FUNCTIONS
# ============================================

# Find parent umbrella project (falls back to MASTER)
find_parent_umbrella() {
    local dir="$1"
    local parent_dir=$(dirname "$dir")
    local depth=0
    while [[ "$parent_dir" != "/" && $depth -lt 5 ]]; do
        if [[ -f "$parent_dir/.claude/statusline-project.json" ]]; then
            echo "$parent_dir/.claude/statusline-project.json"
            return
        fi
        parent_dir=$(dirname "$parent_dir")
        ((depth++))
    done
    # Fall back to MASTER if it exists
    [[ -f "$MASTER_CONFIG" ]] && echo "$MASTER_CONFIG"
}

# Initialize MASTER root at ~/.claude
init_master_project() {
    echo ""
    if [[ -f "$MASTER_CONFIG" ]]; then
        print_warn "MASTER root already exists: $MASTER_CONFIG"
        if ! ask_yes_no "Overwrite?" "n"; then
            exit 0
        fi
    fi

    mkdir -p "$INSTALL_DIR" || { print_error "Cannot create ~/.claude directory"; exit 1; }

    cat > "$MASTER_CONFIG" << 'EOF'
{
  "name": "Claude Master Statusline",
  "icon": "🏠",
  "color": "#8B5CF6",
  "git": null,
  "parent": null,
  "costs": {
    "sessions": {},
    "total": 0,
    "session_count": 0,
    "projects": {}
  }
}
EOF

    print_success "Created MASTER root: ${CYAN}$MASTER_CONFIG${RESET}"
    print_info "All projects without a closer parent will roll up here"
    echo ""
}

# Initialize umbrella project
init_umbrella_project() {
    local target="${1:-$PWD}"
    target=$(cd "$target" 2>/dev/null && pwd) || { print_error "Directory not found: $1"; exit 1; }

    local config="$target/.claude/statusline-project.json"

    echo ""
    if [[ -f "$config" ]]; then
        print_warn "Project config already exists: $config"
        if ! ask_yes_no "Overwrite?" "n"; then
            exit 0
        fi
    fi

    mkdir -p "$target/.claude" || { print_error "Cannot create .claude directory"; exit 1; }

    local folder_name=$(basename "$target")

    # Link to MASTER if it exists
    local parent_json="null"
    [[ -f "$MASTER_CONFIG" ]] && parent_json="\"$MASTER_CONFIG\""

    cat > "$config" << EOF
{
  "name": "$folder_name",
  "icon": "🌌",
  "color": null,
  "git": null,
  "parent": $parent_json
}
EOF

    print_success "Created umbrella project: ${CYAN}$config${RESET}"
    [[ -f "$MASTER_CONFIG" ]] && print_info "Linked to MASTER: ${CYAN}$MASTER_CONFIG${RESET}"
    print_info "Sub-projects in ${CYAN}$target/*${RESET} will auto-link to this umbrella"
    echo ""
}

# Initialize regular project
init_regular_project() {
    local target="${1:-$PWD}"
    target=$(cd "$target" 2>/dev/null && pwd) || { print_error "Directory not found: $1"; exit 1; }

    local config="$target/.claude/statusline-project.json"

    echo ""
    if [[ -f "$config" ]]; then
        print_warn "Project config already exists: $config"
        if ! ask_yes_no "Overwrite?" "n"; then
            exit 0
        fi
    fi

    mkdir -p "$target/.claude" || { print_error "Cannot create .claude directory"; exit 1; }

    local folder_name=$(basename "$target")
    local git_remote=$(git -C "$target" remote get-url origin 2>/dev/null | sed 's|git@\([^:]*\):|https://\1/|;s|\.git$||')
    local parent_config=$(find_parent_umbrella "$target")

    # Format JSON values
    local git_json="null"
    local parent_json="null"
    [[ -n "$git_remote" ]] && git_json="\"$git_remote\""
    [[ -n "$parent_config" ]] && parent_json="\"$parent_config\""

    cat > "$config" << EOF
{
  "name": "$folder_name",
  "icon": "📁",
  "color": null,
  "git": $git_json,
  "parent": $parent_json
}
EOF

    print_success "Created project: ${CYAN}$config${RESET}"
    [[ -n "$git_remote" ]] && print_info "Git: ${CYAN}$git_remote${RESET}"
    if [[ -n "$parent_config" ]]; then
        print_info "Linked to umbrella: ${CYAN}$parent_config${RESET}"
    else
        print_info "No parent umbrella found ${DIM}(costs tracked locally only)${RESET}"
    fi
    echo ""
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
        create_master
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
    --init-master)
        init_master_project
        ;;
    --init-umbrella)
        init_umbrella_project "${2:-}"
        ;;
    --init-project)
        init_regular_project "${2:-}"
        ;;
    --help|-h)
        echo ""
        echo -e "  ${BOLD}Claude Code Statusline Installer${RESET}"
        echo ""
        echo -e "  ${DIM}Usage:${RESET} ./install.sh [option]"
        echo ""
        echo -e "  ${DIM}Install Options:${RESET}"
        echo -e "    ${SLATE}(none)${RESET}          Interactive installation"
        echo -e "    ${SLATE}--defaults${RESET}      Install with defaults"
        echo -e "    ${SLATE}--update${RESET}        Update script only"
        echo -e "    ${SLATE}--uninstall${RESET}     Remove everything"
        echo ""
        echo -e "  ${DIM}Project Hierarchy:${RESET}"
        echo -e "    ${SLATE}--init-master${RESET}           Create MASTER root (~/.claude) - tracks all usage"
        echo -e "    ${SLATE}--init-umbrella [path]${RESET}  Create umbrella project (links to MASTER)"
        echo -e "    ${SLATE}--init-project [path]${RESET}   Create sub-project (links to umbrella/MASTER)"
        echo ""
        echo -e "  ${DIM}Other:${RESET}"
        echo -e "    ${SLATE}--preview${RESET}       Preview statusline appearance"
        echo -e "    ${SLATE}--help${RESET}          Show this help"
        echo ""
        echo -e "  ${DIM}Examples:${RESET}"
        echo -e "    ${CYAN}./install.sh${RESET}                            ${DIM}# Interactive install${RESET}"
        echo -e "    ${CYAN}./install.sh --init-master${RESET}              ${DIM}# Create MASTER root${RESET}"
        echo -e "    ${CYAN}./install.sh --init-umbrella ~/projects${RESET} ${DIM}# Create umbrella${RESET}"
        echo -e "    ${CYAN}./install.sh --init-project ~/projects/app${RESET} ${DIM}# Create project${RESET}"
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
        create_master
        create_umbrella
        update_settings
        print_complete
        ;;
esac
