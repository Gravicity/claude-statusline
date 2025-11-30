# Phase 2: Session Attribution Model

## Implementation Status: ✅ COMPLETE (2025-11-30)

All core Phase 2 features have been implemented:
- [x] MASTER root at ~/.claude/statusline-project.json
- [x] Hierarchy: MASTER → Umbrella → Sub-projects
- [x] Session `started` timestamp from transcript ctime
- [x] Breakdown structure (`_self`, child names)
- [x] Session home tracking (set once in state file)
- [x] Chain roll-up (child → parent → MASTER)
- [x] Updated `--dedicate` for breakdown model
- [x] Updated `--sync` with migration support
- [x] Documentation updated

### Additional Updates (2025-11-30)
- [x] Terminal color compatibility - 256-color fallback implemented
- [x] Duration icon changed from `⧗` to `⏱` for better compatibility
- [x] install.sh updated with MASTER creation (step 3/7 in interactive flow)
- [x] install.sh 256-color fallback for Terminal.app users
- [x] Example JSON files updated (example-master.json, example-umbrella.json, example-project.json)
- [x] README updated with hierarchy documentation and examples table
- [x] `auto_create_mode` config option replacing `git_repos_only` (5 modes: never, git_only, claude_folder, git_and_claude, always)
- [x] Config file now optional - sensible defaults used when absent
- [x] QUICKSTART.md documentation created

### All Issues Resolved
- [x] Test new session tracking from MASTER level (working)

## Terminal Issues (Discovered 2025-11-30)

### Problem: macOS Terminal.app Doesn't Support Truecolor

**Symptoms:**
- Yellow/red background bleeding into terminal
- Colors appearing as white or incorrect shades
- Background color persisting after statusline output

**Root Cause:**
macOS Terminal.app only supports 256-color palette, NOT 24-bit truecolor (16 million colors).

**How Truecolor Works:**
```bash
# Truecolor escape sequences (require terminal support)
\x1b[38;2;R;G;Bm   # Foreground color (R,G,B = 0-255)
\x1b[48;2;R;G;Bm   # Background color
```

When Terminal.app receives these sequences, it attempts to map them to its 256-color palette, often with poor results:
- Pure red `(255,0,0)` → appears white or incorrect
- Purple `(139,92,246)` → maps reasonably well
- Green `(34,197,94)` → maps reasonably well
- Orange/yellow `(249,115,22)` → fails badly

**Detection:**
```bash
# Check $COLORTERM - should be "truecolor" or "24bit"
echo $COLORTERM  # Terminal.app: empty or missing

# Check $TERM
echo $TERM       # Terminal.app: xterm-256color (misleading name)
```

**Solutions:**

1. **Install a Truecolor Terminal** (Recommended):
   - iTerm2: `brew install --cask iterm2`
   - Kitty: `brew install --cask kitty`
   - Alacritty: `brew install --cask alacritty`
   - WezTerm: `brew install --cask wezterm`

2. **Add 256-color Fallback** (Future enhancement):
   ```bash
   # Detect truecolor support
   if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
       # Use RGB colors
       color="\x1b[38;2;${r};${g};${b}m"
   else
       # Fall back to 256-color palette
       color="\x1b[38;5;${palette_index}m"
   fi
   ```

**Implemented Fix (2025-11-30):**
Script now detects `$COLORTERM` environment variable:
- If `truecolor` or `24bit`: Uses full RGB gradients
- Otherwise: Falls back to 256-color palette codes

256-color fallback includes:
- CLI colors (purple, green, yellow, slate)
- Health colors (good/warn/crit)
- Muted slate for disabled indicators
- Simplified pulse animation (no gradient, just moving orb)

The THEME_PRIMARY and THEME_ACCENT were already using 256-color codes, so model theming works in both modes.

## Problem Statement
Current tracking has issues:
1. Session records duplicated across parent and child projects
2. `contributed: 0` is misleading after dedication (session DID contribute)
3. No session start time tracking
4. Can't accurately track split sessions (work across multiple projects in one session)

## Proposed Data Model

### Session Record Structure
Session lives WHERE IT STARTED, with breakdown of where costs went:

