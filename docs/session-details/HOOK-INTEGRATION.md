# Hook Integration for Session Metadata

**Date:** December 1, 2025
**Purpose:** Define triggers for automatic session metadata updates

---

## Overview

Claude Code hooks provide event-driven triggers that can invoke scripts at key moments. This document covers how to use hooks to automatically extract and update session metadata at context barriers.

---

## Available Hook Types

| Hook | Trigger | Use Case |
|------|---------|----------|
| `PreToolUse` | Before any tool executes | Log activity |
| `PostToolUse` | After tool completes | Track changes |
| `Notification` | When Claude sends notification | Detect events |
| `Stop` | Session ends or pauses | Final extraction |
| **`PreCompact`** | Before compaction | **Primary trigger** |

---

## Hook Configuration

Hooks are configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreCompact": [
      {
        "type": "command",
        "command": "~/.claude/hooks/extract-session-metadata.sh"
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "~/.claude/hooks/finalize-session-metadata.sh"
      }
    ]
  }
}
```

---

## Hook Input Format

Hooks receive JSON input via stdin:

```json
{
  "session_id": "3f542803-742f-485d-a220-32fd83a3013a",
  "transcript_path": "/Users/user/.claude/projects/-Users-user-Gravicity-Projects/3f542803-742f-485d-a220-32fd83a3013a.jsonl",
  "cwd": "/Users/user/Gravicity Projects",
  "hook_type": "PreCompact"
}
```

---

## Trigger Strategy

### Option A: PreCompact Only (Recommended Start)

Simplest approach - extract metadata before compaction:

```
Session Start → ... → PreCompact → Metadata Extracted → Compaction → Continue
```

**Pros:**
- Single trigger point
- Session has rich history
- Claude's about to summarize anyway

**Cons:**
- Only triggers if session reaches compaction
- Short sessions never get metadata

### Option B: Multi-Trigger (Advanced)

Multiple extraction points for comprehensive tracking:

```
Session Start
    │
    ▼
[50% Context] ──→ Light extraction (hook or polling)
    │
    ▼
[80% Context] ──→ Full extraction (hook or polling)
    │
    ▼
[PreCompact] ──→ Final extraction with full history
    │
    ▼
[PostCompact] ──→ Incorporate Claude's summary
    │
    ▼
[Stop] ──→ Finalize metadata
```

### Option C: Periodic + Events (Most Complete)

Combine periodic polling with event hooks:

```python
# Pseudo-code for metadata updater daemon

while session_active:
    token_count = get_current_token_count()

    if token_count > 100000 and not extracted_at_50:
        extract_metadata(depth='light')
        extracted_at_50 = True

    if token_count > 160000 and not extracted_at_80:
        extract_metadata(depth='full')
        extracted_at_80 = True

    sleep(60)  # Check every minute

# Hook handlers
on_precompact:
    extract_metadata(depth='full')

on_stop:
    finalize_metadata()
```

---

## Context Barrier Detection

### Challenge: No Direct Token Count Access

Claude Code doesn't expose current token count to hooks. Workarounds:

#### Approach 1: Estimate from File Size

```bash
#!/bin/bash
# estimate-context.sh

session_file="$1"
file_size=$(stat -f "%z" "$session_file")

# Rough estimate: ~4 chars per token, ~2x for JSONL overhead
estimated_tokens=$((file_size / 8))

if [[ $estimated_tokens -gt 160000 ]]; then
    echo "80%"
elif [[ $estimated_tokens -gt 100000 ]]; then
    echo "50%"
else
    echo "under50%"
fi
```

#### Approach 2: Message Count Heuristic

```bash
#!/bin/bash
# estimate-from-messages.sh

session_file="$1"
user_messages=$(grep -c '"type":"user"' "$session_file")
assistant_messages=$(grep -c '"type":"assistant"' "$session_file")

# Rough estimate: ~500 tokens per exchange on average
estimated_tokens=$(( (user_messages + assistant_messages) * 500 ))

echo "$estimated_tokens"
```

#### Approach 3: PostToolUse Tracking

Track tool usage to estimate session complexity:

```bash
#!/bin/bash
# post-tool-use-hook.sh
# Triggered after each tool use

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
session_id=$(echo "$input" | jq -r '.session_id')

# Increment counter
count_file="/tmp/session-tool-count-$session_id"
current=$(cat "$count_file" 2>/dev/null || echo "0")
echo $((current + 1)) > "$count_file"

# Check if threshold reached
if [[ $((current + 1)) -ge 100 ]]; then
    # Trigger extraction
    ~/.claude/hooks/extract-session-metadata.sh "$session_id"
fi
```

---

## PreCompact Hook Implementation

```bash
#!/bin/bash
# ~/.claude/hooks/extract-session-metadata.sh

set -euo pipefail

# Read hook input
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')
transcript_path=$(echo "$input" | jq -r '.transcript_path')
cwd=$(echo "$input" | jq -r '.cwd')

# Paths
METADATA_DIR="$HOME/.claude/statusline/sessions"
SKILL_DIR="$HOME/Gravicity Projects/.claude/skills/session-finder"
OUTPUT_FILE="$METADATA_DIR/${session_id}.json"

# Ensure directory exists
mkdir -p "$METADATA_DIR"

