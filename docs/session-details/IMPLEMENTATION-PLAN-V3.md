# Session Intelligence Implementation Plan (v3)

**Date:** December 1, 2025
**Status:** Approved for Implementation
**Author:** Field Commander Research Session

---

## Overview

This plan defines the implementation of Session Intelligence - a system for enriching Claude Code session logs with meaningful metadata (topics, keywords, milestones, stats) that evolves throughout a session's lifecycle.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SESSION INTELLIGENCE SYSTEM                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  TRIGGERS (Multiple Sources)                                        │
│  ├─ Statusline Script (context barriers)                            │
│  │   ├─ 50% context → trigger light extraction                      │
│  │   └─ 80% context → trigger full extraction                       │
│  ├─ PreCompact Hook → trigger final extraction + use Claude summary │
│  ├─ Stop Hook → finalize metadata                                   │
│  └─ /clear Hook → archive current state                             │
│                                                                     │
│  EXECUTION (Non-Blocking)                                           │
│  ├─ Hook/trigger spawns autonomous agent (fire-and-forget)          │
│  ├─ Agent runs outside session context                              │
│  └─ Returns immediately (no session blocking)                       │
│                                                                     │
│  AUTONOMOUS EXTRACTION AGENT                                        │
│  ├─ Stage 1: Fast signal extraction (bash/jq)                       │
│  ├─ Stage 2: Topic drift detection (compare with previous)          │
│  ├─ Stage 3: AI synthesis (Haiku - optional, configurable)          │
│  ├─ Stage 4: Write to project.json with atomic locking              │
│  └─ Reuses session-finder parsing functions                         │
│                                                                     │
│  STORAGE (Inline in project.json)                                   │
│  ├─ sessions[id].metadata.current → latest topic/keywords           │
│  ├─ sessions[id].metadata.extractions[] → history                   │
│  ├─ sessions[id].metadata.segments[] → topic chapters               │
│  └─ sessions[id].metadata.stats → message counts, tools used        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Trigger Timeline

```
0%        25%        50%        75%        100%
│          │          │          │          │
▼          ▼          ▼          ▼          ▼
START     ───────►  EXTRACT   EXTRACT    COMPACT
(init)              (light)   (full)     (final)

Additional triggers:
├─ Stop Hook → finalize on session end
├─ /clear Hook → archive before clear
└─ On-demand → manual skill invocation
```

---

## Session Metadata Schema

```json
{
  "sessions": {
    "3f542803-742f-485d-a220-32fd83a3013a": {
      "started": "2025-11-29T08:51:08Z",
      "transcript": "/path/to/transcript.jsonl",
      "breakdown": { "_self": 70.96 },
      "total_cost": 70.96,
      "updated": "2025-12-01T15:45:20Z",

      "metadata": {
        "current": {
          "topic": "Statusline File Locking",
          "keywords": ["locking", "statusline", "concurrent", "retry"],
          "overview": "Implementing atomic file locking with 1s stale cleanup"
        },

        "extractions": [
          {
            "stage": "50%",
            "at": "2025-12-01T10:00:00Z",
            "topic": "Auth System Setup",
            "keywords": ["auth", "firebase", "jwt"],
            "overview": "Setting up Firebase authentication",
            "stats": { "user_messages": 45, "assistant_messages": 43 }
          },
          {
            "stage": "80%",
            "at": "2025-12-01T14:00:00Z",
            "topic": "Statusline Development",
            "keywords": ["statusline", "terminal", "bash"],
            "overview": "Building statusline with cost tracking",
            "stats": { "user_messages": 127, "assistant_messages": 125 }
          }
        ],

        "segments": [
          {
            "topic": "Auth System",
            "keywords": ["auth", "firebase"],
            "from_stage": "50%",
            "to_stage": "70%",
            "weight": 0.3
          },
          {
            "topic": "Statusline",
            "keywords": ["statusline", "locking"],
            "from_stage": "70%",
            "to_stage": "current",
            "weight": 0.7
          }
        ],

        "stats": {
          "user_messages": 186,
          "assistant_messages": 182,
          "tools_used": {
            "Edit": 89,
            "Bash": 67,
            "Read": 156,
            "Grep": 45,
            "Write": 12,
            "Task": 8
          },
          "files_touched": 23,
          "subagent_count": 8
        },

        "drift_count": 1,
        "last_extracted": "2025-12-01T14:00:00Z",
        "extraction_count": 2
      }
    }
  }
}
```

---

## Field Definitions

### Current (What matters NOW)

| Field | Type | Max | Description |
|-------|------|-----|-------------|
| `topic` | string | 60 chars | Primary subject/goal |
| `keywords` | string[] | 10 items | Searchable terms |
| `overview` | string | 25 words | Quick human summary |

### Extractions (History)

| Field | Type | Description |
|-------|------|-------------|
| `stage` | enum | "50%", "80%", "post-compact", "stop", "clear" |
| `at` | ISO8601 | When extracted |
| `topic` | string | Topic at this stage |
| `keywords` | string[] | Keywords at this stage |
| `overview` | string | Overview at this stage |
| `stats` | object | Message counts at extraction |

