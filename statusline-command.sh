#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Claude Code Statusline v2.0                                              ║
# ║  A dynamic 4/5-line statusline with project cost tracking                 ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║  Features:                                                                ║
# ║  • Model-specific themes (Opus/Sonnet/Haiku)                              ║
# ║  • Hierarchical cost tracking (MASTER → Umbrella → Project)               ║
# ║  • Session attribution with breakdown structure                           ║
# ║  • Git integration with health-colored staleness                          ║
# ║  • Animated pulse with truecolor/256-color support                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ============================================
# CLI MODE
# ============================================
# Handles: --init-master, --init-umbrella, --init-project, --sync, --dedicate, --help
# These run BEFORE reading stdin and exit immediately

# --- CLI Output Colors ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[1;36m'

# Detect truecolor for CLI output (separate from statusline detection)
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    PURPLE='\033[1;38;2;139;92;246m'
    GREEN='\033[1;38;2;34;197;94m'
    YELLOW='\033[1;38;2;234;179;8m'
    SLATE='\033[1;38;2;148;163;184m'
else
    PURPLE='\033[1;38;5;141m'   # 256-color purple
    GREEN='\033[1;38;5;35m'     # 256-color green
    YELLOW='\033[1;38;5;220m'   # 256-color yellow
    SLATE='\033[1;38;5;248m'    # 256-color gray
fi

# --- CLI Output Helpers ---
cli_print_success() { echo -e "  ${GREEN}✓${RESET} $1"; }
cli_print_info() { echo -e "  ${CYAN}→${RESET} $1"; }
cli_print_warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
cli_print_error() { echo -e "  ${PURPLE}✗${RESET} $1"; }

# --- Hierarchy Constants ---
MASTER_CONFIG="$HOME/.claude/statusline-project.json"  # Top of the tree

# --- CLI Helper: Find Parent ---
# Walks up directory tree (max 5 levels) to find nearest umbrella/parent project
# Falls back to MASTER root if no closer parent found
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
    # Fall back to MASTER root if it exists
    [[ -f "$MASTER_CONFIG" ]] && echo "$MASTER_CONFIG"
}

# --- CLI Command: --init-master ---
# Creates the MASTER root at ~/.claude/statusline-project.json
# All projects without a closer parent roll up here
init_master() {
    local config="$MASTER_CONFIG"

    if [[ -f "$config" ]]; then
        cli_print_warn "MASTER root already exists: $config"
        echo -ne "  ${SLATE}Overwrite? [y/N]:${RESET} "
        read -r response
        [[ ! "$response" =~ ^[Yy] ]] && exit 0
    fi

    mkdir -p "$HOME/.claude" || { cli_print_error "Cannot create ~/.claude directory"; exit 1; }

    cat > "$config" << 'EOF'
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

    cli_print_success "Created MASTER root: ${CYAN}$config${RESET}"
    cli_print_info "All projects without a closer parent will roll up here"
    exit 0
}

# --- CLI Command: --init-umbrella ---
# Creates an umbrella project (parent for multiple sub-projects)
# Sub-projects auto-link to nearest umbrella when created
init_umbrella() {
    local target="${1:-$PWD}"
    target=$(cd "$target" 2>/dev/null && pwd) || { cli_print_error "Directory not found: $1"; exit 1; }

    local config="$target/.claude/statusline-project.json"

    if [[ -f "$config" ]]; then
        cli_print_warn "Project config already exists: $config"
        echo -ne "  ${SLATE}Overwrite? [y/N]:${RESET} "
        read -r response
        [[ ! "$response" =~ ^[Yy] ]] && exit 0
    fi

    mkdir -p "$target/.claude" || { cli_print_error "Cannot create .claude directory"; exit 1; }

    local folder_name=$(basename "$target")

    cat > "$config" << EOF
{
  "name": "$folder_name",
  "icon": "🌌",
  "color": null,
  "git": null,
  "parent": null
}
EOF

    cli_print_success "Created umbrella project: ${CYAN}$config${RESET}"
    cli_print_info "Sub-projects in ${CYAN}$target/*${RESET} will auto-link to this umbrella"
    exit 0
}

# --- CLI Command: --init-project ---
# Creates a regular project config with auto-detected git remote and parent
init_project() {
    local target="${1:-$PWD}"
    target=$(cd "$target" 2>/dev/null && pwd) || { cli_print_error "Directory not found: $1"; exit 1; }

    local config="$target/.claude/statusline-project.json"

    if [[ -f "$config" ]]; then
        cli_print_warn "Project config already exists: $config"
        echo -ne "  ${SLATE}Overwrite? [y/N]:${RESET} "
        read -r response
        [[ ! "$response" =~ ^[Yy] ]] && exit 0
    fi

    mkdir -p "$target/.claude" || { cli_print_error "Cannot create .claude directory"; exit 1; }

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

    cli_print_success "Created project: ${CYAN}$config${RESET}"
    [[ -n "$git_remote" ]] && cli_print_info "Git: ${CYAN}$git_remote${RESET}"
    if [[ -n "$parent_config" ]]; then
        cli_print_info "Linked to umbrella: ${CYAN}$parent_config${RESET}"
    else
        cli_print_info "No parent umbrella found ${DIM}(costs tracked locally only)${RESET}"
    fi
    exit 0
}

