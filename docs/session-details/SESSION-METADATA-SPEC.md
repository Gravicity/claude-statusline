# Session Metadata Specification

**Version:** 1.0.0
**Date:** December 1, 2025
**Status:** Draft for Statusline Integration

---

## Overview

This specification defines the metadata structure for enriching Claude Code sessions with meaningful, searchable information. The goal is to transform anonymous session UUIDs into recognizable entries with topics, keywords, and milestones.

---

## Data Structure

```json
{
  "session_id": "3f542803-742f-485d-a220-32fd83a3013a",
  "project_path": "/Users/user/Gravicity Projects",

  "topic": "Statusline Token Tracking Implementation",

  "keywords": ["statusline", "tokens", "cost", "bash", "terminal"],

  "milestones": [
    {"type": "decision", "text": "Use bash for cross-platform portability", "at": "2025-11-28T10:00:00Z"},
    {"type": "feature", "text": "Token counter with model-specific colors", "at": "2025-11-28T14:30:00Z"},
    {"type": "discovery", "text": "Claude Code /rename command exists but disabled", "at": "2025-11-29T09:00:00Z"},
    {"type": "feature", "text": "Cost-per-session tracking from API responses", "at": "2025-11-29T16:00:00Z"}
  ],

  "overview": "Built terminal statusline showing tokens, cost, and model with dynamic coloring",

  "context_stage": "80%",
  "updated_at": "2025-11-30T14:30:00Z",
  "created_at": "2025-11-28T09:00:00Z",

  "evolution": {
    "topic_stable": true,
    "shift_count": 0,
    "history": []
  },

  "stats": {
    "user_message_count": 127,
    "tools_used": {"Edit": 45, "Bash": 32, "Read": 28},
    "files_touched": 12,
    "estimated_tokens": 165000
  }
}
```

---

## Field Definitions

### Core Identification

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Claude Code session UUID |
| `project_path` | string | Decoded project directory path |

### Semantic Fields

| Field | Type | Max | Description |
|-------|------|-----|-------------|
| `topic` | string | 50 chars | Primary subject/goal of the session |
| `keywords` | string[] | 5-10 items | Searchable terms for discovery |
| `milestones` | object[] | 5-8 items | Key events during the session |
| `overview` | string | 20 words | Quick human-readable summary |

### Tracking Fields

| Field | Type | Description |
|-------|------|-------------|
| `context_stage` | enum | When last updated: `"50%"`, `"80%"`, `"post-compact"` |
| `updated_at` | ISO8601 | Last metadata update timestamp |
| `created_at` | ISO8601 | Session creation timestamp |

### Evolution Tracking

| Field | Type | Description |
|-------|------|-------------|
| `evolution.topic_stable` | boolean | Has topic remained consistent? |
| `evolution.shift_count` | number | How many major topic shifts |
| `evolution.history` | object[] | Previous topics if shifted |

### Statistics

| Field | Type | Description |
|-------|------|-------------|
| `stats.user_message_count` | number | Total user messages |
| `stats.tools_used` | object | Tool usage counts |
| `stats.files_touched` | number | Unique files modified |
| `stats.estimated_tokens` | number | Approximate token usage |

---

## Milestone Types

```
decision   → Architectural or strategic choice made
             "Chose PostgreSQL over MongoDB for ACID compliance"

feature    → Something implemented or created
             "Added user authentication with JWT"

discovery  → Insight, finding, or learning
             "Found that API rate limits to 100 req/min"

fix        → Bug or issue resolved
             "Fixed race condition in websocket handler"

refactor   → Code restructure without new features
             "Extracted auth logic into separate service"

blocker    → Unresolved issue or dependency
             "Waiting for API key from third-party provider"
```

---

## Context Stages

Sessions progress through context stages as tokens accumulate:

```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│   START     │    50%      │    80%      │  COMPACT    │
│   0-100k    │  ~100k      │  ~160k      │   ~200k     │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ Initial     │ Mid-session │ Near limit  │ Compaction  │
│ extraction  │ refinement  │ full update │ final state │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

### Update Behavior by Stage

| Stage | Extraction Depth | Update Action |
|-------|------------------|---------------|
| `50%` | Light | Extract topic + keywords from recent messages |
| `80%` | Medium | Full milestone extraction, refine overview |
| `post-compact` | Full | Use Claude's summary, finalize metadata |

---

## Evolution Logic

### Topic Stability Detection

```python
def should_archive_topic(old_topic, new_signals):
    """Determine if topic has shifted significantly."""

    similarity = compute_similarity(old_topic, new_signals)

    if similarity < 0.5:
        return True   # Major shift - archive old topic
    elif similarity < 0.7:
        return "maybe"  # Moderate shift - ask user or use heuristics
    else:
        return False  # Same topic - accumulate
```

### When Topic Shifts

```json
{
  "topic": "New Topic After Shift",
  "keywords": ["new", "keywords"],
  "milestones": [],
  "evolution": {
    "topic_stable": false,
    "shift_count": 1,
    "history": [
      {
        "topic": "Original Topic",
        "keywords": ["old", "keywords"],
        "milestones": [...],
        "overview": "What was done before shift",
        "archived_at": "2025-11-30T12:00:00Z"
      }
    ]
  }
}
```

### Accumulation vs Replacement

| Scenario | Keywords | Milestones | Overview |
|----------|----------|------------|----------|
| Same topic | Union (dedupe) | Append (max 8) | Regenerate |
| Topic shift | Replace | Reset | Regenerate |
| Post-compact | Replace with refined | Keep important | Use summary |

---

## Storage Options

### Option A: Statusline Project Logs

Store in existing statusline infrastructure:

```
~/.claude/statusline/projects/{encoded-path}/sessions/{session-id}.json
```

**Pros:** Integrated with statusline, single source of truth
**Cons:** Coupled to statusline implementation

### Option B: Dedicated Metadata Store

Separate session metadata system:

```
~/.claude/session-metadata/{session-id}.json
```

**Pros:** Independent, reusable by other tools
**Cons:** Another location to manage

### Option C: Append to Session JSONL

Add metadata entries to the session file itself:

```json
{"type": "session-metadata", "topic": "...", "keywords": [...], ...}
```

**Pros:** Self-contained, travels with session
**Cons:** Modifies Claude Code's files (risky)

**Recommendation:** Option A for now, with export capability to Option B.

---

## Integration Points

### With Session Finder Skill

The `find-sessions.sh` script can:
1. Read existing metadata to enhance search results
2. Generate metadata for sessions that don't have it
3. Use `--file --json` mode to extract raw signals

### With Statusline Display

The statusline can show:
- Current session topic in the status bar
- Keyword indicators for quick context
- Milestone count or recent milestone

### With Resume Picker

A custom resume picker could:
- Display topic instead of first message
- Filter by keywords
- Show milestone summary on hover

---

## Example: Full Session Lifecycle

```
1. SESSION START
   → No metadata yet
   → First extraction after ~50k tokens

2. AT 50% CONTEXT
   → Extract: topic="Auth System Implementation"
   → Extract: keywords=["auth", "firebase", "jwt"]
   → Status: context_stage="50%"

3. AT 80% CONTEXT
   → Topic unchanged, accumulate
   → Add milestone: {"type": "feature", "text": "Login flow complete"}
   → Add keywords: ["oauth", "refresh-tokens"]
   → Status: context_stage="80%"

4. TOPIC SHIFT DETECTED
   → User: "Now let's work on the statusline"
   → Archive old topic to history
   → Reset: topic="Statusline Implementation"
   → Reset: keywords=["statusline", "terminal"]

5. PRE-COMPACT
   → Full extraction with all signals
   → Finalize milestones
   → Generate comprehensive overview

6. POST-COMPACT
   → Use Claude's compaction summary
   → Refine topic from summary
   → Status: context_stage="post-compact"
```

---

## Validation Rules

```yaml
topic:
  required: true
  max_length: 50
  pattern: "^[A-Z].*"  # Start with capital

keywords:
  required: true
  min_items: 3
  max_items: 10
  item_max_length: 30

milestones:
  max_items: 8
  required_fields: [type, text]
  valid_types: [decision, feature, discovery, fix, refactor, blocker]

overview:
  required: true
  max_words: 20
```

---

## Next Steps

1. Implement extraction script for single-session analysis
2. Define hook triggers for context barriers
3. Build metadata storage layer
4. Integrate with statusline display
5. Create custom resume picker using metadata
