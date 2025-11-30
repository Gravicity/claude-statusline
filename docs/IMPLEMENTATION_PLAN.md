# Implementation Plan

## Overview

Refactor claude-statusline to use stdin JSON input, add proper configuration, and create a user-friendly installation experience.

---

## What's Already Done

### Core Features (Working)
- [x] 4/5-line dynamic layout (git line only when in repo)
- [x] Model-specific color themes (Opus=purple, Sonnet=orange, Haiku=teal)
- [x] Animated pulse with health-based gradient
- [x] Cost cycling on line 1: `/hr` → session → `Σproject`
- [x] Git stats: branch, ahead/behind, staged/modified/untracked, +/-diff
- [x] Commit age with staleness-based health coloring
- [x] Path truncation for folders with spaces
- [x] Project cost tracking with multi-session support
- [x] Parent/umbrella project cost updates
- [x] Auto-init for git repos with parent detection
- [x] Atomic file updates with mkdir-based locking

### Files in Repo
- [x] `statusline-command.sh` (592 lines)
- [x] `README.md`
- [x] `docs/DESIGN_DECISIONS.md`
- [x] `example-project.json`
- [x] `.gitignore`
- [x] `LICENSE`

---

## Phase 1: Stdin JSON Refactor

### Goal
Use Claude Code's stdin JSON for primary stats, reduce transcript parsing.

### Stdin JSON Available Fields
```json
{
  "session_id": "uuid",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/current/working/directory",
  "model": {
    "id": "claude-sonnet-4-5-20250929",
    "display_name": "Claude Sonnet 4.5"
  },
  "workspace": {
    "current_dir": "/path",
    "project_dir": "/path"
  },
  "cost": {
    "total_cost_usd": 15.50,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "exceeds_200k_tokens": false
}
```

### Changes
| Stat | Current Source | New Source |
|------|----------------|------------|
| Session cost | Transcript parse | `cost.total_cost_usd` |
| Model name | Transcript parse | `model.display_name` |
| Lines +/- | Transcript parse | `cost.total_lines_*` |
| Session ID | Env var | `session_id` |
| CWD | Env var | `cwd` |

### Still Need Transcript For
- Context % (actual token count, not just boolean)
- Cache % (cache_read_input_tokens / total)
- Message count
- Session start time (for duration)
- Cost/hr (derived)

### Implementation
```bash
# Read stdin once at script start
input=$(cat)

# Fast path - from stdin
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
# ... etc

# Slow path - transcript (cached every 5-10s)
if [[ $display_cycle -eq 0 ]]; then
    parse_transcript_for_detailed_stats
fi
```

---

## Phase 2: Configuration System

### Config File Location
`~/.claude/statusline-config.json`

### Config Schema
```json
{
  "version": 1,
  "plan": "api",
  "tracking": {
    "enabled": true,
    "git_repos_only": true,
    "auto_create_umbrella": false,
    "global_master": false
  },
  "display": {
    "pulse_animation": true,
    "git_line": true,
    "cost_cycling": true
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
```

### Config Loading
```bash
CONFIG_FILE="$HOME/.claude/statusline-config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    TRACKING_ENABLED=$(jq -r '.tracking.enabled // true' "$CONFIG_FILE")
    GIT_REPOS_ONLY=$(jq -r '.tracking.git_repos_only // true' "$CONFIG_FILE")
    # ... etc
fi
```

### Benefits
- Survives script updates
- User preferences preserved
- Easy to modify without editing script

---

## Phase 3: Install Script

### File: `install.sh`

### Flow
```
┌─────────────────────────────────────────────────────────┐
│  Claude Code Statusline Installer                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Check dependencies (jq, bc, git)                    │
│                                                         │
│  2. Claude plan? [api / max5x / max20x]                 │
│     → Affects cost calculations                         │
│                                                         │
│  3. Track project costs? [y/n]                          │
│     → Creates statusline-project.json files             │
│                                                         │
│  4. Auto-create for git repos only? [y/n]               │
│     → Prevents configs in random folders                │
│                                                         │
│  5. Create umbrella project here? [y/n]                 │
│     → For tracking costs across sub-projects            │
│                                                         │
│  6. Install location                                    │
│     → Default: ~/.claude/statusline-command.sh          │
│                                                         │
│  7. Update settings.json automatically? [y/n]           │
│     → Adds statusLine config                            │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  ✓ Installed successfully!                              │
│  ✓ Config saved to ~/.claude/statusline-config.json    │
│  ✓ Script installed to ~/.claude/statusline-command.sh │
│                                                         │
│  Restart Claude Code to see your new statusline.        │
└─────────────────────────────────────────────────────────┘
```

### Options
```bash
./install.sh              # Interactive mode
./install.sh --defaults   # Accept all defaults
./install.sh --update     # Update script only, keep config
./install.sh --uninstall  # Remove everything
```

### One-Liner Install
```bash
curl -fsSL https://raw.githubusercontent.com/gravicity/claude-statusline/main/install.sh | bash
```

---

## Phase 4: Umbrella Project Improvements

### Current Behavior
- Parent gets same session entry as child
- Just mirrors the cost

### New Behavior
- Parent tracks costs BY sub-project
- Shows breakdown of where costs came from

