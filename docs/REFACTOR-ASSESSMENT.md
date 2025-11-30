# Refactoring Assessment

**Date:** 2025-11-30
**Script Size:** 1352 lines (post-Phase 2)
**Decision:** Documentation only, no structural refactor

## Feature Inventory

### CLI Commands (6)
- `--init-master` - Creates MASTER root at ~/.claude/
- `--init-umbrella` - Creates umbrella project
- `--init-project` - Creates project with git/parent detection
- `--sync` - Syncs costs, migrates Phase 1→2
- `--dedicate` - Moves _self to child in breakdown
- `--help` - Shows CLI help

### Config Options (17)
- `plan` - api/max5x/max20x
- `tracking.enabled` - boolean
- `tracking.auto_create_mode` - never/git_only/claude_folder/git_and_claude/always
- `tracking.auto_create_umbrella` - boolean
- `display.pulse_animation` - boolean
- `display.cost_cycling` - boolean
- `display.path_cycling` - boolean
- `display.path_style` - 0/1/2
- `health_colors.good/warn/crit` - RGB arrays
- `thresholds.context_warn/crit` - numbers
- `thresholds.memory_warn/crit` - numbers
- `thresholds.staleness_warn/crit` - numbers

### Display Features
- 3 model themes (Sonnet/Opus/Haiku)
- 3 path display styles with cycling
- 3 cost display modes with cycling
- Truecolor gradient pulse + 256-color fallback
- Git stats (branch, ↑↓, staged, modified, untracked, diff, commit age)
- Clickable session ID
- Health-colored indicators

### Tracking Features
- Auto-create with 5 modes
- Session home + breakdown structure
- Chain roll-up (project → umbrella → MASTER)
- Atomic file locking with 60s stale cleanup
- Transcript caching (MD5 hash)
- Git caching (5s/60s)

## Refactoring Options Considered

| Option | Effort | Risk | Savings | Decision |
|--------|--------|------|---------|----------|
| **A: Modular split** | High | Medium | ~200 lines | Rejected |
| **B: Function extraction** | Medium | Low | ~100 lines | Deferred |
| **C: Documentation only** | Low | None | Readability | **Selected** |

### Option A: Modular Split
Split into separate files:
- `statusline-cli.sh` - CLI commands (~400 lines)
- `statusline-core.sh` - Main statusline (~900 lines)

**Rejected because:**
- More files to manage
- Potential sourcing issues
- Need to maintain single entry point for Claude Code
- Complexity not justified for bash script

### Option B: Function Extraction
Keep single file but extract repeated patterns:
- `acquire_lock()` / `release_lock()` (~20 lines saved)
- `rgb_color()` / `color_256()` helpers
- Grouped related functions

**Deferred because:**
- Savings (~100 lines) not significant
- Risk of breaking working features
- 1352 lines is manageable for bash

### Option C: Documentation Only (Selected)
Added better comments and section headers without restructuring:
- Header banner with feature summary
- `# --- Section Name ---` headers throughout
- Documented all CLI commands
- Explained key logic

**Why selected:**
- Zero risk to functionality
- Improves maintainability
- All features preserved

## What Was Done

Added 25 lines of documentation:

```bash
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
```

Section headers added:
- `# --- CLI Mode ---`
- `# --- CLI Command: --init-master ---` (etc. for each command)
- `# --- Configuration ---`
- `# --- Colors & Truecolor Detection ---`
- `# --- Model Theme ---`
- `# --- Project Detection ---`
- `# --- Auto-Create Project ---`
- `# --- Delta Cost Tracking ---`
- `# --- Memory Files ---`
- `# --- Transcript Parsing (Cached) ---`
- `# --- Path Display ---`
- `# --- Git Info (Cached) ---`
- `# --- BUILD OUTPUT ---` (with line layout diagram)
- `# --- Final Output ---`

## Future Refactoring (If Ever Needed)

If the script grows significantly (>2000 lines), consider:

1. **Extract lock helpers** - Used 3x, could be DRY
2. **Color abstraction** - Single function handling 256/truecolor
3. **Config validation** - Separate function for loading/validating config
4. **Test suite** - Shell unit tests for CLI commands

For now, the script is stable and well-documented.
