# Claude Code Statusline

A beautiful, feature-rich statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with animated pulse, model-specific themes, and hierarchical project cost tracking.

![Opus Theme](screenshots/opus-statusline.png)
![Sonnet Theme](screenshots/sonnet-statusline.png)
![Haiku Theme](screenshots/haiku-statusline.png)

## Features

### Model-Specific Themes
Each Claude model gets its own color personality:
- **Opus**: Purple (royal, prestigious)
- **Sonnet**: Orange (warm, creative)
- **Haiku**: Teal (zen, minimal)

### Dynamic 4/5-Line Layout
```
╭─Opus─4.5─🧠─64%─📚─3─💰 2.59/hr
│ 📁 claude-statusline
│ ⚙ phase2-sessi.. ~4 +675-215
│ ⏱ 30h33m 💬2.1K +5.1K-2.3K ※a3013a
╰────────────────◉────── 🛡 94%
```

**Line breakdown:**
| Line | Content |
|------|---------|
| 1 | Model─Version─🧠─Context%─📚─Memory─💰Cost |
| 2 | Icon + Project name |
| 3 | Git: branch ↑ahead ↓behind ●staged ~modified +add-del age |
| 4 | ⏱Duration 💬Messages +Code-Removed ※SessionID |
| 5 | Pulse animation + 🛡Cache% |

*Git line (3) only appears when in a git repo*

### Animated Pulse
- Smooth RGB gradient from theme color to health color (truecolor terminals)
- Traveling orb with particle burst at end
- Health-based coloring (cyan/yellow/red)
- 256-color fallback for Terminal.app compatibility

### Real-Time Stats
- Context usage with health colors
- Memory files count (CLAUDE.md)
- Cycling costs: `/hr` burn rate → session total → `Σ` project total
- Code changes in session (+added/-removed)
- Git: branch, ahead/behind, staged/modified/untracked, diff, commit age
- Cache efficiency percentage
- Clickable session ID (opens transcript)

### Hierarchical Project Cost Tracking
Track costs across sessions with the Session Attribution Model:

```
~/.claude/statusline-project.json        (MASTER - all Claude usage)
├── ~/Projects/.claude/                   (Umbrella project)
│   ├── my-app/.claude/                   (Sub-project)
│   └── other-app/.claude/                (Sub-project)
```

- **MASTER root** at `~/.claude/` tracks total Claude usage across all projects
- **Session ownership**: Sessions belong to the project where they started
- **Breakdown tracking**: Sessions track `{ "_self": X, "child-name": Y }` for accurate attribution
- **Chain roll-up**: Costs propagate up: sub-project → umbrella → MASTER
- **Dedication**: Attribute umbrella session costs to specific sub-projects

## Installation

### Interactive Install (Recommended)

```bash
git clone https://github.com/gravicity/claude-statusline.git
cd claude-statusline
./install.sh
```

The interactive installer (7 steps):
1. **Claude Plan** - API, Max 5x, or Max 20x
2. **Cost Tracking** - Enable per-project tracking
3. **MASTER Root** - Create global tracker at `~/.claude/` (recommended)
4. **Auto-Create Mode** - When to auto-create project configs (see modes below)
5. **Umbrella** - Create umbrella for current directory
6. **Display** - Pulse animation and cost cycling
7. **Install** - Copy script and create config

### Quick Install (with defaults)

```bash
./install.sh --defaults
```

Creates script, config, and MASTER root with sensible defaults.

See [docs/QUICKSTART.md](docs/QUICKSTART.md) for detailed setup instructions.

### One-Liner

```bash
mkdir -p ~/.claude && curl -fsSL https://raw.githubusercontent.com/gravicity/claude-statusline/main/statusline-command.sh -o ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
```

Then add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

## Configuration

Config file: `~/.claude/statusline-config.json` (optional - sensible defaults used if absent)

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
    "cost_cycling": true,
    "path_cycling": true,
    "path_style": 0
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

