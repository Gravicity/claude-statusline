# Claude Code Statusline

A beautiful, feature-rich statusline for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with animated pulse, model-specific themes, and project cost tracking.

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
╭─Opus─4.5─🧠─44%─📚─3─💰24.26/hr
│ 📁 ~/Gravicity../my-project
│ 🔀 feature-bra.. ↑2 ●3 ~5 +156-23 12m
│ ⧗ 2h15m 💬 42 +156-23 ※ a1b2c3
╰──────┉━━━━━◉╸╍┈────── 🛡 92%
```
*Git line only appears when in a git repo (4 lines otherwise)*

### Animated Pulse
- Smooth RGB gradient from theme color to health color
- Traveling orb with particle burst at end
- Health-based coloring (green/yellow/red)

### Real-Time Stats
- Context usage with health colors
- Memory files count (CLAUDE.md)
- Cycling costs: `/hr` burn rate → session total → `Σ` project total
- Code changes in session (+added/-removed)
- Git: branch, ahead/behind, staged/modified/untracked, diff, commit age
- Cache efficiency percentage
- Clickable session ID (opens transcript)

### Project Cost Tracking
Track costs across sessions with delta-based attribution:
- Costs attributed to the project where work actually happens
- Sub-projects link to parent for aggregate tracking
- Umbrella projects show breakdown by sub-project

## Installation

### Interactive Install (Recommended)

```bash
git clone https://github.com/gravicity/claude-statusline.git
cd claude-statusline
./install.sh
```

The installer will:
1. Check dependencies (jq, bc, git)
2. Ask about your Claude plan
3. Configure cost tracking options
4. Create your config file
5. Update Claude Code settings

### Quick Install

```bash
./install.sh --defaults
```

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

Config file: `~/.claude/statusline-config.json`

```json
{
  "plan": "api",
  "tracking": {
    "enabled": true,
    "git_repos_only": true
  },
  "display": {
    "pulse_animation": true,
    "cost_cycling": true
  },
  "thresholds": {
    "context_warn": 50,
    "context_crit": 75
  }
}
```

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for all options.

## Project Config

Create `.claude/statusline-project.json` in any project:

```json
{
  "name": "my-app",
  "icon": "🚀",
  "color": "#6366F1",
  "git": "https://github.com/user/my-app",
  "parent": "/path/to/umbrella/.claude/statusline-project.json"
}
```

Configs are auto-created in git repos if `git_repos_only` is enabled.

For umbrella projects that aggregate sub-project costs, see [example-umbrella.json](example-umbrella.json).

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
- Terminal with true color support (24-bit RGB)

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

| Terminal | Status |
|----------|--------|
| VS Code / Cursor | Full support |
| iTerm2 | Full support |
| macOS Terminal.app | Works (256-color) |
| Warp | Full support |

## License

MIT

---

Built with Claude