```json
// Parent/Umbrella project (e.g., ~/Gravicity Projects/.claude/statusline-project.json)
{
  "name": "Gravicity Projects",
  "sessions": {
    "a3013a": {
      "started": "2025-11-30T02:00:00Z",
      "transcript": "/path/to/transcript.jsonl",
      "total_cost": 63.60,
      "breakdown": {
        "_self": 5.00,              // Work done at THIS project level
        "claude-statusline": 55.60, // Work done while cwd was in this child
        "verivox": 3.00             // Work done while cwd was in another child
      }
    },
    "b4e2f1": {
      "started": "2025-11-29T10:00:00Z",
      "transcript": "...",
      "total_cost": 12.00,
      "breakdown": {
        "_self": 12.00  // All work at umbrella level
      }
    }
  },
  "projects": {
    "claude-statusline": {
      "contributed": 55.60,
      "sessions": ["a3013a"]  // Which sessions contributed
    },
    "verivox": {
      "contributed": 3.00,
      "sessions": ["a3013a"]
    }
  },
  "costs": {
    "total": 75.60,  // Sum of all sessions' total_cost
    "direct": 17.00  // Sum of all _self (work at this level)
  }
}
```

### Child Project Structure
Simpler - references parent's tracking:

```json
// Child project (e.g., ~/Gravicity Projects/claude-statusline/.claude/statusline-project.json)
{
  "name": "claude-statusline",
  "parent": "/Users/user/Gravicity Projects/.claude/statusline-project.json",
  "own_sessions": {
    // Sessions that STARTED in this project (user ran claude from here)
    "c7d8e9": {
      "started": "2025-11-30T14:00:00Z",
      "transcript": "...",
      "total_cost": 8.00,
      "breakdown": {
        "_self": 8.00
      }
    }
  },
  "costs": {
    "from_parent": 55.60,     // What parent's breakdown says we got
    "own_total": 8.00,        // Sum of own_sessions
    "total": 63.60            // from_parent + own_total
  }
}
```

## Key Rules

1. **Session Ownership**: Session belongs to project where `cwd` was when session STARTED
   - Determined by checking which project config contains the cwd at first statusline render

2. **Breakdown Tracking**: As user moves between projects during session:
   - If in parent project: `breakdown._self += delta`
   - If in child project: `breakdown["child-name"] += delta`

3. **Child Detection**: Compare current `cwd` against known child projects
   - Child has `parent` field pointing to this config
   - Or detect by checking if cwd is under a subdirectory with its own config

4. **Roll-up Calculation**:
   - Project total = sum(own_sessions.total_cost) + sum(from parent breakdown)
   - Or for umbrella: sum(all sessions.total_cost)

5. **--dedicate Behavior**:
   - Moves amount from `breakdown._self` to `breakdown["child-name"]`
   - Updates parent's `projects[child].contributed`
   - Does NOT move session record - just re-attributes within breakdown

## Implementation Tasks

### 1. Add 'started' timestamp
- On first render of new session, get transcript file ctime
- Store in session record

### 2. Refactor session structure
- Change from `sessions[id].contributed` to `sessions[id].breakdown`
- Add `total_cost` field (actual session cost from state file)

### 3. Track session home project
- Store which project "owns" the session
- First project to see session claims it

### 4. Update delta tracking
- Detect if cwd is in a child project
- Route delta to appropriate breakdown key

### 5. Update --dedicate
- Instead of zeroing parent session, modify breakdown
- Move `_self` to specified child

### 6. Update --sync
- Handle new breakdown structure
- Reconcile total_cost with actual transcript/state data

### 7. Migrate existing data
- Convert old `contributed` to `breakdown._self`
- Handle dedicated sessions (currently have `contributed: 0`)

## Migration Path

For existing data like:
```json
"sessions": {
  "a3013a": {
    "contributed": 0,
    "dedicated_to": "claude-statusline"
  }
}
```

Convert to:
```json
"sessions": {
  "a3013a": {
    "total_cost": 63.60,
    "breakdown": {
      "_self": 0,
      "claude-statusline": 63.60
    }
  }
}
```

## Answered Design Questions

1. **Do child projects track their own sessions?**
   YES - A child can have sessions that STARTED there. A child becomes a parent when it has subfolders with their own repos/configs.

2. **What if session starts in child but parent doesn't exist?**
   The chain ALWAYS goes up to `~/.claude/statusline-project.json` (master). Every project has a parent, ultimately rooted at ~/.claude.

3. **Does grandparent track grandchild breakdown?**
   NO - Each level only tracks IMMEDIATE children. Grandparent sees child's total (which already includes grandchild contributions rolled up).

## Hierarchy Example