*Additional `health_colors` config available—see [docs/CONFIGURATION.md](docs/CONFIGURATION.md).*

### Auto-Create Modes

| Mode | Projects created when... |
|------|--------------------------|
| `claude_folder` | `.claude/` folder exists (default) |
| `git_only` | Git repository detected |
| `git_and_claude` | Both `.git/` AND `.claude/` exist |
| `always` | Any directory |
| `never` | Manual `--init` only |

**When `.claude/` gets created:** Claude Code creates this folder when you select "don't ask again" for permissions (saves `settings.local.json`), use `/config`, or manually create it. The folder signals project-specific intent, making it a good trigger for statusline tracking.

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for all options.

## Project Config

Create `.claude/statusline-project.json` in any project:

```json
{
  "name": "my-app",
  "icon": "🚀",
  "color": "#6366F1",
  "git": "https://github.com/user/my-app",
  "parent": "/path/to/umbrella/.claude/statusline-project.json",
  "costs": { ... }
}
```

*The `costs` object is auto-populated with session data, totals, and breakdowns.*

### Hierarchy Setup

```bash
# 1. Create MASTER root (one-time, tracks all Claude usage)
~/.claude/statusline-command.sh --init-master

# 2. Create umbrella for a projects folder
~/.claude/statusline-command.sh --init-umbrella ~/Projects

# 3. Create sub-projects (auto-links to parent)
~/.claude/statusline-command.sh --init ~/Projects/my-app
```

Configs are auto-created based on your `auto_create_mode` setting (default: `claude_folder`).

### Examples

| File | Description |
|------|-------------|
| [example-master.json](example-master.json) | MASTER root config (`~/.claude/`) |
| [example-umbrella.json](example-umbrella.json) | Umbrella project with child tracking |
| [example-project.json](example-project.json) | Sub-project (leaf node) |
| [example-config.json](example-config.json) | User config file |

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for detailed hierarchy documentation.

## Updating

```bash
./install.sh --update
```

Or manually:
```bash
curl -fsSL https://raw.githubusercontent.com/gravicity/claude-statusline/main/statusline-command.sh -o ~/.claude/statusline-command.sh
```

See [docs/UPDATING.md](docs/UPDATING.md) for details.

## Uninstall

```bash
./uninstall.sh
```

Or manually:
```bash
rm ~/.claude/statusline-command.sh ~/.claude/statusline-config.json
rm -rf ~/.cache/claude-statusline
```

## Requirements

- Claude Code
- `jq` for JSON parsing
- `bc` for calculations
- Any terminal (256-color minimum, truecolor recommended)

## How It Works

The statusline receives JSON input from Claude Code via stdin:
- Triggered on message updates (300ms debounce)
- Uses Claude's provided cost, model, and line stats
- Parses transcript only for context %, cache %, message count

Cost tracking uses delta attribution:
- Tracks "last known cost" per session
- Only the change (delta) is attributed to current project
- Accurate even when switching between project folders

## Terminal Compatibility

The statusline automatically detects terminal capabilities via `$COLORTERM`:

| Terminal | Truecolor | Features |
|----------|-----------|----------|
| **iTerm2** | ✅ Yes | Full RGB gradients, smooth pulse animation |
| **Kitty** | ✅ Yes | Full RGB gradients, GPU-accelerated |
| **VS Code / Cursor** | ✅ Yes | Full RGB gradients |
| **Warp** | ✅ Yes | Full RGB gradients |
| **macOS Terminal.app** | ❌ No | 256-color fallback, simplified pulse |

### IDE Users

Most users run Claude Code in an IDE like **VS Code** or **Cursor**—these already support truecolor, so the statusline works perfectly out of the box.

### Terminal Power Users

If you run Claude directly in a terminal, **iTerm2** or **Kitty** are highly recommended for the full experience:

