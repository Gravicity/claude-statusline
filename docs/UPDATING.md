# Updating Claude Code Statusline

## Quick Update

If you have the repo cloned:

```bash
cd /path/to/claude-statusline
git pull
./install.sh --update
```

This updates the script while preserving your config.

## One-Liner Update

```bash
curl -fsSL https://raw.githubusercontent.com/gravicity/claude-statusline/main/statusline-command.sh \
  -o ~/.claude/statusline-command.sh && chmod +x ~/.claude/statusline-command.sh
```

## Manual Update

1. Download the latest `statusline-command.sh`
2. Replace `~/.claude/statusline-command.sh`
3. Make executable: `chmod +x ~/.claude/statusline-command.sh`

Your config (`~/.claude/statusline-config.json`) is not affected.

## Version History

### v2.0 (Current)
- Stdin JSON input (faster, more reliable)
- External config file support
- Delta cost tracking (accurate project attribution)
- Umbrella project breakdown by sub-project
- Git repos only auto-init option
- Configurable health colors and thresholds
- Interactive install script

### v1.0
- Initial release
- Transcript parsing for all stats
- Hardcoded configuration
- Basic cost tracking

## Breaking Changes

### v1.0 → v2.0

**Cost tracking format changed:**

Old format:
```json
{
  "costs": {
    "sessions": {
      "session-id": { "cost": 35.00 }
    }
  }
}
```

New format (delta-based):
```json
{
  "costs": {
    "sessions": {
      "session-id": { "contributed": 35.00 }
    }
  }
}
```

Existing project configs will continue to work, but cost totals may reset on first update.

**Umbrella projects now track by sub-project:**
```json
{
  "costs": {
    "projects": {
      "sub-project-name": { "contributed": 35.00 }
    }
  }
}
```

## Troubleshooting

### Statusline not appearing after update

1. Check settings.json has correct path:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline-command.sh"
     }
   }
   ```

2. Verify script is executable:
   ```bash
   chmod +x ~/.claude/statusline-command.sh
   ```

3. Test manually:
   ```bash
   echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline-command.sh
   ```

### Config not loading

1. Verify JSON syntax:
   ```bash
   jq . ~/.claude/statusline-config.json
   ```

2. Check file permissions:
   ```bash
   ls -la ~/.claude/statusline-config.json
   ```

### Clear cache

```bash
rm -rf ~/.cache/claude-statusline
```

This clears all cached data. Safe to do anytime.