# --- CLI Command: --sync ---
# Syncs project costs with actual session data from state files
# Also migrates Phase 1 sessions (contributed) to Phase 2 (breakdown)
sync_project() {
    local target="${1:-$PWD}"
    target=$(cd "$target" 2>/dev/null && pwd) || { cli_print_error "Directory not found: $1"; exit 1; }

    local config="$target/.claude/statusline-project.json"
    [[ ! -f "$config" ]] && { cli_print_error "No project config found: $config"; exit 1; }

    local cache_dir="$HOME/.cache/claude-statusline"
    local parent=$(jq -r '.parent // empty' "$config" 2>/dev/null)
    local project_name=$(jq -r '.name // "unknown"' "$config" 2>/dev/null)

    # If sub-project, sync to umbrella instead
    if [[ -n "$parent" && -f "$parent" ]]; then
        cli_print_info "Sub-project detected: ${CYAN}$project_name${RESET}"
        cli_print_info "Syncing umbrella: ${CYAN}$parent${RESET}"
        config="$parent"
        project_name=$(jq -r '.name // "unknown"' "$config" 2>/dev/null)
    fi

    echo -e "\n  ${BOLD}Syncing: $project_name (Phase 2)${RESET}\n"

    # Read all sessions from config
    local sessions=$(jq -r '.costs.sessions // {} | keys[]' "$config" 2>/dev/null)
    [[ -z "$sessions" ]] && { cli_print_warn "No sessions found in project config"; exit 0; }

    local updated=0
    local migrated=0
    local total_diff=0
    local updated_config=$(cat "$config")

    while IFS= read -r session_id; do
        [[ -z "$session_id" ]] && continue

        # Look for state file in cache
        local state_file="$cache_dir/session-${session_id}.state"
        local actual_cost=""

        if [[ -f "$state_file" ]]; then
            # State file format: cost|session_home_config
            actual_cost=$(cut -d'|' -f1 < "$state_file" 2>/dev/null)
        fi

        # Get current recorded cost (Phase 2: total_cost or contributed for backward compat)
        local recorded=$(echo "$updated_config" | jq -r ".costs.sessions[\"$session_id\"].total_cost // .costs.sessions[\"$session_id\"].contributed // 0")
        [[ "$recorded" == "null" ]] && recorded=0

        # Check if session has breakdown or needs migration
        local has_breakdown=$(echo "$updated_config" | jq -r ".costs.sessions[\"$session_id\"].breakdown // empty")

        if [[ -z "$has_breakdown" ]]; then
            # Migrate: old contributed -> breakdown._self
            local old_contributed=$(echo "$updated_config" | jq -r ".costs.sessions[\"$session_id\"].contributed // 0")
            local dedicated_to=$(echo "$updated_config" | jq -r ".costs.sessions[\"$session_id\"].dedicated_to // empty")

            printf "  ${CYAN}↑${RESET} Session ${DIM}${session_id:0:8}${RESET}: migrating to Phase 2 breakdown"

            if [[ -n "$dedicated_to" ]]; then
                # Was dedicated: put full amount in breakdown[dedicated_to]
                printf " ${DIM}(dedicated to ${dedicated_to})${RESET}\n"
                local migrate_amount="$old_contributed"
                [[ -n "$actual_cost" && "$actual_cost" != "0" ]] && migrate_amount="$actual_cost"
                updated_config=$(echo "$updated_config" | jq --arg sid "$session_id" --arg child "$dedicated_to" --argjson amt "$migrate_amount" '
                    .costs.sessions[$sid].breakdown = { "_self": 0, ($child): $amt } |
                    .costs.sessions[$sid].total_cost = $amt
                ')
            else
                # Not dedicated: put in breakdown._self
                printf "\n"
                local migrate_amount="$old_contributed"
                [[ -n "$actual_cost" && "$actual_cost" != "0" ]] && migrate_amount="$actual_cost"
                updated_config=$(echo "$updated_config" | jq --arg sid "$session_id" --argjson amt "$migrate_amount" '
                    .costs.sessions[$sid].breakdown = { "_self": $amt } |
                    .costs.sessions[$sid].total_cost = $amt
                ')
            fi
            ((migrated++))
            continue
        fi

        # Session has breakdown - check if needs sync
        if [[ -z "$actual_cost" || "$actual_cost" == "0" ]]; then
            printf "  ${YELLOW}!${RESET} Session ${DIM}${session_id:0:8}${RESET}: no state file found, skipping\n"
            continue
        fi

        # Calculate difference
        local diff=$(echo "$actual_cost - $recorded" | bc -l 2>/dev/null || echo "0")

        # Check if significant difference (> $0.01)
        if (( $(echo "${diff#-} > 0.01" | bc -l 2>/dev/null || echo 0) )); then
            printf "  ${CYAN}→${RESET} Session ${DIM}${session_id:0:8}${RESET}: "
            printf "${YELLOW}\$%.2f${RESET} → ${GREEN}\$%.2f${RESET} " "$recorded" "$actual_cost"
            if (( $(echo "$diff > 0" | bc -l) )); then
                printf "${GREEN}(+\$%.2f)${RESET}\n" "$diff"
                # Add difference to _self (unattributed new cost)
                updated_config=$(echo "$updated_config" | jq --arg sid "$session_id" --argjson diff "$diff" '
                    .costs.sessions[$sid].breakdown._self = ((.costs.sessions[$sid].breakdown._self // 0) + $diff) |
                    .costs.sessions[$sid].total_cost = ([.costs.sessions[$sid].breakdown // {} | to_entries[].value] | add // 0)
                ')
            else
                printf "${YELLOW}(\$%.2f)${RESET}\n" "$diff"
            fi
            ((updated++))
            total_diff=$(echo "$total_diff + $diff" | bc -l 2>/dev/null || echo "$total_diff")
        else
            printf "  ${GREEN}✓${RESET} Session ${DIM}${session_id:0:8}${RESET}: \$%.2f ${DIM}(in sync)${RESET}\n" "$recorded"
        fi
    done <<< "$sessions"

    echo ""

    if [[ $updated -gt 0 || $migrated -gt 0 ]]; then
        # Recalculate total (sum sessions total_cost/contributed + projects contributions)
        updated_config=$(echo "$updated_config" | jq '
            .costs.total = (
                ([.costs.sessions // {} | to_entries[].value.total_cost // .value.contributed // 0] | add // 0) +
                ([.costs.projects // {} | to_entries[].value.contributed // 0] | add // 0)
            ) |
            .costs.last_updated = (now | todate)
        ')

        local new_total=$(echo "$updated_config" | jq -r '.costs.total // 0')

        # Write updated config
        echo "$updated_config" > "$config"

        if [[ $migrated -gt 0 ]]; then
            printf "  ${GREEN}✓${RESET} Migrated ${BOLD}%d${RESET} sessions to Phase 2 breakdown\n" "$migrated"
        fi
        if [[ $updated -gt 0 ]]; then
            printf "  ${GREEN}✓${RESET} Synced ${BOLD}%d${RESET} sessions, " "$updated"
            if (( $(echo "$total_diff > 0" | bc -l) )); then
                printf "added ${GREEN}\$%.2f${RESET}\n" "$total_diff"
            else
                printf "adjusted ${YELLOW}\$%.2f${RESET}\n" "$total_diff"
            fi
        fi
        printf "  ${GREEN}✓${RESET} New total: ${BOLD}\$%.2f${RESET}\n\n" "$new_total"
    else
        cli_print_success "All sessions already in sync"
        echo ""
    fi

    exit 0
}

# --- CLI Command: --dedicate ---
# Moves a session's _self breakdown amount to a specified child project
# Use when work done at umbrella level was actually for a specific sub-project
dedicate_session() {
    local session_short="${1:-}"
    local target_project="${2:-$PWD}"

    [[ -z "$session_short" ]] && { cli_print_error "Usage: --dedicate <session-id> [project-path]"; exit 1; }

    # Find full session ID from short form
    local cache_dir="$HOME/.cache/claude-statusline"
    local state_file=$(ls "$cache_dir"/session-*"$session_short"*.state 2>/dev/null | head -1)

    if [[ -z "$state_file" || ! -f "$state_file" ]]; then
        cli_print_error "Session not found: $session_short"
        cli_print_info "Available sessions:"
        ls "$cache_dir"/session-*.state 2>/dev/null | sed 's|.*/session-||;s|\.state||' | while read sid; do
            echo -e "    ${DIM}${sid:0:8}${RESET}"
        done
        exit 1
    fi

    local session_id=$(basename "$state_file" | sed 's/session-//;s/\.state//')
    local actual_cost=$(cut -d'|' -f1 < "$state_file")
    local session_home=$(cut -d'|' -f2 < "$state_file")

    # Find target project (child to dedicate to)
    target_project=$(cd "$target_project" 2>/dev/null && pwd) || { cli_print_error "Directory not found: $2"; exit 1; }
    local project_config="$target_project/.claude/statusline-project.json"
    [[ ! -f "$project_config" ]] && { cli_print_error "No project config at: $project_config"; exit 1; }

    local child_name=$(jq -r '.name // "unknown"' "$project_config")

    # Session must exist in session_home
    [[ ! -f "$session_home" ]] && { cli_print_error "Session home not found: $session_home"; exit 1; }

    local home_name=$(jq -r '.name // "unknown"' "$session_home")

    echo -e "\n  ${BOLD}Dedicate Session (Phase 2)${RESET}\n"
    echo -e "  Session:      ${CYAN}${session_id:0:8}${RESET}"
    echo -e "  Session home: ${CYAN}${home_name}${RESET}"
    echo -e "  Dedicate to:  ${CYAN}${child_name}${RESET}"

    # Get current breakdown
    local self_amount=$(jq -r ".costs.sessions[\"$session_id\"].breakdown._self // .costs.sessions[\"$session_id\"].contributed // 0" "$session_home")
    local child_current=$(jq -r ".costs.sessions[\"$session_id\"].breakdown[\"$child_name\"] // 0" "$session_home")
    local total_cost_session=$(jq -r ".costs.sessions[\"$session_id\"].total_cost // .costs.sessions[\"$session_id\"].contributed // 0" "$session_home")

    echo ""
    echo -e "  ${DIM}Current breakdown:${RESET}"
    printf "    _self:        ${YELLOW}\$%.2f${RESET}\n" "$self_amount"
    printf "    ${child_name}: ${YELLOW}\$%.2f${RESET}\n" "$child_current"
    printf "    Total cost:   ${GREEN}\$%.2f${RESET}\n" "$total_cost_session"
    echo ""

    if (( $(echo "$self_amount == 0" | bc -l) )); then
        cli_print_warn "No _self amount to dedicate (already 0)"
        exit 0
    fi

    # Confirm
    printf "  ${SLATE}Move \$%.2f from _self to ${child_name}? [y/N]:${RESET} " "$self_amount"
    read -r response
    [[ ! "$response" =~ ^[Yy] ]] && { echo "  Cancelled."; exit 0; }

    echo ""

    # Update session_home: move _self to child in breakdown
    cli_print_info "Updating ${home_name}..."
    local updated=$(jq --arg sid "$session_id" --arg child "$child_name" '
        # Move _self to child
        .costs.sessions[$sid].breakdown[$child] = ((.costs.sessions[$sid].breakdown[$child] // 0) + (.costs.sessions[$sid].breakdown._self // .costs.sessions[$sid].contributed // 0)) |
        .costs.sessions[$sid].breakdown._self = 0 |
        # Recalculate total_cost (should stay the same)
        .costs.sessions[$sid].total_cost = ([.costs.sessions[$sid].breakdown // {} | to_entries[].value] | add // 0) |
        .costs.sessions[$sid].updated = (now | todate) |
        # Update projects tracking
        .costs.projects[$child].sessions = ((.costs.projects[$child].sessions // []) + [$sid] | unique) |
        .costs.last_updated = (now | todate)
    ' "$session_home")
    echo "$updated" > "$session_home"

    # Show new state
    local new_self=$(echo "$updated" | jq -r ".costs.sessions[\"$session_id\"].breakdown._self")
    local new_child=$(echo "$updated" | jq -r ".costs.sessions[\"$session_id\"].breakdown[\"$child_name\"]")

    echo ""
    cli_print_success "Dedicated _self to ${child_name}"
    printf "  ${GREEN}✓${RESET} _self:        ${BOLD}\$%.2f${RESET}\n" "$new_self"
    printf "  ${GREEN}✓${RESET} ${child_name}: ${BOLD}\$%.2f${RESET}\n" "$new_child"
    echo ""

    exit 0
}

# --- CLI Command: --help ---
show_cli_help() {
    echo ""
    echo -e "  ${BOLD}Claude Code Statusline${RESET} ${DIM}v2.0${RESET}"
    echo ""
    echo -e "  ${DIM}Usage:${RESET}"
    echo -e "    ${SLATE}(stdin)${RESET}           Normal statusline mode (receives JSON from Claude Code)"
    echo -e "    ${SLATE}--init-master${RESET}     Create MASTER root at ~/.claude (top of hierarchy)"
    echo -e "    ${SLATE}--init-umbrella${RESET}   Create umbrella/parent project config"
    echo -e "    ${SLATE}--init-project${RESET}    Create project config in current or specified directory"
    echo -e "    ${SLATE}--sync${RESET}            Sync project costs with actual transcript data"
    echo -e "    ${SLATE}--dedicate${RESET}        Dedicate a session's full cost to a project"
    echo -e "    ${SLATE}--help${RESET}            Show this help"
    echo ""
    echo -e "  ${DIM}Examples:${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --init-master${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --init-umbrella ~/projects${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --init-project${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --sync${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --dedicate a3013a${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --dedicate a3013a ~/projects/my-app${RESET}"
    echo ""
    exit 0
}

# --- CLI Argument Router ---
case "${1:-}" in
    --init-master)   init_master ;;
    --init-umbrella) init_umbrella "${2:-}" ;;
    --init-project)  init_project "${2:-}" ;;
    --sync)          sync_project "${2:-}" ;;
    --dedicate)      dedicate_session "${2:-}" "${3:-}" ;;
    --help|-h)       show_cli_help ;;
esac

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  STATUSLINE MODE - Receives JSON from Claude Code via stdin               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

input=$(cat)

# Debug mode: dump raw JSON (set STATUSLINE_DEBUG=1 to enable)
[[ "${STATUSLINE_DEBUG:-0}" == "1" ]] && mkdir -p "$HOME/.cache/claude-statusline" && echo "$input" > "$HOME/.cache/claude-statusline/debug-input.json"

# --- Parse Input JSON ---
model_name=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir')
session_id=$(echo "$input" | jq -r '.session_id')
transcript_path=$(echo "$input" | jq -r '.transcript_path')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
total_duration=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
token_warning=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')

# --- Cache Directory ---
CACHE_DIR="$HOME/.cache/claude-statusline"
mkdir -p "$CACHE_DIR"

# --- Configuration ---
# All settings are optional; defaults used if config file absent
CONFIG_FILE="$HOME/.claude/statusline-config.json"

# Default values
TRACKING_ENABLED=true
AUTO_CREATE_MODE="claude_folder"  # never, git_only, claude_folder, git_and_claude, always
AUTO_CREATE_UMBRELLA=false
PULSE_ANIMATION=true
COST_CYCLING=true
PATH_CYCLING=true
PATH_STYLE=0  # 0=forward, 1=project+depth, 2=reverse

# Health colors - RGB values
HEALTH_GOOD_RGB=(34 197 94)      # Green  #22C55E
HEALTH_WARN_RGB=(234 179 8)      # Yellow #EAB308
HEALTH_CRIT_RGB=(239 68 68)      # Red    #EF4444

# Thresholds
CONTEXT_WARN=50
CONTEXT_CRIT=75
MEMORY_WARN=4
MEMORY_CRIT=8
STALENESS_WARN=100
STALENESS_CRIT=500

# Load config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    TRACKING_ENABLED=$(jq -r '.tracking.enabled // true' "$CONFIG_FILE")

    AUTO_CREATE_MODE=$(jq -r '.tracking.auto_create_mode // "claude_folder"' "$CONFIG_FILE")

    AUTO_CREATE_UMBRELLA=$(jq -r '.tracking.auto_create_umbrella // false' "$CONFIG_FILE")
    PULSE_ANIMATION=$(jq -r '.display.pulse_animation // true' "$CONFIG_FILE")
    COST_CYCLING=$(jq -r '.display.cost_cycling // true' "$CONFIG_FILE")
    PATH_CYCLING=$(jq -r '.display.path_cycling // true' "$CONFIG_FILE")
    PATH_STYLE=$(jq -r '.display.path_style // 0' "$CONFIG_FILE")

    # Health colors from config
    if jq -e '.health_colors.good' "$CONFIG_FILE" > /dev/null 2>&1; then
        HEALTH_GOOD_RGB=($(jq -r '.health_colors.good | @sh' "$CONFIG_FILE" | tr -d "'"))
    fi
    if jq -e '.health_colors.warn' "$CONFIG_FILE" > /dev/null 2>&1; then
        HEALTH_WARN_RGB=($(jq -r '.health_colors.warn | @sh' "$CONFIG_FILE" | tr -d "'"))
    fi
    if jq -e '.health_colors.crit' "$CONFIG_FILE" > /dev/null 2>&1; then
        HEALTH_CRIT_RGB=($(jq -r '.health_colors.crit | @sh' "$CONFIG_FILE" | tr -d "'"))
    fi

    # Thresholds from config
    CONTEXT_WARN=$(jq -r '.thresholds.context_warn // 50' "$CONFIG_FILE")
    CONTEXT_CRIT=$(jq -r '.thresholds.context_crit // 75' "$CONFIG_FILE")
    MEMORY_WARN=$(jq -r '.thresholds.memory_warn // 4' "$CONFIG_FILE")
    MEMORY_CRIT=$(jq -r '.thresholds.memory_crit // 8' "$CONFIG_FILE")
    STALENESS_WARN=$(jq -r '.thresholds.staleness_warn // 100' "$CONFIG_FILE")
    STALENESS_CRIT=$(jq -r '.thresholds.staleness_crit // 500' "$CONFIG_FILE")
fi

# Plan: env var takes precedence over config
CLAUDE_PLAN="${CLAUDE_PLAN:-$(jq -r '.plan // "api"' "$CONFIG_FILE" 2>/dev/null || echo "api")}"

# --- Colors & Truecolor Detection ---
# Truecolor (24-bit RGB) vs 256-color palette fallback for Terminal.app
RESET='\033[0m'
DIM='\033[2m'
B_CYAN='\033[1;36m'
B_BLUE='\033[1;34m'
B_RED='\033[1;31m'
B_YELLOW='\033[1;33m'
B_MAGENTA='\033[1;35m'

# Detect truecolor support (iTerm2, Kitty, etc set this)
TRUECOLOR_SUPPORT=0
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    TRUECOLOR_SUPPORT=1
fi

# Muted colors - use 256-color fallback if no truecolor
if [[ $TRUECOLOR_SUPPORT -eq 1 ]]; then
    MUTED_SLATE='\033[1;38;2;148;163;184m'  # Bold Slate-400 #94A3B8
else
    MUTED_SLATE='\033[1;38;5;248m'  # 256-color approximation
fi

# Health colors - truecolor or 256-color fallback
if [[ $TRUECOLOR_SUPPORT -eq 1 ]]; then
    HEALTH_GOOD="\033[1;38;2;${HEALTH_GOOD_RGB[0]};${HEALTH_GOOD_RGB[1]};${HEALTH_GOOD_RGB[2]}m"
    HEALTH_WARN="\033[1;38;2;${HEALTH_WARN_RGB[0]};${HEALTH_WARN_RGB[1]};${HEALTH_WARN_RGB[2]}m"
    HEALTH_CRIT="\033[1;38;2;${HEALTH_CRIT_RGB[0]};${HEALTH_CRIT_RGB[1]};${HEALTH_CRIT_RGB[2]}m"
else
    # 256-color palette approximations
    HEALTH_GOOD='\033[1;38;5;44m'   # Cyan-ish (good)
    HEALTH_WARN='\033[1;38;5;214m'  # Orange-ish (warning)
    HEALTH_CRIT='\033[1;38;5;196m'  # Red (critical)
fi

# Get health color based on value and thresholds
# reverse=1 means higher values are worse (e.g., context %)
get_health_color() {
    local val="$1" warn="$2" crit="$3" reverse="${4:-0}"
    if [[ $reverse -eq 1 ]]; then
        [[ $val -ge $crit ]] && echo "$HEALTH_CRIT" && return
        [[ $val -ge $warn ]] && echo "$HEALTH_WARN" && return
    else
        [[ $val -le $crit ]] && echo "$HEALTH_CRIT" && return
        [[ $val -le $warn ]] && echo "$HEALTH_WARN" && return
    fi
    echo "$HEALTH_GOOD"
}

# Format large numbers (1234 → 1.2K)
format_num() {
    local n="$1"
    if [[ $n -ge 1000000 ]]; then
        printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc)"
    elif [[ $n -ge 1000 ]]; then
        printf "%.1fK" "$(echo "scale=1; $n / 1000" | bc)"
    else
        echo "$n"
    fi
}

# Set health RGB for pulse gradient
get_health_rgb() {
    local pct="$1"
    if [[ $pct -ge $CONTEXT_CRIT ]]; then
        END_R=${HEALTH_CRIT_RGB[0]} END_G=${HEALTH_CRIT_RGB[1]} END_B=${HEALTH_CRIT_RGB[2]}
    elif [[ $pct -ge $CONTEXT_WARN ]]; then
        END_R=${HEALTH_WARN_RGB[0]} END_G=${HEALTH_WARN_RGB[1]} END_B=${HEALTH_WARN_RGB[2]}
    else
        END_R=${HEALTH_GOOD_RGB[0]} END_G=${HEALTH_GOOD_RGB[1]} END_B=${HEALTH_GOOD_RGB[2]}
    fi
}

# --- Model Theme ---
# Each model gets its own color personality (256-color safe + RGB for pulse)
case "$model_name" in
    *Sonnet*)
        THEME_PRIMARY='\033[1;38;5;208m'  # Orange
        THEME_ACCENT='\033[1;38;5;214m'
        THEME_R=255 THEME_G=140 THEME_B=0
        ;;
    *Opus*)
        THEME_PRIMARY='\033[1;38;5;93m'   # Purple
        THEME_ACCENT='\033[1;38;5;141m'
        THEME_R=139 THEME_G=92 THEME_B=246
        ;;
    *Haiku*)
        THEME_PRIMARY='\033[1;38;5;37m'   # Teal
        THEME_ACCENT='\033[1;38;5;44m'
        THEME_R=0 THEME_G=188 THEME_B=212
        ;;
    *)
        THEME_PRIMARY='\033[1;38;5;208m'  # Default: Orange
        THEME_ACCENT='\033[1;38;5;214m'
        THEME_R=255 THEME_G=140 THEME_B=0
        ;;
esac

# --- Project Detection ---
# Walks up to find .claude/statusline-project.json (max 5 levels)
detect_project() {
    local dir="$1" depth=0
    while [[ "$dir" != "/" && $depth -lt 5 ]]; do
        [[ -f "$dir/.claude/statusline-project.json" ]] && echo "$dir/.claude/statusline-project.json" && return
        dir=$(dirname "$dir")
        ((depth++))
    done
}

# --- Auto-Create Project ---
# Creates project config based on auto_create_mode setting
# Modes: never, git_only, claude_folder (default), git_and_claude, always
auto_create_project() {
    [[ "$TRACKING_ENABLED" != "true" ]] && return
    [[ "$AUTO_CREATE_MODE" == "never" ]] && return

    local config="$cwd/.claude/statusline-project.json"
    [[ -f "$config" ]] && return  # Already exists

    # Check conditions based on auto_create_mode
    local has_git=false has_claude=false
    [[ -d "$cwd/.git" ]] && has_git=true
    [[ -d "$cwd/.claude" ]] && has_claude=true

    case "$AUTO_CREATE_MODE" in
        git_only)
            [[ "$has_git" != "true" ]] && return
            ;;
        claude_folder)
            [[ "$has_claude" != "true" ]] && return
            ;;
        git_and_claude)
            [[ "$has_git" != "true" || "$has_claude" != "true" ]] && return
            ;;
        always)
            # Always create (will create .claude folder below)
            ;;
        *)
            # Unknown mode, default to claude_folder behavior
            [[ "$has_claude" != "true" ]] && return
            ;;
    esac

    mkdir -p "$cwd/.claude" 2>/dev/null || return
    local folder_name=$(basename "$cwd")
    local git_remote=$(git -C "$cwd" remote get-url origin 2>/dev/null | sed 's|git@\([^:]*\):|https://\1/|;s|\.git$||')

    # Check for parent/umbrella project
    local parent_config=""
    local parent_dir=$(dirname "$cwd")
    local depth=0
    while [[ "$parent_dir" != "/" && $depth -lt 5 ]]; do
        if [[ -f "$parent_dir/.claude/statusline-project.json" ]]; then
            parent_config="$parent_dir/.claude/statusline-project.json"
            break
        fi
        parent_dir=$(dirname "$parent_dir")
        ((depth++))
    done

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
}

auto_create_project
project_config=$(detect_project "$cwd")

project_icon="" project_name="" project_root=""

if [[ -n "$project_config" && -f "$project_config" ]]; then
    project_root=$(dirname "$(dirname "$project_config")")
    project_icon=$(jq -r '.icon // ""' "$project_config" 2>/dev/null)
    project_name=$(jq -r '.name // ""' "$project_config" 2>/dev/null)
else
    project_icon="🏠"
fi

# --- Delta Cost Tracking (Session Attribution) ---
# Session belongs to project where it STARTED (session_home)
# Breakdown tracks where work was done: { "_self": X, "child-name": Y }
# State file format: {cost}|{session_home_config}

state_file="$CACHE_DIR/session-${session_id}.state"
project_total_cost=0
display_cycle=$(( $(date +%S) % 10 ))

# Calculate delta and determine session home
cost_delta="$total_cost"
session_home=""  # Where session started (set once, preserved)
if [[ -f "$state_file" ]]; then
    IFS='|' read -r last_cost session_home < "$state_file"
    if [[ -n "$last_cost" ]] && (( $(echo "$total_cost > $last_cost" | bc -l 2>/dev/null || echo 0) )); then
        cost_delta=$(echo "$total_cost - $last_cost" | bc -l 2>/dev/null || echo "$total_cost")
    else
        cost_delta=0
    fi
fi

# First render: current project becomes session home
if [[ -z "$session_home" ]]; then
    session_home="$project_config"
fi

# Breakdown key: "_self" if in session_home, else the child project's name
breakdown_key="_self"
if [[ -n "$project_config" && "$project_config" != "$session_home" ]]; then
    # We're in a different project than where session started
    breakdown_key=$(jq -r '.name // "unknown"' "$project_config" 2>/dev/null)
fi

# Update session cost in project config using breakdown structure
# Uses atomic file locking with 60s stale lock cleanup
update_project_cost() {
    local config="$1" amount="$2" sid="$3" plan="$4" breakdown_key="${5:-_self}" transcript="${6:-}"
    [[ -z "$config" || ! -f "$config" ]] && return
    [[ "$amount" == "0" || -z "$amount" ]] && return

    local lock_dir="${config}.lock"
    # Remove stale locks (older than 60 seconds)
    if [[ -d "$lock_dir" ]]; then
        local lock_age=$(( $(date +%s) - $(stat -f %m "$lock_dir" 2>/dev/null || echo 0) ))
        [[ $lock_age -gt 60 ]] && rmdir "$lock_dir" 2>/dev/null
    fi
    mkdir "$lock_dir" 2>/dev/null || return

    # Get session start time from transcript file ctime (macOS: -f %B = birth time)
    local started_iso=""
    if [[ -n "$transcript" && -f "$transcript" ]]; then
        local ctime=$(stat -f %B "$transcript" 2>/dev/null)
        [[ -n "$ctime" && "$ctime" != "0" ]] && started_iso=$(date -r "$ctime" -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    # Phase 2: Session with breakdown structure
    # breakdown_key is either "_self" (work at this level) or child project name
    local updated=$(jq --arg delta "$amount" --arg sid "$sid" --arg plan "$plan" \
                       --arg transcript "$transcript" --arg started "$started_iso" \
                       --arg bkey "$breakdown_key" '
        # Set started and transcript only on first session creation
        .costs.sessions[$sid].started = (.costs.sessions[$sid].started // (if $started != "" then $started else null end)) |
        .costs.sessions[$sid].transcript = (.costs.sessions[$sid].transcript // (if $transcript != "" then $transcript else null end)) |

        # Phase 2: Use breakdown structure instead of contributed
        # Initialize breakdown object if needed
        .costs.sessions[$sid].breakdown = (.costs.sessions[$sid].breakdown // {}) |
        .costs.sessions[$sid].breakdown[$bkey] = ((.costs.sessions[$sid].breakdown[$bkey] // 0) + ($delta | tonumber)) |

        # Calculate total_cost as sum of all breakdown values
        .costs.sessions[$sid].total_cost = ([.costs.sessions[$sid].breakdown // {} | to_entries[].value] | add // 0) |
        .costs.sessions[$sid].updated = (now | todate) |

        # Project total = sum of all sessions total_cost + child projects contributed
        .costs.total = (
            ([.costs.sessions // {} | to_entries[].value.total_cost // .value.contributed // 0] | add // 0) +
            ([.costs.projects // {} | to_entries[].value.contributed // 0] | add // 0)
        ) |
        .costs.session_count = ([.costs.sessions // {} | keys[]] | length) |
        .costs.last_updated = (now | todate) |
        .costs.plan = $plan |
        if .costs.tracking_started == null then .costs.tracking_started = (now | todate) else . end
    ' "$config")

    echo "$updated" > "${config}.tmp" && mv "${config}.tmp" "$config"
    rmdir "$lock_dir" 2>/dev/null
}

# Roll-up: Update parent project with child's contributed total
update_parent_project() {
    local config="$1" sub_name="$2" sub_total="$3" sid="$4" plan="$5"
    [[ -z "$config" || ! -f "$config" ]] && return

    local lock_dir="${config}.lock"
    if [[ -d "$lock_dir" ]]; then
        local lock_age=$(( $(date +%s) - $(stat -f %m "$lock_dir" 2>/dev/null || echo 0) ))
        [[ $lock_age -gt 60 ]] && rmdir "$lock_dir" 2>/dev/null
    fi
    mkdir "$lock_dir" 2>/dev/null || return

    # Set sub-project total (absolute, self-healing)
    local updated=$(jq --arg total "$sub_total" --arg sid "$sid" --arg plan "$plan" --arg sub "$sub_name" '
        .costs.projects[$sub].contributed = ($total | tonumber) |
        .costs.projects[$sub].sessions = ((.costs.projects[$sub].sessions // []) + [$sid] | unique) |
        .costs.total = (
            ([.costs.sessions // {} | to_entries[].value.total_cost // .value.contributed // 0] | add // 0) +
            ([.costs.projects // {} | to_entries[].value.contributed // 0] | add // 0)
        ) |
        .costs.last_updated = (now | todate) |
        .costs.plan = $plan
    ' "$config")

    echo "$updated" > "${config}.tmp" && mv "${config}.tmp" "$config"
    rmdir "$lock_dir" 2>/dev/null
}

# Only update on cycle 0 (every ~10s) and if tracking enabled
if [[ "$TRACKING_ENABLED" == "true" && -n "$session_home" && $display_cycle -eq 0 ]]; then
    # Phase 2: Update SESSION HOME with delta, using breakdown_key
    # Session lives where it started, with breakdown tracking where work was done
    update_project_cost "$session_home" "$cost_delta" "$session_id" "$CLAUDE_PLAN" "$breakdown_key" "$transcript_path"

    # Roll up the entire chain from session_home to MASTER
    # Each project's total gets reported to its parent
    rollup_config="$session_home"
    while [[ -n "$rollup_config" && -f "$rollup_config" ]]; do
        parent_config=$(jq -r '.parent // empty' "$rollup_config" 2>/dev/null)
        if [[ -n "$parent_config" && -f "$parent_config" ]]; then
            sub_project_name=$(jq -r '.name // "unknown"' "$rollup_config" 2>/dev/null)
            sub_project_total=$(jq -r '.costs.total // 0' "$rollup_config" 2>/dev/null)
            update_parent_project "$parent_config" "$sub_project_name" "$sub_project_total" "$session_id" "$CLAUDE_PLAN"
            rollup_config="$parent_config"
        else
            break
        fi
    done

    # Save state AFTER successful update - preserve session_home (set once)
    echo "${total_cost}|${session_home}" > "$state_file"

    # Get display total from session home
    project_total_cost=$(jq -r '.costs.total // 0' "$session_home" 2>/dev/null || echo "0")
elif [[ -n "$session_home" && -f "$session_home" ]]; then
    project_total_cost=$(jq -r '.costs.total // 0' "$session_home" 2>/dev/null || echo "0")
elif [[ -n "$project_config" && -f "$project_config" ]]; then
    project_total_cost=$(jq -r '.costs.total // 0' "$project_config" 2>/dev/null || echo "0")
fi

# --- Memory Files ---
# Counts CLAUDE.md files in cwd hierarchy (max 3 levels up) + global
count_memory_files() {
    local count=0 dir="$cwd" depth=0
    while [[ "$dir" != "/" && $depth -lt 3 ]]; do
        [[ -f "$dir/CLAUDE.md" ]] && ((count++))
        [[ -f "$dir/.claude/CLAUDE.md" ]] && ((count++))
        dir=$(dirname "$dir")
        ((depth++))
    done
    [[ -f "$HOME/.claude/CLAUDE.md" ]] && ((count++))
    echo $count
}
memory_count=$(count_memory_files)

# --- Transcript Parsing (Cached) ---
# Extracts: context %, cache %, message count
# Cached by MD5 hash of transcript path
if [[ -f "$transcript_path" ]]; then
    cache_file="$CACHE_DIR/transcript-$(echo "$transcript_path" | md5).cache"
    transcript_mtime=$(stat -f %m "$transcript_path" 2>/dev/null || echo 0)
    cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)

    if [[ -f "$cache_file" && $cache_mtime -ge $transcript_mtime ]]; then
        read conversation_tokens cache_pct total_input baseline_overhead true_total msg_count <<< "$(cat "$cache_file")"
    else
        result=$(jq -r 'select(.message.usage) | .message.usage | [(.input_tokens // 0), (.output_tokens // 0), (.cache_read_input_tokens // 0), (.cache_creation_input_tokens // 0)] | @tsv' "$transcript_path" 2>/dev/null | awk '
            BEGIN { input=0; cache_read=0; cache_create=0; latest_cache_read=0; latest_cache_create=0 }
            { input += $1; cache_read += $3; cache_create += $4; if ($3 > 0) latest_cache_read = $3; if ($4 > 0) latest_cache_create = $4 }
            END {
                total = input + cache_read + cache_create
                cache_pct = total > 0 ? int((cache_read / total) * 100) : 0
                current = latest_cache_read + latest_cache_create
                print current, cache_pct, total, latest_cache_read, current
            }')
        msg_count=$(grep -c '"type":"assistant"' "$transcript_path" 2>/dev/null || echo 0)
        echo "$result $msg_count" | tee "$cache_file" > /dev/null
        read conversation_tokens cache_pct total_input baseline_overhead true_total msg_count <<< "$result $msg_count"
    fi
else
    conversation_tokens=0 cache_pct=0 total_input=0 baseline_overhead=0 true_total=0 msg_count=0
fi

# --- Path Display ---
# Three styles: forward truncation, project+depth, reverse truncation
# Cycles every ~3 seconds when path_cycling enabled

truncate_name() {
    local name="$1" max="${2:-15}"
    [[ "$name" == *" "* ]] && name="${name%% *}…"
    [[ ${#name} -gt $max ]] && name="${name:0:$((max-1))}…"
    echo "$name"
}

# Path cycling (changes every ~3 seconds)
PATH_MAX=32
if [[ "$PATH_CYCLING" == "true" ]]; then
    path_cycle=$((display_cycle / 3 % 3))
else
    path_cycle=$PATH_STYLE
fi

# Truncate from end (forward): ~/Gravicity…/.claude/sk…
truncate_forward() {
    local path="$1" max="$2"
    [[ "$path" == "$HOME"* ]] && path="~${path#$HOME}"
    path=$(echo "$path" | sed 's|\([^/ ]*\) [^/]*|\1…|g')
    [[ ${#path} -gt $max ]] && path="${path:0:$((max-1))}…"
    echo "$path"
}

# Truncate from start (reverse): …skills/field-commander
truncate_reverse() {
    local path="$1" max="$2"
    [[ ${#path} -gt $max ]] && path="…${path: -$((max-1))}"
    echo "$path"
}

if [[ -n "$project_name" && -n "$project_root" ]]; then
    if [[ "$cwd" == "$project_root" ]]; then
        # At project root - show full name, only truncate if really long
        display_dir="$project_name"
        [[ ${#display_dir} -gt $PATH_MAX ]] && display_dir="${display_dir:0:$((PATH_MAX-1))}…"
    elif [[ "$cwd" == "$project_root"/* ]]; then
        short_project=$(truncate_name "$project_name" 10)
        rel_path="${cwd#$project_root/}"
        IFS='/' read -ra rel_parts <<< "$rel_path"
        num_parts=${#rel_parts[@]}
        last_folder="${rel_parts[$((num_parts-1))]}"

        if [[ $num_parts -eq 1 ]]; then
            # Single level - no cycling needed
            display_dir="${short_project}/${last_folder}"
            [[ ${#display_dir} -gt $PATH_MAX ]] && display_dir="${display_dir:0:$((PATH_MAX-1))}…"
        else
            case $path_cycle in
                0)  # Forward truncation: ~/Gravicity…/.claude/sk…
                    display_dir=$(truncate_forward "$cwd" $PATH_MAX)
                    ;;
                1)  # Project + depth + last: Gravicity…//field-comm…
                    slashes=$(printf '/%.0s' $(seq 1 $((num_parts - 1))))
                    display_dir="${short_project}…${slashes}${last_folder}"
                    [[ ${#display_dir} -gt $PATH_MAX ]] && display_dir="${display_dir:0:$((PATH_MAX-1))}…"
                    ;;
                2)  # Reverse truncation: …skills/field-commander
                    display_dir=$(truncate_reverse "$rel_path" $PATH_MAX)
                    ;;
            esac
        fi
    else
        display_dir=$(truncate_forward "$cwd" $PATH_MAX)
    fi
else
    display_dir=$(truncate_forward "$cwd" $PATH_MAX)
    [[ "$display_dir" == "~" || -z "$display_dir" ]] && display_dir="Home"
fi

# --- Git Info (Cached) ---
# Branch, ahead/behind, status; cached 5s
# Git URL cached 60s for clickable links
git_info="" git_url=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    cache_file="$CACHE_DIR/git-$(echo "$cwd" | md5)-${session_id:0:8}.cache"
    age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))

    if [[ $age -lt 5 && -f "$cache_file" ]]; then
        git_info=$(cat "$cache_file")
    else
        branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "detached")
        status_char="⊚"
        [[ -n $(git -C "$cwd" status --porcelain 2>/dev/null) ]] && status_char="⊛"

        upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        ahead_behind=""
        if [[ -n "$upstream" ]]; then
            ahead=$(git -C "$cwd" rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
            behind=$(git -C "$cwd" rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
            [[ $ahead -gt 0 ]] && ahead_behind="↑$ahead"
            [[ $behind -gt 0 ]] && ahead_behind="${ahead_behind:+$ahead_behind }↓$behind"
        fi
        git_info="$status_char $branch${ahead_behind:+ $ahead_behind}"
        echo "$git_info" > "$cache_file"
    fi

    # Git URL (cached longer)
    url_cache="$CACHE_DIR/git-url-$(echo "$cwd" | md5).cache"
    url_age=$(($(date +%s) - $(stat -f %m "$url_cache" 2>/dev/null || echo 0)))
    if [[ $url_age -lt 60 && -f "$url_cache" ]]; then
        git_url=$(cat "$url_cache")
    else
        remote_url=$(git -C "$cwd" remote get-url origin 2>/dev/null)
        [[ "$remote_url" == git@* ]] && remote_url=$(echo "$remote_url" | sed 's|git@\([^:]*\):|https://\1/|;s|\.git$||')
        [[ "$remote_url" == *.git ]] && remote_url="${remote_url%.git}"
        git_url="$remote_url"
        echo "$git_url" > "$url_cache"
    fi
fi

# --- Format Values ---
duration_info=""
if [[ "$total_duration" != "0" && "$total_duration" != "null" ]]; then
    secs=$((total_duration / 1000))
    if [[ $secs -ge 3600 ]]; then
        duration_info="$((secs / 3600))h$(((secs % 3600) / 60))m"
    elif [[ $secs -ge 60 ]]; then
        duration_info="$((secs / 60))m$((secs % 60))s"
    else
        duration_info="${secs}s"
    fi
fi

cost_info=""
if [[ "$total_cost" != "0" && "$total_cost" != "null" && "$total_duration" != "0" ]]; then
    hours=$(echo "scale=4; $total_duration / 3600000" | bc)
    if (( $(echo "$hours > 0.001" | bc -l) )); then
        cost_info=$(echo "scale=2; $total_cost / $hours" | bc)
    fi
fi

code_added="" code_removed=""
[[ "$lines_added" != "0" || "$lines_removed" != "0" ]] && code_added="+$(format_num $lines_added)" && code_removed="-$(format_num $lines_removed)"

BUFFER_SIZE=45000
total_with_buffer=$true_total
[[ "$token_warning" == "false" ]] && total_with_buffer=$((true_total + BUFFER_SIZE))

context_pct=0 context_color="$HEALTH_GOOD"
if [[ $total_with_buffer -gt 0 ]]; then
    context_pct=$(echo "scale=0; ($total_with_buffer * 100) / 200000" | bc)
    context_color=$(get_health_color $context_pct $CONTEXT_WARN $CONTEXT_CRIT 1)
fi

session_short="${session_id: -6}"
IDE_SCHEME="${CLAUDE_IDE_SCHEME:-file://}"

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  BUILD OUTPUT - Assembles the 4/5 line statusline                         ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║  Line 1: Model─Version─🧠─Context%─📚─Memory─💰Cost                        ║
# ║  Line 2: Icon + Project/Path                                              ║
# ║  Line 3: Git info (branch, ahead/behind, staged, modified, diff, age)     ║
# ║  Line 4: ⏱Duration 💬Messages +Code-Removed ※SessionID                    ║
# ║  Line 5: Animated pulse + 🛡Cache%                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

SEP="${THEME_PRIMARY}─${RESET}"

# --- Line 1: Model─Context─Memory─Cost ---
model_display="${model_name// /${SEP}${THEME_ACCENT}}"
line1="${THEME_PRIMARY}╭─${RESET}${THEME_ACCENT}${model_display}${RESET}"
[[ $total_with_buffer -gt 0 ]] && line1+="${SEP}🧠${SEP}${context_color}${context_pct}%${RESET}"
if [[ $memory_count -gt 0 ]]; then
    memory_color=$(get_health_color $memory_count $MEMORY_WARN $MEMORY_CRIT 1)
    line1+="${SEP}📚${SEP}${memory_color}${memory_count}${RESET}"
fi

# Cost cycling: /hr → session → Σproject (if enabled)
if [[ "$COST_CYCLING" == "true" ]]; then
    cost_cycle=$((display_cycle / 3 % 3))
else
    cost_cycle=1  # Always show session cost
fi

if [[ "$total_cost" != "0" && "$total_cost" != "null" ]]; then
    if [[ $cost_cycle -eq 0 && -n "$cost_info" ]]; then
        line1+="${SEP}💰${THEME_ACCENT}${cost_info}/hr${RESET}"
    elif [[ $cost_cycle -eq 1 ]]; then
        line1+="${SEP}💰${THEME_ACCENT}$(printf "%.2f" "$total_cost")${RESET}"
    elif [[ $cost_cycle -eq 2 && -n "$project_total_cost" ]] && (( $(echo "$project_total_cost > 0" | bc -l) )); then
        line1+="${SEP}💰${THEME_ACCENT}Σ$(printf "%.2f" "$project_total_cost")${RESET}"
    else
        line1+="${SEP}💰${THEME_ACCENT}$(printf "%.2f" "$total_cost")${RESET}"
    fi
fi

# --- Line 2: Project/Path ---
line2="${THEME_PRIMARY}│${RESET} "
[[ -n "$project_icon" ]] && line2+="${project_icon}${B_CYAN}${display_dir}${RESET}" || line2+="📦 ${B_CYAN}${display_dir}${RESET}"

# --- Line 3: Git Info (only shown in git repos) ---
line_git=""
if [[ -n "$git_info" ]]; then
    line_git="${THEME_PRIMARY}│${RESET} "
    branch=$(echo "$git_info" | awk '{print $2}')
    status_char=$(echo "$git_info" | awk '{print $1}')

    # Git stats (cached 10s)
    git_cache="$CACHE_DIR/git-stats-$(echo "$cwd" | md5).cache"
    git_cache_age=$(($(date +%s) - $(stat -f %m "$git_cache" 2>/dev/null || echo 0)))

    if [[ $git_cache_age -lt 10 && -f "$git_cache" ]]; then
        source "$git_cache"
    else
        ahead=$(git -C "$cwd" rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
        behind=$(git -C "$cwd" rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
        staged=$(git -C "$cwd" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        modified=$(git -C "$cwd" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        untracked=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        diff_stats=$(git -C "$cwd" diff --shortstat HEAD 2>/dev/null)
        diff_add=$(echo "$diff_stats" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
        diff_del=$(echo "$diff_stats" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
        last_commit_secs=$(git -C "$cwd" log -1 --format=%ct 2>/dev/null || echo 0)
        now_secs=$(date +%s)
        commit_age=$(( (now_secs - last_commit_secs) / 60 ))

        cat > "$git_cache" << EOF
ahead=$ahead
behind=$behind
staged=$staged
modified=$modified
untracked=$untracked
diff_add=$diff_add
diff_del=$diff_del
commit_age=$commit_age
EOF
    fi

    # Staleness health color
    dirty_total=$((staged + modified))
    stale_score=$((dirty_total * commit_age))

    if [[ $commit_age -ge 1440 ]]; then
        commit_age_fmt="$((commit_age / 1440))d"
    elif [[ $commit_age -ge 60 ]]; then
        commit_age_fmt="$((commit_age / 60))h"
    else
        commit_age_fmt="${commit_age}m"
    fi

    if [[ $stale_score -ge $STALENESS_CRIT ]]; then
        commit_age_color="$HEALTH_CRIT"
    elif [[ $stale_score -ge $STALENESS_WARN ]]; then
        commit_age_color="$HEALTH_WARN"
    else
        commit_age_color="$HEALTH_GOOD"
    fi

    # Build stats array
    git_stats=()
    [[ $ahead -gt 0 ]] && git_stats+=("${HEALTH_GOOD}↑${ahead}${RESET}")
    [[ $behind -gt 0 ]] && git_stats+=("${B_RED}↓${behind}${RESET}")
    [[ $staged -gt 0 ]] && git_stats+=("${HEALTH_GOOD}●${staged}${RESET}")
    [[ $modified -gt 0 ]] && git_stats+=("${B_YELLOW}~${modified}${RESET}")
    [[ $untracked -gt 0 ]] && git_stats+=("${MUTED_SLATE}?${untracked}${RESET}")
    [[ $diff_add -gt 0 || $diff_del -gt 0 ]] && git_stats+=("${THEME_ACCENT}+${diff_add}${RESET}${B_RED}-${diff_del}${RESET}")
    [[ $commit_age -gt 0 ]] && git_stats+=("${commit_age_color}${commit_age_fmt}${RESET}")

    # Branch display
    if [[ ${#branch} -le 15 ]]; then
        branch_display="$status_char $branch"
        show_all=1
    else
        branch_display="$status_char ${branch:0:12}.."
        show_all=0
    fi

    # Add branch with link
    if [[ -n "$git_url" ]]; then
        line_git+="\033]8;;${git_url}\007${B_BLUE}${branch_display}${RESET}\033]8;;\007"
    else
        line_git+="${B_BLUE}${branch_display}${RESET}"
    fi

    # Add stats
    if [[ $show_all -eq 1 ]]; then
        for stat in "${git_stats[@]}"; do
            line_git+=" $stat"
        done
    elif [[ ${#git_stats[@]} -gt 0 ]]; then
        mid=$(( (${#git_stats[@]} + 1) / 2 ))
        cycle=$((display_cycle / 2 % 2))
        if [[ $cycle -eq 0 ]]; then
            for ((i=0; i<mid; i++)); do
                line_git+=" ${git_stats[$i]}"
            done
        else
            for ((i=mid; i<${#git_stats[@]}; i++)); do
                line_git+=" ${git_stats[$i]}"
            done
        fi
    fi
fi

# --- Line 4: Duration─Messages─Code─Session ---
line_stats="${THEME_PRIMARY}│${RESET} "
[[ -n "$duration_info" ]] && line_stats+="⏱ ${THEME_ACCENT}${duration_info}${RESET}"
[[ $msg_count -gt 0 ]] && line_stats+=" 💬${B_CYAN}$(format_num $msg_count)${RESET}"
[[ -n "$code_added" ]] && line_stats+=" ${THEME_ACCENT}${code_added}${RESET}${B_RED}${code_removed}${RESET}"

if [[ -f "$transcript_path" ]]; then
    line_stats+=" \033]8;;${IDE_SCHEME}${transcript_path}\007${THEME_ACCENT}※${session_short}${RESET}\033]8;;\007"
else
    line_stats+=" ${THEME_ACCENT}※${session_short}${RESET}"
fi

# --- Line 5: Pulse Animation + Cache Shield ---
# Truecolor: smooth RGB gradient from theme → health color
# 256-color fallback: simple moving orb without gradient
get_health_rgb $context_pct

# Choose color mode for pulse (256-color fallback for Terminal.app)
if [[ $TRUECOLOR_SUPPORT -eq 1 ]]; then
    # Truecolor: use RGB gradients
    PULSE_THEME="\033[38;2;${THEME_R};${THEME_G};${THEME_B}m"
    PULSE_END="\033[38;2;${END_R};${END_G};${END_B}m"
else
    # 256-color fallback: use THEME_PRIMARY colors (already 256-safe)
    PULSE_THEME="${THEME_PRIMARY}"
    # Map health to 256-color
    if [[ $context_pct -ge $CONTEXT_CRIT ]]; then
        PULSE_END='\033[38;5;196m'  # Red
    elif [[ $context_pct -ge $CONTEXT_WARN ]]; then
        PULSE_END='\033[38;5;214m'  # Orange
    else
        PULSE_END='\033[38;5;44m'   # Cyan
    fi
fi

if [[ "$PULSE_ANIMATION" == "true" ]]; then
    frame=$(( $(date +%S) % 24 ))
    line_len=26 grad_len=6
    pulse=""

    if [[ $TRUECOLOR_SUPPORT -eq 1 ]]; then
        # Truecolor gradient animation
        if ((frame >= 22)); then
            for ((i=0; i<line_len; i++)); do
                if ((i < line_len - grad_len)); then
                    pulse+="${PULSE_THEME}─\033[0m"
                elif ((i == line_len - grad_len)); then
                    pulse+="${PULSE_THEME}┉\033[0m"
                else
                    prog=$((i - (line_len - grad_len)))
                    r=$((THEME_R + (END_R - THEME_R) * prog / grad_len))
                    g=$((THEME_G + (END_G - THEME_G) * prog / grad_len))
                    b=$((THEME_B + (END_B - THEME_B) * prog / grad_len))
                    pulse+="\033[38;2;${r};${g};${b}m━\033[0m"
                fi
            done
            ((frame == 22)) && pulse+="${PULSE_END}◉✦✧·\033[0m" \
                            || pulse+="${PULSE_END}◉\033[0m${DIM}·✧✦\033[0m"
        else
            orb_pos=$((frame + 2))
            for ((i=0; i<orb_pos; i++)); do
                dist=$((orb_pos - i))
                if ((dist > grad_len)); then
                    pulse+="${PULSE_THEME}─\033[0m"
                elif ((dist == grad_len)); then
                    pulse+="${PULSE_THEME}┉\033[0m"
                else
                    prog=$((grad_len - dist))
                    r=$((THEME_R + (END_R - THEME_R) * prog / grad_len))
                    g=$((THEME_G + (END_G - THEME_G) * prog / grad_len))
                    b=$((THEME_B + (END_B - THEME_B) * prog / grad_len))
                    pulse+="\033[38;2;${r};${g};${b}m━\033[0m"
                fi
            done
            pulse+="${PULSE_END}◉\033[0m"

            remaining=$((line_len - orb_pos))
            fade_chars=("╸" "╍" "┈")
            for ((i=0; i<remaining; i++)); do
                prog=$((i * 100 / (remaining > 0 ? remaining : 1)))
                r=$((END_R + (THEME_R - END_R) * prog / 100))
                g=$((END_G + (THEME_G - END_G) * prog / 100))
                b=$((END_B + (THEME_B - END_B) * prog / 100))
                ((i < 3)) && pulse+="\033[38;2;${r};${g};${b}m${fade_chars[$i]}\033[0m" \
                          || pulse+="\033[38;2;${r};${g};${b}m─\033[0m"
            done
        fi
    else
        # 256-color simplified animation (no gradient, just moving orb)
        if ((frame >= 22)); then
            for ((i=0; i<line_len; i++)); do
                pulse+="${PULSE_THEME}─${RESET}"
            done
            ((frame == 22)) && pulse+="${PULSE_END}◉✦✧·${RESET}" \
                            || pulse+="${PULSE_END}◉${RESET}${DIM}·✧✦${RESET}"
        else
            orb_pos=$((frame + 2))
            for ((i=0; i<orb_pos; i++)); do
                pulse+="${PULSE_THEME}─${RESET}"
            done
            pulse+="${PULSE_END}◉${RESET}"
            for ((i=orb_pos+1; i<line_len; i++)); do
                pulse+="${PULSE_THEME}─${RESET}"
            done
        fi
    fi
else
    # Static line if animation disabled
    pulse=""
    for ((i=0; i<26; i++)); do
        pulse+="${PULSE_THEME}─${RESET}"
    done
fi

line_pulse="${THEME_PRIMARY}╰${RESET}${PULSE_THEME}─${RESET}${pulse}"
[[ $cache_pct -gt 0 ]] && line_pulse+=" ${context_color}🛡 ${cache_pct}%${RESET}" || line_pulse+=" ${MUTED_SLATE}🛡 ─${RESET}"

# --- Final Output ---
echo -e "$line1"
echo -e "$line2"
[[ -n "$line_git" ]] && echo -e "$line_git"
echo -e "$line_stats"
echo -e "${line_pulse}${RESET}"
