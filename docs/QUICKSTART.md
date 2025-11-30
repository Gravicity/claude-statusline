# Quick Start Guide

Get the Claude Code statusline running in under 2 minutes.

## Option A: Automatic Install (Recommended)

```bash
# Clone and install
git clone https://github.com/gravicity/claude-statusline.git
cd claude-statusline
./install.sh
```

Follow the 7-step interactive prompts. For all defaults:

```bash
./install.sh --defaults
```

**Done!** Restart Claude Code to see your statusline.

---

## Option B: Manual Setup

### 1. Install Dependencies

```bash
# macOS
brew install jq bc git

# Ubuntu/Debian
sudo apt install jq bc git
```

### 2. Create Directory

```bash
mkdir -p ~/.claude
mkdir -p ~/.cache/claude-statusline
```

### 3. Download Script

```bash
curl -fsSL https://raw.githubusercontent.com/gravicity/claude-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

### 4. Create Config File

Create `~/.claude/statusline-config.json`:

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
    "context_crit": 75
  }
}
```

**auto_create_mode options:**
| Mode | Projects created when... |
|------|--------------------------|
| `claude_folder` | `.claude/` folder exists (default) |
| `git_only` | Git repository detected |
| `git_and_claude` | Both `.git/` AND `.claude/` exist |
| `never` | Only via manual `--init` |

**When projects are created:** With `claude_folder` mode (default), statusline projects are created when a `.claude/` folder exists. Claude creates this folder when you run `claude init` or select "don't ask again" for permissions—signaling project-specific intent. Users with global settings may prefer `git_only` or `git_and_claude` modes.

### 5. Create MASTER Root (Optional but Recommended)

```bash
~/.claude/statusline-command.sh --init-master
```

This creates `~/.claude/statusline-project.json` which tracks total Claude usage across all projects.

### 6. Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

### 7. Restart Claude Code

Close and reopen Claude Code. You should see the statusline.

---

## Setting Up Project Hierarchy

### Create Umbrella (for a projects folder)

```bash
~/.claude/statusline-command.sh --init-umbrella ~/Projects
```

### Create Sub-Project

```bash
~/.claude/statusline-command.sh --init ~/Projects/my-app
```

The sub-project automatically links to the nearest parent (umbrella or MASTER).

### Hierarchy Example

```
~/.claude/statusline-project.json        (MASTER - tracks everything)
├── ~/Projects/.claude/                   (Umbrella)
│   ├── my-app/.claude/                   (Sub-project)
│   └── api-server/.claude/               (Sub-project)
```

Costs roll up: sub-project → umbrella → MASTER

---

## Verify Installation

```bash
# Check script exists
ls -la ~/.claude/statusline-command.sh

# Check config exists
cat ~/.claude/statusline-config.json

# Check MASTER exists (if created)
cat ~/.claude/statusline-project.json

# Test script help
~/.claude/statusline-command.sh --help
```

---

## Terminal Compatibility

| Terminal | Truecolor | Notes |
|----------|-----------|-------|
| iTerm2 | ✅ | Full RGB gradients |
| Kitty | ✅ | Full RGB gradients |
| VS Code/Cursor | ✅ | Full RGB gradients |
| macOS Terminal.app | ❌ | 256-color fallback (works, less fancy) |

For best experience on macOS:

```bash
brew install --cask iterm2
```

---

## Troubleshooting

### Statusline not appearing
1. Check settings.json has `statusLine` configured
2. Restart Claude Code completely
3. Verify script is executable: `chmod +x ~/.claude/statusline-command.sh`

### Colors look wrong (Terminal.app)
- This is normal - Terminal.app doesn't support truecolor
- Install iTerm2 or Kitty for full colors
- Or just use it as-is (256-color fallback works fine)

### Costs not tracking
1. Ensure `tracking.enabled` is `true` in config
2. Check project config exists: `.claude/statusline-project.json`
3. Run `--sync` to reconcile: `~/.claude/statusline-command.sh --sync`

---

## Next Steps

- [CONFIGURATION.md](CONFIGURATION.md) - All config options
- [PHASE2-PLAN.md](PHASE2-PLAN.md) - Session attribution model details
- [README.md](../README.md) - Full documentation