### Segments (Topic Chapters)

| Field | Type | Description |
|-------|------|-------------|
| `topic` | string | Segment topic |
| `keywords` | string[] | Segment keywords |
| `from_stage` | string | When segment started |
| `to_stage` | string | When segment ended or "current" |
| `weight` | number | 0-1, relevance for search ranking |

### Stats (Aggregate Metrics)

| Field | Type | Description |
|-------|------|-------------|
| `user_messages` | number | Total user message count |
| `assistant_messages` | number | Total assistant message count |
| `tools_used` | object | Tool usage counts by name |
| `files_touched` | number | Unique files modified |
| `subagent_count` | number | Task tool invocations |

### Meta Fields

| Field | Type | Description |
|-------|------|-------------|
| `drift_count` | number | Major topic shifts detected |
| `last_extracted` | ISO8601 | Last extraction timestamp |
| `extraction_count` | number | Total extractions performed |

---

## Topic Drift Detection

### Algorithm

```python
def detect_drift(prev_extraction, new_signals):
    """
    Compare keyword overlap to detect topic drift.

    Returns:
      - "archive_and_reset": Major drift (< 30% overlap)
      - "evolve": Moderate drift (30-60% overlap)
      - "accumulate": Same topic (> 60% overlap)
    """
    if not prev_extraction:
        return "accumulate"  # First extraction

    old_kw = set(prev_extraction['keywords'])
    new_kw = set(new_signals['keywords'])

    if not old_kw:
        return "accumulate"

    overlap = len(old_kw & new_kw) / len(old_kw)

    # Also check for explicit drift signals
    recent_text = ' '.join(new_signals.get('recent_messages', []))
    drift_phrases = [
        "now let's", "switch to", "moving on",
        "different topic", "new feature", "actually let's"
    ]
    explicit_drift = any(p in recent_text.lower() for p in drift_phrases)

    if explicit_drift or overlap < 0.3:
        return "archive_and_reset"
    elif overlap < 0.6:
        return "evolve"
    else:
        return "accumulate"
```

### Behavior by Drift Type

| Drift Type | Keywords | Topic | Segments |
|------------|----------|-------|----------|
| `accumulate` | Union (dedupe) | Keep current | No change |
| `evolve` | Merge with weight | Refine | Update weights |
| `archive_and_reset` | Replace | Replace | Archive old as segment |

---

## Implementation Phases

### Phase 1: Multi-Trigger Infrastructure

**1a. Statusline context barrier triggers**
```bash
# In statusline-command.sh, after context_pct calculation
trigger_dir="$HOME/.cache/claude-statusline/triggers"

if [[ $context_pct -ge 50 ]] && [[ ! -f "$trigger_dir/extracted-50-$session_id" ]]; then
    echo '{"stage":"50%","session_id":"'$session_id'","transcript":"'$transcript_path'","cwd":"'$cwd'"}' \
        > "$trigger_dir/pending-$session_id-50"
    touch "$trigger_dir/extracted-50-$session_id"
fi

if [[ $context_pct -ge 80 ]] && [[ ! -f "$trigger_dir/extracted-80-$session_id" ]]; then
    echo '{"stage":"80%","session_id":"'$session_id'","transcript":"'$transcript_path'","cwd":"'$cwd'"}' \
        > "$trigger_dir/pending-$session_id-80"
    touch "$trigger_dir/extracted-80-$session_id"
fi
```

**1b. Hook configuration**
```json
{
  "hooks": {
    "PreCompact": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-enricher.sh",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-enricher.sh",
        "timeout": 5
      }]
    }]
  }
}
```

**1c. Field preservation in statusline**
- Update `update_project_cost` to preserve `metadata` object
- Use null-coalescing: `.metadata = (.metadata // {})`

---

### Phase 2: Non-Blocking Extraction Agent

**2a. Hook script (fire-and-forget)**
```bash
#!/bin/bash
# ~/.claude/hooks/session-enricher.sh
# Spawns agent and returns immediately

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
transcript=$(echo "$input" | jq -r '.transcript_path')
stage=$(echo "$input" | jq -r '.hook_event_name // "hook"')

# Fire and forget - agent runs in background
nohup ~/.claude/agents/session-extraction-agent.sh \
    "$session_id" "$transcript" "$stage" \
    > /tmp/session-extract-$session_id.log 2>&1 &

exit 0  # Return immediately
```

**2b. Extraction agent**
- Reuse session-finder functions
- Extract signals (summaries, messages, tools)
- Calculate stats (message counts, tool usage)
- Detect drift from previous extraction
- Write to project.json with atomic locking

**2c. Trigger processor**
- Watch for pending trigger files
- Process and clean up
- Runs as part of statusline or separate daemon

---

### Phase 3: Evolution Tracking

**3a. Drift detection**
- Implement overlap algorithm
- Track drift_count
- Archive old topics to segments