```bash
# iTerm2 - Feature-rich, macOS native feel
brew install --cask iterm2

# Kitty - Fast, GPU-accelerated, keyboard-driven
brew install --cask kitty
```

### 256-Color Fallback

If your terminal doesn't support truecolor (like macOS Terminal.app), the statusline automatically:
- Uses 256-color palette approximations
- Simplifies pulse animation (moving orb without gradient)
- All functionality works, just less visually fancy

**Detection:** The script checks `$COLORTERM` for `truecolor` or `24bit`. Truecolor terminals set this automatically.

## CLI Commands

```bash
# Initialize MASTER root (tracks all Claude usage)
~/.claude/statusline-command.sh --init-master

# Initialize umbrella project
~/.claude/statusline-command.sh --init-umbrella [path]

# Initialize sub-project
~/.claude/statusline-command.sh --init [path]

# Dedicate session costs to a sub-project
~/.claude/statusline-command.sh --dedicate <session-id> <project-name>

# Sync/reconcile project costs
~/.claude/statusline-command.sh --sync [path]

# Show help
~/.claude/statusline-command.sh --help
```

## Background

As a father of two, my coding sessions get interrupted—a lot. I often have several terminals with Claude running, and sometimes hours or days go by before I come back to a wall of sessions (or none at all after an IDE crash). Coming back after a great session just to figure out where I left off felt daunting.

I wanted to see which model I was using, how much context I'd burned through, what branch I was on, whether the repo was up to date—all at a glance. Running `/cost` or `/model` hundreds of times gets old. And asking Claude to recall any of this wastes context and pollutes it.

This started as that quick hack, then grew into cost tracking across my [Gravicity](https://github.com/Gravicity) umbrella project where I kept losing track of what I'd spent where. The idea kept evolving from there (see [docs/PHASE2-PLAN.md](docs/PHASE2-PLAN.md) for the rabbit hole).

**Project stats** (tracked by the statusline itself):
- Started: November 29, 2025
- Tracked cost: ~$90 (API estimates)
- Actual cost: Probably $100-120—delta tracking wasn't working until mid-project

Cost tracking isn't essential on the Max 20x plan, but it's useful for understanding where time actually goes.

## Roadmap

### Completed

**Display**
- Model-specific themes (Opus/Sonnet/Haiku)
- Truecolor gradient pulse + 256-color fallback
- Health-colored context/staleness indicators
- 3 cost display modes with cycling (burn rate → session → project total)
- 3 path display styles with cycling
- Git stats (branch, ahead/behind, staged/modified/untracked, diff, commit age)
- Clickable session ID (opens transcript)

**Tracking**
- Hierarchical cost tracking (MASTER → Umbrella → Project)
- Session attribution with breakdown structure
- Delta cost tracking (accurate across folder switches)
- 5 auto-create modes (never/git_only/claude_folder/git_and_claude/always)
- Atomic file locking with stale cleanup + retry
- Transcript and git caching

**CLI**
- `--init-master`, `--init-umbrella`, `--init` for hierarchy setup
- `--dedicate` for session cost attribution
- `--sync` for cost reconciliation

### Ideas

Some ideas that might happen:

- **Session summaries** - Brief summaries updated over time (after compacts or on request), stored in project logs with session IDs for easy resumption via `claude --resume <id>`
- **Smart keyword tagging** - Track key topics and features worked on for quick reference and filtering
- **Budget alerts** - Warnings when approaching cost thresholds
- **Compact offloading** - Delegate chat compaction to external Haiku sessions or general agents, reducing context bloat and enabling smarter project memory updates
- **Export/reports** - CSV/JSON export for expense tracking

No promises, no timeline. PRs welcome.

## Support

If this saves you time or money (or just looks cool), consider:
- ⭐ Starring the repo
- 🐛 Reporting issues
- 💡 Suggesting features
- ☕ [Sponsoring](https://github.com/sponsors/Gravicity) (coming soon)

## License

MIT

---

Built with Claude
