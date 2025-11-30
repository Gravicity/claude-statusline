#!/bin/bash
# Claude Code Statusline - Dynamic 4/5-line display
# Displays: Model, context, memory, cost, project, git, stats, pulse animation

# ============================================
# CLI COMMANDS (run before stdin)
# ============================================

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
PURPLE='\033[1;38;2;139;92;246m'
GREEN='\033[1;38;2;34;197;94m'
YELLOW='\033[1;38;2;234;179;8m'
CYAN='\033[1;36m'
SLATE='\033[1;38;2;148;163;184m'

cli_print_success() { echo -e "  ${GREEN}✓${RESET} $1"; }
cli_print_info() { echo -e "  ${CYAN}→${RESET} $1"; }
cli_print_warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
cli_print_error() { echo -e "  ${PURPLE}✗${RESET} $1"; }

# Find parent umbrella project
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
}

# Initialize umbrella project
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

# Initialize regular project
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

# CLI help
show_cli_help() {
    echo ""
    echo -e "  ${BOLD}Claude Code Statusline${RESET} ${DIM}v2.0${RESET}"
    echo ""
    echo -e "  ${DIM}Usage:${RESET}"
    echo -e "    ${SLATE}(stdin)${RESET}           Normal statusline mode (receives JSON from Claude Code)"
    echo -e "    ${SLATE}--init-project${RESET}    Create project config in current or specified directory"
    echo -e "    ${SLATE}--init-umbrella${RESET}   Create umbrella/parent project config"
    echo -e "    ${SLATE}--help${RESET}            Show this help"
    echo ""
    echo -e "  ${DIM}Examples:${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --init-umbrella ~/projects${RESET}"
    echo -e "    ${CYAN}~/.claude/statusline-command.sh --init-project${RESET}"
    echo -e "    ${CYAN}cd ~/projects/my-app && ~/.claude/statusline-command.sh --init-project${RESET}"
    echo ""
    exit 0
}

# Handle CLI arguments before reading stdin
case "${1:-}" in
    --init-umbrella) init_umbrella "${2:-}" ;;
    --init-project)  init_project "${2:-}" ;;
    --help|-h)       show_cli_help ;;
esac

# ============================================
# STATUSLINE MODE (stdin JSON input)
# ============================================

input=$(cat)

# Debug: dump raw JSON (set STATUSLINE_DEBUG=1)
[[ "${STATUSLINE_DEBUG:-0}" == "1" ]] && mkdir -p "$HOME/.cache/claude-statusline" && echo "$input" > "$HOME/.cache/claude-statusline/debug-input.json"

# ============================================
# PARSE INPUT (from stdin JSON)
# ============================================
model_name=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir')
session_id=$(echo "$input" | jq -r '.session_id')
transcript_path=$(echo "$input" | jq -r '.transcript_path')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
total_duration=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
token_warning=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')

# Cache directory
CACHE_DIR="$HOME/.cache/claude-statusline"
mkdir -p "$CACHE_DIR"

# ============================================
# CONFIGURATION
# ============================================
CONFIG_FILE="$HOME/.claude/statusline-config.json"

# Defaults
TRACKING_ENABLED=true
GIT_REPOS_ONLY=true
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
    GIT_REPOS_ONLY=$(jq -r '.tracking.git_repos_only // true' "$CONFIG_FILE")
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

# Plan from environment or config
CLAUDE_PLAN="${CLAUDE_PLAN:-$(jq -r '.plan // "api"' "$CONFIG_FILE" 2>/dev/null || echo "api")}"

# ============================================
# COLORS
# ============================================
RESET='\033[0m'
DIM='\033[2m'
B_CYAN='\033[1;36m'
B_BLUE='\033[1;34m'
B_RED='\033[1;31m'
B_YELLOW='\033[1;33m'
B_MAGENTA='\033[1;35m'
# Muted colors (visible but de-emphasized)
MUTED_SLATE='\033[1;38;2;148;163;184m'  # Bold Slate-400 #94A3B8

HEALTH_GOOD="\033[1;38;2;${HEALTH_GOOD_RGB[0]};${HEALTH_GOOD_RGB[1]};${HEALTH_GOOD_RGB[2]}m"
HEALTH_WARN="\033[1;38;2;${HEALTH_WARN_RGB[0]};${HEALTH_WARN_RGB[1]};${HEALTH_WARN_RGB[2]}m"
HEALTH_CRIT="\033[1;38;2;${HEALTH_CRIT_RGB[0]};${HEALTH_CRIT_RGB[1]};${HEALTH_CRIT_RGB[2]}m"

# Health color helper (reverse=1: higher is worse)
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

# ============================================
# MODEL THEME (ANSI-256 + RGB)
# ============================================
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

# ============================================
# PROJECT DETECTION & AUTO-INIT
# ============================================
detect_project() {
    local dir="$1" depth=0
    while [[ "$dir" != "/" && $depth -lt 5 ]]; do
        [[ -f "$dir/.claude/statusline-project.json" ]] && echo "$dir/.claude/statusline-project.json" && return
        dir=$(dirname "$dir")
        ((depth++))
    done
}

