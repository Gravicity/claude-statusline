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
    "git_repos_only": true,
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
| `git_repos_only` | boolean | `true` | Only auto-create project configs in git repos |
| `auto_create_umbrella` | boolean | `false` | Auto-create umbrella projects |

### `display`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pulse_animation` | boolean | `true` | Enable animated pulse on bottom line |
| `cost_cycling` | boolean | `true` | Cycle through /hr → session → project costs |

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
      "abc123": { "contributed": 8.20, "plan": "api" },
      "def456": { "contributed": 4.25, "plan": "api" }
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
| `costs` | Auto-managed cost tracking (don't edit manually) |

## Umbrella Project Config

For parent projects that aggregate costs from sub-projects:

```json
{
  "name": "Gravicity Projects",
  "icon": "🌌",
  "color": null,
  "git": null,
  "parent": null,
  "costs": {
    "total": 87.50,
    "projects": {
      "my-app": {
        "contributed": 12.45,
        "sessions": ["abc123", "def456"]
      },
      "api-server": {
        "contributed": 45.30,
        "sessions": ["ghi789", "jkl012"]
      }
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `costs.total` | Sum of all sub-project contributions |
| `costs.projects` | Per-sub-project breakdown |
| `costs.projects[name].contributed` | Total cost from that sub-project |
| `costs.projects[name].sessions` | Session IDs that contributed |

**Note:** Umbrella projects are regular project configs with `parent: null`. Sub-projects link to them via the `parent` field. Costs roll up automatically via delta tracking.

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
