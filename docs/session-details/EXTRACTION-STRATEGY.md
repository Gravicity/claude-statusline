# Session Metadata Extraction Strategy

**Date:** December 1, 2025
**Purpose:** Define how to extract meaningful metadata from raw session data

---

## Overview

Session metadata extraction transforms raw JSONL conversation data into structured, searchable fields: topic, keywords, milestones, and overview. This document covers extraction signals, processing approaches, and integration patterns.

---

## Extraction Signals

### Primary Signals (High Value)

| Signal | Source | What It Tells Us |
|--------|--------|------------------|
| First user message | `type: "user"` (first) | Initial intent/goal |
| Recent user messages | `type: "user"` (last N) | Current focus |
| Compaction summaries | `type: "summary"` | AI-generated overview |
| Tool names | `tool_use.name` | Activity type |
| File paths | `tool_use.input.file_path` | Code areas touched |

### Secondary Signals (Supporting)

| Signal | Source | What It Tells Us |
|--------|--------|------------------|
| Git branch | `gitBranch` field | Feature context |
| Working directory | `cwd` field | Project scope |
| Timestamps | `timestamp` field | Session timeline |
| Message count | Entry count | Session length |
| File size | OS stat | Session complexity |

---

## Extraction Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    RAW SESSION (.jsonl)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 1: Fast Filter (grep)                                    │
│  ─────────────────────────────                                  │
│  • Check if session matches search criteria                     │
│  • Extract file metadata (size, mtime)                          │
│  • Count entries by type                                        │
│  • Time: <1 second                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 2: Signal Extraction (jq)                                │
│  ───────────────────────────────                                │
│  • Extract user messages (first + last 20)                      │
│  • Extract summaries (all)                                      │
│  • Extract tool usage counts                                    │
│  • Extract file paths touched                                   │
│  • Time: 2-5 seconds                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  STAGE 3: AI Synthesis (Haiku)                                  │
│  ──────────────────────────────                                 │
│  • Generate topic from signals                                  │
│  • Extract keywords                                             │
│  • Identify milestones                                          │
│  • Write overview                                               │
│  • Time: 5-15 seconds                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  STRUCTURED METADATA                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Stage 1: Fast Filter

Bash script for quick metadata extraction without full parsing:

```bash
#!/bin/bash
# extract-signals-fast.sh <session.jsonl>

file="$1"

# File metadata
mtime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file")
size=$(stat -f "%z" "$file")

# Entry counts (fast grep)
user_count=$(grep -c '"type":"user"' "$file")
assistant_count=$(grep -c '"type":"assistant"' "$file")
summary_count=$(grep -c '"type":"summary"' "$file")
tool_count=$(grep -c '"type":"tool_use"' "$file")

# First user message
first_msg=$(grep -m1 '"type":"user"' "$file" | \
  jq -r '.message.content[0].text // ""' | head -c 200)

# Output as JSON
jq -n \
  --arg mtime "$mtime" \
  --arg size "$size" \
  --arg users "$user_count" \
  --arg summaries "$summary_count" \
  --arg first "$first_msg" \
  '{
    file_metadata: {modified: $mtime, size_bytes: ($size | tonumber)},
    counts: {user_messages: ($users | tonumber), summaries: ($summaries | tonumber)},
    first_message: $first
  }'
```

---

## Stage 2: Signal Extraction

Detailed extraction for synthesis:

```bash
#!/bin/bash
# extract-signals-full.sh <session.jsonl>

file="$1"
output_dir="${2:-.}"

# Extract summaries (highest value, usually at file start)
head -100 "$file" | \
  grep '"type":"summary"' | \
  jq -r '.summary' > "$output_dir/summaries.txt"

# Extract first 5 user messages (initial intent)
grep '"type":"user"' "$file" | head -5 | \
  jq -r '.message.content[0].text' > "$output_dir/first_messages.txt"

# Extract last 20 user messages (recent focus)
grep '"type":"user"' "$file" | tail -20 | \
  jq -r '.message.content[0].text' > "$output_dir/recent_messages.txt"

# Extract tool usage summary
grep -o '"name":"[A-Za-z]*"' "$file" | \
  sed 's/"name":"//g; s/"//g' | \
  grep -v -E '^(user|assistant)$' | \
  sort | uniq -c | sort -rn | head -10 > "$output_dir/tools.txt"

# Extract unique file paths (from Edit tool)
grep '"name":"Edit"' "$file" | \
  jq -r '.input.file_path // empty' 2>/dev/null | \
  sort -u | head -20 > "$output_dir/files.txt"

# Extract git branch
grep -m1 '"gitBranch"' "$file" | \
  jq -r '.gitBranch // ""' > "$output_dir/branch.txt"

# Package as JSON
jq -n \
  --rawfile summaries "$output_dir/summaries.txt" \
  --rawfile first "$output_dir/first_messages.txt" \
  --rawfile recent "$output_dir/recent_messages.txt" \
  --rawfile tools "$output_dir/tools.txt" \
  --rawfile files "$output_dir/files.txt" \
  --rawfile branch "$output_dir/branch.txt" \
  '{
    summaries: ($summaries | split("\n") | map(select(length > 0))),
    first_messages: ($first | split("\n") | map(select(length > 0))),
    recent_messages: ($recent | split("\n") | map(select(length > 0))),
    tools_used: $tools,
    files_touched: ($files | split("\n") | map(select(length > 0))),
    git_branch: ($branch | rtrimstr("\n"))
  }'
```

---

## Stage 3: AI Synthesis