### Umbrella JSON Structure
```json
{
  "name": "Gravicity Projects",
  "icon": "🌌",
  "color": "#6366F1",
  "costs": {
    "projects": {
      "claude-statusline": {
        "config": "/path/to/.claude/statusline-project.json",
        "contributed": 35.00,
        "sessions": ["sess-123", "sess-456"]
      },
      "verivox": {
        "config": "/path/to/.claude/statusline-project.json",
        "contributed": 12.00,
        "sessions": ["sess-789"]
      }
    },
    "direct_sessions": {
      "sess-abc": { "cost": 5.00 }
    },
    "total": 52.00
  }
}
```

### Update Logic
```bash
update_umbrella_cost() {
    local umbrella="$1" sub_project_name="$2" delta="$3" session_id="$4"

    jq --arg name "$sub_project_name" \
       --arg delta "$delta" \
       --arg sid "$session_id" \
       '
       .costs.projects[$name].contributed += ($delta | tonumber) |
       .costs.projects[$name].sessions += [$sid] | unique |
       .costs.total = [.costs.projects[].contributed] | add
       ' "$umbrella" > "${umbrella}.tmp" && mv "${umbrella}.tmp" "$umbrella"
}
```

---

## Phase 5: Delta Cost Tracking

### Problem
Session cost is cumulative. If you switch folders, all cost gets attributed to current folder.

### Solution
Track "last known cost" per session, only add delta to current project.

### State File
```bash
# Per-session state in /tmp (auto-cleaned on reboot)
state_file="/tmp/claude-sl-${session_id}.state"

# Format: cost|project_config_path
# Example: 15.50|/path/to/project/.claude/statusline-project.json
```

### Logic
```bash
if [[ -f "$state_file" ]]; then
    IFS='|' read -r last_cost last_project < "$state_file"
    delta=$(echo "$current_cost - $last_cost" | bc -l)
else
    delta=$current_cost  # First run
fi

# Save state
echo "${current_cost}|${project_config}" > "$state_file"

# Only update if positive delta
if (( $(echo "$delta > 0" | bc -l) )); then
    update_project_cost "$project_config" "$delta" ...
fi
```

### Edge Cases
| Scenario | Behavior |
|----------|----------|
| First run | Full cost attributed to current project |
| Same project | Delta added to same project |
| Switch projects | Delta goes to NEW project |
| No project found | Delta not tracked (if git_repos_only=true) |
| Session restart | State file gone, starts fresh |

---

## Phase 6: Auto-Init Refinement

### Current Behavior
- Auto-create in git repos
- Auto-create if no project found anywhere (creates clutter)

### New Behavior
- Auto-create ONLY in git repos (if tracking.git_repos_only=true)
- No config created in random folders
- User manually creates umbrella projects

### Logic
```bash
init_project_if_needed() {
    local config="$cwd/.claude/statusline-project.json"

    # Already exists
    [[ -f "$config" ]] && return

    # Check config setting
    if [[ "$GIT_REPOS_ONLY" == "true" ]]; then
        # Only create in git repos
        [[ ! -d "$cwd/.git" ]] && return
    fi

    # Create with parent detection
    mkdir -p "$cwd/.claude" 2>/dev/null || return
    # ... create JSON with parent link
}
```

---

## Phase 7: Documentation

### Files to Create/Update

1. **README.md** - Already exists, update for new features
2. **docs/CONFIGURATION.md** - All config options explained
3. **docs/UPDATING.md** - How to update the script
4. **docs/DESIGN_DECISIONS.md** - Already exists, keep current

### CONFIGURATION.md Outline
```markdown
# Configuration

## Config File Location
## All Options Explained
## Environment Variables
## Project JSON Schema
## Umbrella Project Setup
## Health Color Customization
## Threshold Tuning
```

---

## File Structure (Final)

```
claude-statusline/
├── statusline-command.sh    # Main script
├── install.sh               # Interactive installer
├── uninstall.sh             # Clean removal
├── example-project.json     # Template for projects
├── example-config.json      # Template for user config
├── README.md                # Main documentation
├── LICENSE                  # MIT
├── .gitignore
├── docs/
│   ├── DESIGN_DECISIONS.md  # Architecture notes
│   ├── CONFIGURATION.md     # Config reference
│   └── UPDATING.md          # Update instructions
└── screenshots/
    ├── opus-statusline.png
    ├── sonnet-statusline.png
    └── haiku-statusline.png
```

---

## Implementation Order

1. **Phase 1: Stdin refactor** - Use JSON input, reduce transcript parsing
2. **Phase 2: Config system** - External config file
3. **Phase 3: Install script** - Interactive setup
4. **Phase 4: Umbrella improvements** - Per-project breakdown
5. **Phase 5: Delta tracking** - Accurate cost attribution
6. **Phase 6: Auto-init refinement** - Git repos only option
7. **Phase 7: Documentation** - Complete the docs

---

## Notes & Decisions

### Why 300ms is fine
- Claude Code debounces statusline calls to 300ms
- Event-driven (on message), not continuous polling
- Our caching (5-10s for heavy ops) is appropriate

### Why git repos only (default)
- Prevents `.claude/statusline-project.json` in random folders
- Users expect tracking in "real" projects
- Umbrella projects are explicitly created

### Why delta tracking
- Session cost is cumulative
- Folder switching would misattribute costs
- Delta tracking attributes cost to where work happened
- Simple state file in /tmp, no persistence needed

### Why external config
- Survives script updates
- User preferences preserved
- Can be version controlled separately
- Easy for install script to create