**3b. Segment management**
- Weight calculation based on recency and duration
- Prune old segments (keep max 5)
- Search across all segments

**3c. Stats aggregation**
- Message counts from grep
- Tool usage from session-finder
- Files touched from Edit tool inputs

---

### Phase 4: AI Synthesis (Optional)

**4a. Haiku integration**
- Configurable in statusline-config.json: `"ai_synthesis": true`
- Use extraction prompt from EXTRACTION-STRATEGY.md
- Generate higher quality topic/overview/milestones

**4b. Cost tracking**
- Track extraction API costs separately
- ~$0.01-0.05 per extraction
- Respect rate limits

---

## Custom Resume Command (Future)

### Concept: `statusline --resume` or `/smart-resume`

```bash
# List sessions with metadata
statusline --resume

┌─────────────────────────────────────────────────────────────────────┐
│  SESSIONS (Last 7 days)                                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  TODAY                                                              │
│  ├─ 📊 Statusline Locking [186 msgs, $70.96]     ※3f5428 ──────────│
│  │      locking, concurrent, retry                                  │
│  │      Implementing atomic file locking with 1s stale cleanup      │
│  │                                                                  │
│  ├─ 🔐 VeriVox Auth System [89 msgs, $23.50]     ※a10c4a ──────────│
│  │      auth, firebase, transcription                               │
│  │      Setting up authentication for VeriVox rebuild               │
│  │                                                                  │
│  YESTERDAY                                                          │
│  ├─ 🎬 Orbit Video Export [234 msgs, $45.00]     ※701cb1 ──────────│
│  │      video, export, ffmpeg                                       │
│  │      Implementing video export with FFmpeg integration           │
│  │                                                                  │
│                                                                     │
│  [↑/↓] Navigate  [Enter] Resume  [/] Search  [p] Filter by project  │
└─────────────────────────────────────────────────────────────────────┘
```

### Features

- **Categorized by project** - Group sessions by umbrella/project
- **Metadata display** - Topic, keywords, overview, stats
- **Search** - Filter by keyword across all metadata
- **Cost visibility** - Show session cost and message count
- **Quick resume** - Select and launch `claude --resume <id>`

### Implementation

```bash
# CLI command
statusline --resume [--project NAME] [--days N] [--search KEYWORD]

# Interactive mode
statusline --resume --interactive
```

---

## File Structure

```
~/.claude/
├── hooks/
│   └── session-enricher.sh          # Hook entry point (fire-and-forget)
├── agents/
│   └── session-extraction-agent.sh  # Autonomous extraction agent
├── lib/
│   └── session-parser.sh            # Shared parsing functions
├── skills/
│   └── session-finder/              # Existing search skill
└── settings.json                    # Hook configuration

~/.cache/claude-statusline/
├── triggers/
│   ├── pending-{session}-50         # Pending 50% extraction
│   ├── pending-{session}-80         # Pending 80% extraction
│   ├── extracted-50-{session}       # Marker: 50% done
│   └── extracted-80-{session}       # Marker: 80% done
└── session-{id}.state               # Existing cost state

claude-statusline/
├── statusline-command.sh            # Add trigger logic + field preservation
├── install.sh                       # Install hooks and agents
└── docs/session-details/            # This documentation
```

---

## Configuration

Add to `~/.claude/statusline-config.json`:

```json
{
  "metadata": {
    "enabled": true,
    "triggers": {
      "context_50": true,
      "context_80": true,
      "pre_compact": true,
      "stop": true,
      "clear": true
    },
    "ai_synthesis": false,
    "max_segments": 5,
    "max_extractions": 10
  }
}
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Extraction latency | < 5s (no AI), < 20s (with AI) |
| Session blocking | 0 (fire-and-forget) |
| Storage overhead | < 5KB per session |
| Drift detection accuracy | > 80% |
| Search improvement | Find sessions 3x faster |

---

## Next Steps

1. [ ] Phase 1a: Add context barrier triggers to statusline script
2. [ ] Phase 1b: Configure PreCompact + Stop hooks
3. [ ] Phase 1c: Add metadata field preservation
4. [ ] Phase 2a: Create hook entry point script
5. [ ] Phase 2b: Implement extraction agent
6. [ ] Phase 3: Add drift detection and evolution tracking
7. [ ] Phase 4: Optional AI synthesis integration
8. [ ] Future: Custom resume command with interactive picker

---

## Related Documentation

- [SESSION-METADATA-SPEC.md](./SESSION-METADATA-SPEC.md) - Original field definitions
- [SESSION-STORAGE-ARCHITECTURE.md](./SESSION-STORAGE-ARCHITECTURE.md) - Claude Code internals
- [EXTRACTION-STRATEGY.md](./EXTRACTION-STRATEGY.md) - Extraction pipeline details
- [HOOK-INTEGRATION.md](./HOOK-INTEGRATION.md) - Hook configuration patterns
- [SESSION-FINDER-SKILL.md](./SESSION-FINDER-SKILL.md) - Existing skill reference
