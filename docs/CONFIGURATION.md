# Configuration Reference

The statusline is configured via `~/.claude/statusline-config.json`. All settings are optional - defaults are used if not specified.

## Config File Location

```
~/.claude/statusline-config.json
```

## Full Example

```json
{
  "version": 1,
  "plan": "api",
  "tracking": {
    "enabled": true,
    "auto_create_mode": "claude_folder",
    "auto_create_umbrella": false
  },
  "display": {
    "pulse_animation": true,
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

## Options Explained

### `plan`
Your Claude subscription plan. Affects cost awareness display.
- `"api"` - Pay per use (default)
- `"max5x"` - Pro with 5x usage
- `"max20x"` - Pro with 20x usage

Can also be set via environment variable: `export CLAUDE_PLAN="max5x"`

### `tracking`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable project cost tracking |
| `auto_create_mode` | string | `"claude_folder"` | When to auto-create project configs (see below) |
| `auto_create_umbrella` | boolean | `false` | Auto-create umbrella projects |

**auto_create_mode values:**

| Mode | Description |
|------|-------------|
| `"never"` | Never auto-create; use `--init` manually |
| `"git_only"` | Create when `.git/` directory exists |
| `"claude_folder"` | Create when `.claude/` folder exists (default) |
| `"git_and_claude"` | Create only when both `.git/` AND `.claude/` exist |
| `"always"` | Create in any directory |

**Recommended:** `claude_folder` (default) - Projects are naturally "born" when you start Claude in a new folder, since Claude creates `.claude/` on init or permission acceptance. This follows Claude's own "this is a Claude project" signal.


### `display`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pulse_animation` | boolean | `true` | Enable animated pulse on bottom line |
| `cost_cycling` | boolean | `true` | Cycle through /hr → session → project costs |
| `path_cycling` | boolean | `true` | Cycle through path display styles |
| `path_style` | integer | `0` | Path style when cycling disabled (0=forward, 1=project+depth, 2=reverse) |

**Path Styles:**
- `0` (forward): `~/Gravicity…/.claude/sk…` - truncates from end
- `1` (project+depth): `Gravicity…//field-comm…` - shows project, depth slashes, last folder
- `2` (reverse): `…skills/field-commander` - truncates from start, shows end of path

### `health_colors`

RGB values for health indicators. Format: `[R, G, B]`

| Color | Default | Hex | Usage |
|-------|---------|-----|-------|
| `good` | `[34, 197, 94]` | #22C55E | Low context, fresh commits |
| `warn` | `[234, 179, 8]` | #EAB308 | Medium context, stale commits |
| `crit` | `[239, 68, 68]` | #EF4444 | High context, very stale commits |

### `thresholds`

Configurable thresholds for health coloring.

| Threshold | Default | Description |
|-----------|---------|-------------|
| `context_warn` | 50 | Context % for yellow warning |
| `context_crit` | 75 | Context % for red critical |
| `memory_warn` | 4 | Memory file count for warning |
| `memory_crit` | 8 | Memory file count for critical |
| `staleness_warn` | 100 | Git staleness score for warning |
| `staleness_crit` | 500 | Git staleness score for critical |

**Staleness Score**: `(staged_files + modified_files) × minutes_since_commit`

## Project Hierarchy (Phase 2)

The statusline uses a hierarchical project structure:

```
~/.claude/statusline-project.json          (MASTER root)
├── ~/Gravicity Projects/                   (umbrella)
│   ├── ~/Gravicity Projects/my-app/       (sub-project)
│   └── ~/Gravicity Projects/api-server/   (sub-project)
└── ~/other-projects/                       (another umbrella)
```

**Key concepts:**
- **MASTER root** (`~/.claude/statusline-project.json`): Top of the hierarchy, all costs roll up here
- **Umbrella projects**: Parent folders containing multiple related projects
- **Sub-projects**: Individual projects with a parent reference

## Session Attribution Model (Phase 2)

Sessions are tracked using a **breakdown** structure that shows exactly where time was spent:

```json
{
  "sessions": {
    "abc123": {
      "started": "2025-11-30T08:00:00Z",
      "transcript": "/path/to/transcript.jsonl",
      "total_cost": 50.00,
      "breakdown": {
        "_self": 5.00,           // Work done at this project level
        "my-app": 35.00,         // Work done in my-app subfolder
        "api-server": 10.00      // Work done in api-server subfolder
      }
    }
  }
}
```

**Session ownership rules:**
1. Session belongs to the project where `cwd` was when session **started**
2. As you navigate between folders, costs route to the appropriate `breakdown` key
3. `_self` tracks work done directly in the session's home project
4. Child project names track work done in subfolders

## Project Config

Per-project settings in `.claude/statusline-project.json`:

```json
{
  "name": "my-app",
  "icon": "🚀",
  "color": "#6366F1",
  "git": "https://github.com/user/my-app",
  "parent": "/Users/user/projects/.claude/statusline-project.json",
  "costs": {
    "total": 12.45,
    "sessions": {
      "abc123": {
        "started": "2025-11-30T08:00:00Z",
        "transcript": "/path/to/transcript.jsonl",
        "total_cost": 8.20,
        "breakdown": { "_self": 8.20 }
      }
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `name` | Display name for the project |
| `icon` | Emoji icon shown in statusline |
| `color` | Custom accent color (hex, currently unused) |
| `git` | Git remote URL (auto-detected) |
| `parent` | Path to parent/umbrella project config |
| `costs.sessions` | Session records with breakdown tracking |
| `costs.sessions[id].breakdown` | Where the session's costs went |
| `costs.total` | Sum of all session total_costs + child contributions |

## Umbrella Project Config

For parent projects that aggregate costs from sub-projects:

```json
{
  "name": "Gravicity Projects",
  "icon": "🌌",
  "color": "#6366F1",
  "git": null,
  "parent": "/Users/user/.claude/statusline-project.json",
  "costs": {
    "total": 87.50,
    "sessions": {
      "xyz789": {
        "started": "2025-11-30T10:00:00Z",
        "total_cost": 60.00,
        "breakdown": {
          "_self": 10.00,
          "my-app": 35.00,
          "api-server": 15.00
        }
      }
    },
    "projects": {
      "my-app": {
        "contributed": 12.45,
        "sessions": ["abc123", "xyz789"]
      },
      "api-server": {
        "contributed": 15.00,
        "sessions": ["xyz789"]
      }
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `costs.total` | Sum of all sessions' total_cost + child project contributions |
| `costs.sessions` | Sessions that **started** in this umbrella |
| `costs.projects` | Roll-up totals from child projects |
| `costs.projects[name].contributed` | Total cost attributed to that child |
| `costs.projects[name].sessions` | Session IDs that contributed to that child |

## MASTER Root Config

The global root at `~/.claude/statusline-project.json`:

```json
{
  "name": "Claude Master Statusline",
  "icon": "🏠",
  "color": "#8B5CF6",
  "git": null,
  "parent": null,
  "costs": {
    "sessions": {},
    "total": 150.00,
    "projects": {
      "Gravicity Projects": {
        "contributed": 87.50
      },
      "other-umbrella": {
        "contributed": 62.50
      }
    }
  }
}
```

All costs eventually roll up to MASTER, giving you a complete picture of Claude usage.

## CLI Commands

The statusline script includes several CLI commands for managing projects:

```bash
# Create MASTER root (top of hierarchy, run once)
~/.claude/statusline-command.sh --init-master

# Create umbrella project (parent for multiple sub-projects)
~/.claude/statusline-command.sh --init-umbrella ~/projects

# Create regular project (auto-links to parent umbrella if found)
~/.claude/statusline-command.sh --init-project
~/.claude/statusline-command.sh --init-project ~/projects/my-app

# Sync project costs with actual session data
# Also migrates old sessions to Phase 2 breakdown format
~/.claude/statusline-command.sh --sync

# Dedicate session's _self cost to a specific child project
# Moves unattributed work from _self to the specified project
~/.claude/statusline-command.sh --dedicate abc123 ~/projects/my-app

# Show help
~/.claude/statusline-command.sh --help
```

### When to Use `--sync`

Use the sync command when:
- You created a project config mid-session (missed earlier costs)
- Cost tracking seems out of sync with statusline display
- After recovering from tracking bugs or data migration
- **To migrate old sessions** to the new Phase 2 breakdown format

**Note:** Sync reads from session state files in `~/.cache/claude-statusline/`. Sessions without state files (older/inactive sessions) cannot be synced and will be skipped.

### When to Use `--dedicate`

Use the dedicate command when:
- You worked in an umbrella project but the work was really for a specific child
- You want to re-attribute `_self` costs to a child project

**Example:** You started a session in `~/Gravicity Projects` and did work there. Later you realize all that work was for `my-app`. Use `--dedicate session-id ~/Gravicity Projects/my-app` to move the `_self` amount to `my-app` in the breakdown.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_PLAN` | Override plan from config |
| `CLAUDE_IDE_SCHEME` | URL scheme for transcript links (default: `file://`) |
| `STATUSLINE_DEBUG` | Set to `1` to dump input JSON to cache |

## Cache Directory

Cached data is stored in:
```
~/.cache/claude-statusline/
```

Contents:
- `session-{id}.state` - Delta tracking state per session
- `transcript-{hash}.cache` - Parsed transcript data
- `git-{hash}.cache` - Git status cache
- `git-stats-{hash}.cache` - Detailed git stats cache
- `git-url-{hash}.cache` - Git remote URL cache