```
~/.claude/statusline-project.json                    (MASTER - root of all)
├── sessions: { own sessions started at ~ level }
├── projects: {
│     "Gravicity Projects": { contributed: 75.00 }   // Just the total
│   }

~/Gravicity Projects/.claude/statusline-project.json  (umbrella)
├── parent: ~/.claude/statusline-project.json
├── sessions: {
│     "a3013a": {
│       breakdown: { _self: 5, "claude-statusline": 55, "verivox": 15 }
│     }
│   }
├── projects: {
│     "claude-statusline": { contributed: 55 },
│     "verivox": { contributed: 15 }
│   }

~/Gravicity Projects/claude-statusline/.claude/       (leaf project)
├── parent: ~/Gravicity Projects/.claude/statusline-project.json
├── sessions: { sessions that STARTED here }
├── costs: { from_parent: 55, own: X, total: 55+X }
```

**Roll-up flow:**
1. claude-statusline reports total (from_parent + own) UP to Gravicity Projects
2. Gravicity Projects reports its total UP to ~/.claude master
3. Master sees all costs, but only immediate children breakdown

## Files to Modify

- `statusline-command.sh`: Main tracking logic
- `docs/CONFIGURATION.md`: Document new structure
- Existing project configs: Migration needed

## Implementation Notes (Context Preservation)

### File Locations
- **Main script**: `/Users/user/Gravicity Projects/claude-statusline/statusline-command.sh`
- **Installed script**: `~/.claude/statusline-command.sh` (copy after testing)
- **Umbrella config**: `/Users/user/Gravicity Projects/.claude/statusline-project.json`
- **Sub-project config**: `/Users/user/Gravicity Projects/claude-statusline/.claude/statusline-project.json`
- **State files**: `~/.cache/claude-statusline/session-{id}.state`
- **State file format**: `{cost}|{project_config_path}`

### Key Functions in statusline-command.sh
- `update_project_cost()` ~line 510 - handles both umbrella (is_umbrella=true) and regular updates
- `dedicate_session()` ~line 224 - current implementation (needs Phase 2 update)
- `sync_project()` ~line 117 - reads from state files to reconcile
- `init_project()` / `init_umbrella()` - project setup commands
- Delta tracking logic ~line 498-508 - calculates cost_delta from state file

### Current Data Structure (Pre-Phase 2)
```json
// Umbrella session (after dedication - THIS IS WHAT WE'RE FIXING)
"sessions": {
  "a3013a": {
    "contributed": 0,           // <-- misleading, needs to become breakdown
    "dedicated_to": "claude-statusline",
    "transcript": "..."
  }
}

// Sub-project session
"sessions": {
  "a3013a": {
    "contributed": 63.60,
    "dedicated": true,
    "transcript": "..."
  }
}
```

### Timing Mechanism
- `display_cycle=$(( $(date +%S) % 10 ))` - cycles 0-9 based on current second
- Project updates only happen on cycle 0 (~every 10 seconds)
- State file should ONLY update after successful project update (bug we fixed)

### Lock Mechanism
- Uses `mkdir "$lock_dir"` for atomic locking (returns 1 if exists)
- Stale lock cleanup: removes locks older than 60 seconds
- Lock dir: `${config}.lock`

### Child Project Detection (NEEDED FOR PHASE 2)
Currently we detect child by checking if `project_config` has a `parent` field.
For breakdown tracking, we need to detect if cwd is IN a child:
```bash
# Pseudocode for detecting child project
current_project_config = find_project_config(cwd)
session_home_config = ... # where session started
if current_project_config != session_home_config:
    # We're in a child (or different project)
    child_name = jq '.name' current_project_config
    # Update breakdown[child_name] instead of breakdown._self
```

### Roll-up Logic (NEEDED FOR PHASE 2)
After updating a project, also update its parent:
```bash
parent_config=$(jq -r '.parent // empty' "$project_config")
if [[ -n "$parent_config" && -f "$parent_config" ]]; then
    my_total=$(jq -r '.costs.total' "$project_config")
    my_name=$(jq -r '.name' "$project_config")
    # Update parent's projects[my_name].contributed = my_total
fi
```

### Session Start Detection
To get session start time, use transcript file creation time:
```bash
transcript_ctime=$(stat -f %B "$transcript_path" 2>/dev/null)  # macOS
# Convert to ISO date for JSON
```

### Test Data Reference
- Current session: `3f542803-742f-485d-a220-32fd83a3013a` (short: a3013a)
- Session cost: ~$65+ (check state file for current)
- Already dedicated to claude-statusline

### Migration Strategy
1. Read existing `contributed` value
2. If `dedicated_to` exists: put full amount in `breakdown[dedicated_to]`, `_self: 0`
3. If no dedication: put full amount in `breakdown._self`
4. Add `total_cost` from state file or transcript
5. Add `started` from transcript ctime