# Auto-create project config if in git repo without one
init_project_if_git() {
    [[ "$TRACKING_ENABLED" != "true" ]] && return

    local config="$cwd/.claude/statusline-project.json"
    [[ -f "$config" ]] && return  # Already exists

    # Only auto-create in git repos if git_repos_only is true
    if [[ "$GIT_REPOS_ONLY" == "true" ]]; then
        [[ ! -d "$cwd/.git" ]] && return
    fi

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

init_project_if_git
project_config=$(detect_project "$cwd")

project_icon="" project_name="" project_root=""

if [[ -n "$project_config" && -f "$project_config" ]]; then
    project_root=$(dirname "$(dirname "$project_config")")
    project_icon=$(jq -r '.icon // ""' "$project_config" 2>/dev/null)
    project_name=$(jq -r '.name // ""' "$project_config" 2>/dev/null)
else
    project_icon="🏠"
fi

# ============================================
# DELTA COST TRACKING
# ============================================
# Track cost changes per project using session state file
state_file="$CACHE_DIR/session-${session_id}.state"
project_total_cost=0
display_cycle=$(( $(date +%S) % 10 ))

# Calculate delta since last update
cost_delta="$total_cost"
last_project=""
if [[ -f "$state_file" ]]; then
    IFS='|' read -r last_cost last_project < "$state_file"
    if [[ -n "$last_cost" ]] && (( $(echo "$total_cost > $last_cost" | bc -l 2>/dev/null || echo 0) )); then
        cost_delta=$(echo "$total_cost - $last_cost" | bc -l 2>/dev/null || echo "$total_cost")
    else
        cost_delta=0
    fi
fi

# Save current state
echo "${total_cost}|${project_config}" > "$state_file"

# Update project costs with delta
update_project_cost() {
    local config="$1" delta="$2" sid="$3" plan="$4" is_umbrella="${5:-false}" sub_name="${6:-}"
    [[ -z "$config" || ! -f "$config" ]] && return
    [[ "$delta" == "0" || -z "$delta" ]] && return

    local lock_dir="${config}.lock"
    mkdir "$lock_dir" 2>/dev/null || return

    if [[ "$is_umbrella" == "true" && -n "$sub_name" ]]; then
        # Umbrella: track by sub-project
        local updated=$(jq --arg delta "$delta" --arg sid "$sid" --arg plan "$plan" --arg sub "$sub_name" '
            .costs.projects[$sub].contributed = ((.costs.projects[$sub].contributed // 0) + ($delta | tonumber)) |
            .costs.projects[$sub].sessions = ((.costs.projects[$sub].sessions // []) + [$sid] | unique) |
            .costs.total = ([.costs.projects // {} | to_entries[].value.contributed // 0] | add // 0) |
            .costs.last_updated = (now | todate) |
            .costs.plan = $plan
        ' "$config")
    else
        # Regular project: track by session
        local updated=$(jq --arg delta "$delta" --arg sid "$sid" --arg plan "$plan" '
            .costs.sessions[$sid].contributed = ((.costs.sessions[$sid].contributed // 0) + ($delta | tonumber)) |
            .costs.sessions[$sid].updated = (now | todate) |
            # Total = sessions + projects (for umbrellas with direct work)
            .costs.total = (
                ([.costs.sessions // {} | to_entries[].value.contributed // 0] | add // 0) +
                ([.costs.projects // {} | to_entries[].value.contributed // 0] | add // 0)
            ) |
            .costs.session_count = ([.costs.sessions // {} | keys[]] | length) |
            .costs.last_updated = (now | todate) |
            .costs.plan = $plan |
            if .costs.tracking_started == null then .costs.tracking_started = (now | todate) else . end
        ' "$config")
    fi

    echo "$updated" > "${config}.tmp" && mv "${config}.tmp" "$config"
    rmdir "$lock_dir" 2>/dev/null
}

# Only update on cycle 0 (every ~10s) and if tracking enabled
if [[ "$TRACKING_ENABLED" == "true" && -n "$project_config" && $display_cycle -eq 0 ]]; then
    # Update current project with delta
    update_project_cost "$project_config" "$cost_delta" "$session_id" "$CLAUDE_PLAN" "false"

    # Update parent/umbrella with delta (tracked by sub-project name)
    parent_config=$(jq -r '.parent // empty' "$project_config" 2>/dev/null)
    if [[ -n "$parent_config" && -f "$parent_config" ]]; then
        sub_project_name=$(jq -r '.name // "unknown"' "$project_config" 2>/dev/null)
        update_project_cost "$parent_config" "$cost_delta" "$session_id" "$CLAUDE_PLAN" "true" "$sub_project_name"
    fi

    project_total_cost=$(jq -r '.costs.total // 0' "$project_config" 2>/dev/null || echo "0")
elif [[ -n "$project_config" && -f "$project_config" ]]; then
    project_total_cost=$(jq -r '.costs.total // 0' "$project_config" 2>/dev/null || echo "0")
fi

# ============================================
# MEMORY FILES COUNT
# ============================================
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

# ============================================
# TRANSCRIPT PARSING (cached - only for context%, cache%, msg_count)
# ============================================
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

# ============================================
# PATH DISPLAY
# ============================================
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
        display_dir=$(truncate_name "$project_name" $PATH_MAX)
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

# ============================================
# GIT INFO (cached)
# ============================================
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

# ============================================
# FORMAT VALUES
# ============================================
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

# ============================================
# BUILD OUTPUT
# ============================================
SEP="${THEME_PRIMARY}─${RESET}"

# Line 1: Model─Context─Memory─Cost
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

# Line 2: Project/Path
line2="${THEME_PRIMARY}│${RESET} "
[[ -n "$project_icon" ]] && line2+="${project_icon}${B_CYAN}${display_dir}${RESET}" || line2+="📦 ${B_CYAN}${display_dir}${RESET}"

# Line 3 (conditional): Git info
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

# Line 4: Duration─Messages─Code─Session
line_stats="${THEME_PRIMARY}│${RESET} "
[[ -n "$duration_info" ]] && line_stats+="⧗ ${THEME_ACCENT}${duration_info}${RESET}"
[[ $msg_count -gt 0 ]] && line_stats+=" 💬${B_CYAN}$(format_num $msg_count)${RESET}"
[[ -n "$code_added" ]] && line_stats+=" ${THEME_ACCENT}${code_added}${RESET}${B_RED}${code_removed}${RESET}"

if [[ -f "$transcript_path" ]]; then
    line_stats+=" \033]8;;${IDE_SCHEME}${transcript_path}\007${THEME_ACCENT}※${session_short}${RESET}\033]8;;\007"
else
    line_stats+=" ${THEME_ACCENT}※${session_short}${RESET}"
fi

# Line 5: Pulse animation with cache shield
get_health_rgb $context_pct

if [[ "$PULSE_ANIMATION" == "true" ]]; then
    frame=$(( $(date +%S) % 24 ))
    line_len=26 grad_len=6
    pulse=""

    if ((frame >= 22)); then
        for ((i=0; i<line_len; i++)); do
            if ((i < line_len - grad_len)); then
                pulse+="\033[38;2;${THEME_R};${THEME_G};${THEME_B}m─\033[0m"
            elif ((i == line_len - grad_len)); then
                pulse+="\033[38;2;${THEME_R};${THEME_G};${THEME_B}m┉\033[0m"
            else
                prog=$((i - (line_len - grad_len)))
                r=$((THEME_R + (END_R - THEME_R) * prog / grad_len))
                g=$((THEME_G + (END_G - THEME_G) * prog / grad_len))
                b=$((THEME_B + (END_B - THEME_B) * prog / grad_len))
                pulse+="\033[38;2;${r};${g};${b}m━\033[0m"
            fi
        done
        ((frame == 22)) && pulse+="\033[38;2;${END_R};${END_G};${END_B}m◉✦✧·\033[0m" \
                        || pulse+="\033[38;2;${END_R};${END_G};${END_B}m◉\033[0m${DIM}·✧✦\033[0m"
    else
        orb_pos=$((frame + 2))
        for ((i=0; i<orb_pos; i++)); do
            dist=$((orb_pos - i))
            if ((dist > grad_len)); then
                pulse+="\033[38;2;${THEME_R};${THEME_G};${THEME_B}m─\033[0m"
            elif ((dist == grad_len)); then
                pulse+="\033[38;2;${THEME_R};${THEME_G};${THEME_B}m┉\033[0m"
            else
                prog=$((grad_len - dist))
                r=$((THEME_R + (END_R - THEME_R) * prog / grad_len))
                g=$((THEME_G + (END_G - THEME_G) * prog / grad_len))
                b=$((THEME_B + (END_B - THEME_B) * prog / grad_len))
                pulse+="\033[38;2;${r};${g};${b}m━\033[0m"
            fi
        done
        pulse+="\033[38;2;${END_R};${END_G};${END_B}m◉\033[0m"

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
    # Static line if animation disabled
    pulse=""
    for ((i=0; i<26; i++)); do
        pulse+="\033[38;2;${THEME_R};${THEME_G};${THEME_B}m─\033[0m"
    done
fi

line_pulse="${THEME_PRIMARY}╰${RESET}\033[38;2;${THEME_R};${THEME_G};${THEME_B}m─\033[0m${pulse}"
[[ $cache_pct -gt 0 ]] && line_pulse+=" ${context_color}🛡 ${cache_pct}%${RESET}" || line_pulse+=" ${MUTED_SLATE}🛡 ─${RESET}"

# Output
echo -e "$line1"
echo -e "$line2"
[[ -n "$line_git" ]] && echo -e "$line_git"
echo -e "$line_stats"
echo -e "$line_pulse"
