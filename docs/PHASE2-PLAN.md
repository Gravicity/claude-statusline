# Phase 2: Session Attribution Model

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