# Check if we already have recent metadata
if [[ -f "$OUTPUT_FILE" ]]; then
    last_update=$(jq -r '.updated_at' "$OUTPUT_FILE")
    # Skip if updated within last hour
    # (implementation depends on date comparison)
fi

# Extract signals using session-finder skill
signals=$("$SKILL_DIR/scripts/find-sessions.sh" --file "$session_id" --json 2>/dev/null)

# Get existing metadata if any
existing="{}"
[[ -f "$OUTPUT_FILE" ]] && existing=$(cat "$OUTPUT_FILE")

# Synthesize metadata (could call Haiku here, or use simpler extraction)
# For now, create basic metadata from signals

topic=$(echo "$signals" | jq -r '
  if .summaries[0] then .summaries[0]
  elif .first_message then .first_message | .[0:50]
  else "Untitled Session"
  end
')

keywords=$(echo "$signals" | jq -r '
  [.tools_used | split("\n") | .[0:3] | .[] | split("(")[0]] |
  unique | join(", ")
')

# Build metadata
jq -n \
  --arg session_id "$session_id" \
  --arg project "$cwd" \
  --arg topic "$topic" \
  --arg keywords "$keywords" \
  --arg updated "$(date -Iseconds)" \
  --arg stage "pre-compact" \
  --argjson signals "$signals" \
  '{
    session_id: $session_id,
    project_path: $project,
    topic: $topic,
    keywords: ($keywords | split(", ")),
    milestones: [],
    overview: ($signals.first_message // "Session in progress"),
    context_stage: $stage,
    updated_at: $updated,
    raw_signals: $signals
  }' > "$OUTPUT_FILE"

echo "Metadata extracted for session $session_id" >&2
exit 0
```

---

## Stop Hook Implementation

```bash
#!/bin/bash
# ~/.claude/hooks/finalize-session-metadata.sh

set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id')

METADATA_DIR="$HOME/.claude/statusline/sessions"
OUTPUT_FILE="$METADATA_DIR/${session_id}.json"

if [[ -f "$OUTPUT_FILE" ]]; then
    # Update context stage to "complete"
    jq '.context_stage = "complete" | .updated_at = now | todate' \
      "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp"
    mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
fi

exit 0
```

---

## Integration with Statusline

The statusline can read session metadata:

```bash
#!/bin/bash
# In statusline-command.sh

session_id="$CLAUDE_SESSION_ID"
metadata_file="$HOME/.claude/statusline/sessions/${session_id}.json"

if [[ -f "$metadata_file" ]]; then
    topic=$(jq -r '.topic // "Untitled"' "$metadata_file")
    echo "📋 $topic"
else
    echo "📋 Session $session_id"
fi
```

---

## Metadata Evolution via Hooks

### Flow for Topic Stability

```
PreCompact #1: Extract initial metadata
    topic: "Auth Implementation"
    keywords: ["auth", "firebase", "jwt"]

PreCompact #2: Session continued, topic stable
    topic: "Auth Implementation" (unchanged)
    keywords: ["auth", "firebase", "jwt", "oauth"] (accumulated)
    milestones: +1 new

PreCompact #3: Topic shift detected
    topic: "Statusline Implementation" (replaced)
    keywords: ["statusline", "terminal"] (replaced)
    evolution.history: [previous topic archived]
```

### Shift Detection in Hook

```bash
#!/bin/bash
# detect-topic-shift.sh

existing_metadata="$1"
new_signals="$2"

old_topic=$(echo "$existing_metadata" | jq -r '.topic')
old_keywords=$(echo "$existing_metadata" | jq -r '.keywords | join(" ")')

# Extract keywords from new signals
new_keywords=$(echo "$new_signals" | jq -r '
  .recent_messages | join(" ") |
  gsub("[^a-zA-Z ]"; "") |
  split(" ") |
  map(select(length > 4)) |
  unique |
  .[0:10] |
  join(" ")
')

# Simple overlap check
overlap=$(echo "$old_keywords $new_keywords" | tr ' ' '\n' | sort | uniq -d | wc -l)
total=$(echo "$old_keywords" | wc -w)

if [[ $overlap -lt $((total / 3)) ]]; then
    echo "shifted"
else
    echo "stable"
fi
```

---

## Hook Testing

```bash
# Test PreCompact hook manually
echo '{
  "session_id": "test-session-123",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/Users/user/project",
  "hook_type": "PreCompact"
}' | ~/.claude/hooks/extract-session-metadata.sh

# Check output
cat ~/.claude/statusline/sessions/test-session-123.json
```

---

## Configuration Checklist

1. [ ] Create hooks directory: `mkdir -p ~/.claude/hooks`
2. [ ] Write extraction script: `extract-session-metadata.sh`
3. [ ] Make executable: `chmod +x ~/.claude/hooks/*.sh`
4. [ ] Configure in settings.json
5. [ ] Create metadata storage: `mkdir -p ~/.claude/statusline/sessions`
6. [ ] Test with manual trigger
7. [ ] Verify statusline integration

---

## Future Enhancements

- [ ] AI-powered synthesis via Haiku API call in hook
- [ ] Token count estimation improvements
- [ ] Multiple trigger points (50%, 80%, PreCompact)
- [ ] Cross-session context continuity
- [ ] Metadata search indexing