Prompt for Haiku to generate structured metadata:

```markdown
# Session Metadata Extraction

Given these signals from a Claude Code session, extract structured metadata.

## Input Signals

### Compaction Summaries (if available)
{summaries}

### First User Messages (initial intent)
{first_messages}

### Recent User Messages (current focus)
{recent_messages}

### Tools Used
{tools_used}

### Files Touched
{files_touched}

## Required Output

Generate JSON with these fields:

1. **topic** (max 50 chars): The primary subject/goal of this session.
   - Should be a noun phrase describing what's being built/done
   - Example: "Statusline Token Tracking Implementation"

2. **keywords** (5-7 items): Searchable terms for finding this session.
   - Include technologies, concepts, and action words
   - Example: ["statusline", "tokens", "bash", "terminal", "cost-tracking"]

3. **milestones** (3-5 items): Key events with type and description.
   - Types: decision, feature, discovery, fix, refactor, blocker
   - Example: {"type": "feature", "text": "Added color-coded model display"}

4. **overview** (max 20 words): Brief human-readable summary.
   - Should answer "What was accomplished in this session?"
   - Example: "Built terminal statusline with token counting and cost tracking"

## Output Format

```json
{
  "topic": "...",
  "keywords": [...],
  "milestones": [...],
  "overview": "..."
}
```
```

---

## Milestone Detection Heuristics

### Decision Detection

Look for patterns in user messages:
- "let's use", "we should", "I've decided"
- "going with", "choosing", "prefer"
- Architecture discussions, technology choices

### Feature Detection

Look for Edit tool usage patterns:
- New file creation (file didn't exist before)
- Significant code additions
- Test file creation
- Config changes

### Discovery Detection

Look for patterns:
- "found that", "discovered", "turns out"
- "interesting", "didn't know"
- Investigation results, debugging findings

### Fix Detection

Look for patterns:
- "fixed", "resolved", "bug", "issue"
- Error message discussions followed by Edit
- Test passing after failing

---

## Context-Aware Extraction

### At 50% Context (~100k tokens)

```python
def extract_at_50_percent(session_file):
    """Light extraction - establish topic and initial keywords."""

    signals = {
        'first_messages': get_first_n_user_messages(session_file, 5),
        'recent_messages': get_last_n_user_messages(session_file, 10),
        'tools': get_tool_summary(session_file),
    }

    # Use Haiku for quick synthesis
    return synthesize_metadata(signals, depth='light')
```

### At 80% Context (~160k tokens)

```python
def extract_at_80_percent(session_file, existing_metadata):
    """Medium extraction - add milestones, refine topic."""

    signals = {
        'first_messages': get_first_n_user_messages(session_file, 5),
        'recent_messages': get_last_n_user_messages(session_file, 20),
        'tools': get_tool_summary(session_file),
        'files': get_files_touched(session_file),
        'existing': existing_metadata,
    }

    # Compare new signals with existing topic
    if topic_has_shifted(signals, existing_metadata):
        return synthesize_metadata(signals, depth='full', archive_old=True)
    else:
        return merge_metadata(existing_metadata, signals)
```

### Post-Compact

```python
def extract_post_compact(session_file, existing_metadata):
    """Full extraction - use Claude's summary as primary input."""

    summaries = get_summaries(session_file)

    if summaries:
        # Claude's summary is high-quality input
        signals = {
            'summaries': summaries,
            'recent_messages': get_last_n_user_messages(session_file, 10),
            'existing': existing_metadata,
        }
        return synthesize_metadata(signals, depth='full', use_summaries=True)
    else:
        # No summaries, extract from messages
        return extract_at_80_percent(session_file, existing_metadata)
```

---

## Topic Shift Detection

```python
def topic_has_shifted(new_signals, existing_metadata):
    """Determine if the session topic has significantly changed."""

    old_topic = existing_metadata.get('topic', '')
    old_keywords = set(existing_metadata.get('keywords', []))

    # Extract candidate keywords from recent messages
    new_keywords = extract_keywords_from_messages(new_signals['recent_messages'])

    # Calculate overlap
    overlap = len(old_keywords & new_keywords) / max(len(old_keywords), 1)

    # Check for explicit topic change signals
    recent_text = ' '.join(new_signals['recent_messages'])
    shift_phrases = [
        "now let's", "switch to", "moving on to",
        "different topic", "next task", "new feature"
    ]
    explicit_shift = any(phrase in recent_text.lower() for phrase in shift_phrases)

    if explicit_shift:
        return True
    elif overlap < 0.3:
        return True  # Less than 30% keyword overlap
    elif overlap < 0.5:
        return "maybe"  # Borderline - could ask user
    else:
        return False
```

---

## Integration with Session Finder

The session finder skill (`find-sessions.sh`) provides the foundation:

```bash
# Get raw signals for a session
find-sessions.sh --file abc-123-def --json > /tmp/session_signals.json

# Pipe to synthesis script
cat /tmp/session_signals.json | synthesize-metadata.py > /tmp/metadata.json

# Store result
cp /tmp/metadata.json ~/.claude/statusline/sessions/abc-123-def.json
```

---

## Performance Targets

| Stage | Target Time | Memory |
|-------|-------------|--------|
| Fast filter | <1s | <10MB |
| Signal extraction | <5s | <50MB |
| AI synthesis | <15s | N/A (API) |
| Total | <20s | <50MB |

For batch processing (multiple sessions):
- Process in parallel where possible
- Cache extracted signals
- Skip recently processed sessions
