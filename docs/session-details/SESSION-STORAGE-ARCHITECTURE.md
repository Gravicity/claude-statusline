# Claude Code Session Storage Architecture

**Date:** December 1, 2025
**Source:** Investigation of Claude Code internals + GitHub issues research

---

## Overview

This document details how Claude Code stores session data, based on analysis of the JSONL file format, directory structure, and compaction behavior. Understanding this architecture is essential for building session metadata extraction.

---

## Directory Structure

```
~/.claude/
├── projects/
│   └── [encoded-path]/                    # Per-project session storage
│       ├── [session-uuid].jsonl           # Full conversation history
│       └── [session-uuid].jsonl           # Additional sessions
├── history.jsonl                          # Session access history
├── settings.json                          # Global preferences & permissions
├── settings.local.json                    # Environment overrides (optional)
├── statsig/                               # Feature flags and tracking
├── todos/                                 # Task management
└── local/                                 # NPM packages and binaries
```

---

## Path Encoding

Claude Code encodes project paths by replacing forward slashes with hyphens:

```
Original:  /Users/user/Gravicity Projects
Encoded:   -Users-user-Gravicity-Projects
Location:  ~/.claude/projects/-Users-user-Gravicity-Projects/
```

### Encoding/Decoding Functions

```bash
# Encode path
encode_path() {
  echo "$1" | sed 's/\//-/g'
}

# Decode path
decode_path() {
  echo "$1" | sed 's/^-/\//; s/-/\//g'
}
```

**Caveat:** Paths with hyphens in folder names can cause ambiguity. The encoding is lossy.

---

## JSONL File Format

Each session is stored as a JSON Lines file where each line is a discrete event.

### Entry Types

| Type | Description | Token Cost | Search Value |
|------|-------------|------------|--------------|
| `user` | User messages | Medium | **Primary** |
| `assistant` | AI responses | High | Secondary |
| `summary` | Compaction summaries | Low | **High** |
| `tool_use` | Tool invocations | Medium | Activity indicator |
| `tool_result` | Tool outputs | High | Low (verbose) |
| `thinking` | Extended thinking | High | Low |
| `file-history-snapshot` | File state tracking | Medium | Low |

### User Message Structure

```json
{
  "type": "user",
  "uuid": "abc-123-def",
  "parentUuid": "xyz-789-ghi",
  "sessionId": "3f542803-742f-485d-a220-32fd83a3013a",
  "timestamp": "2025-11-28T14:30:00.271Z",
  "cwd": "/Users/user/Gravicity Projects",
  "gitBranch": "main",
  "version": "2.0.55",
  "userType": "external",
  "isSidechain": false,
  "message": {
    "role": "user",
    "content": [
      {
        "type": "text",
        "text": "Let's implement the token counter for the statusline"
      }
    ]
  }
}
```

### Assistant Message Structure

```json
{
  "type": "assistant",
  "uuid": "fbe30702-...",
  "parentUuid": "abc-123-def",
  "sessionId": "3f542803-...",
  "timestamp": "2025-11-28T14:30:15.740Z",
  "requestId": "req_011CVNJC...",
  "cwd": "/Users/user/Gravicity Projects",
  "gitBranch": "main",
  "version": "2.0.55",
  "userType": "external",
  "isSidechain": false,
  "message": {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "I'll implement the token counter..."
      },
      {
        "type": "tool_use",
        "id": "toolu_...",
        "name": "Edit",
        "input": {
          "file_path": "/path/to/file.sh",
          "old_string": "...",
          "new_string": "..."
        }
      }
    ]
  }
}
```

### Summary Entry Structure (Compaction)

```json
{
  "type": "summary",
  "summary": "Claude statusline box alignment fixes",
  "leafUuid": "66122d05-9592-41f4-b3ff-eb8b4ca047cc"
}
```

**Key insight:** Summary entries appear at the **beginning** of session files after compaction. The `leafUuid` points to the last message before compaction occurred.

---

## Message Threading (DAG Structure)

Claude Code uses a Git-like Directed Acyclic Graph for message threading:

```
Message 1 (uuid: A, parentUuid: null)
    │
    ▼
Message 2 (uuid: B, parentUuid: A)
    │
    ├──────────────────┐
    ▼                  ▼
Message 3a           Message 3b (isSidechain: true)
(uuid: C)            (uuid: D)
(parentUuid: B)      (parentUuid: B)
```

### Threading Rules

- First message: `parentUuid: null`
- Subsequent messages: `parentUuid` points to previous
- Sidechains: `isSidechain: true` for parallel threads
- Leaf messages: Tips of conversation branches

---

## Compaction Behavior

### What Triggers Compaction

- **Automatic:** Session approaches ~200k token context limit
- **Manual:** User runs `/compact` command

### What Happens During Compaction

1. Claude analyzes conversation to identify key information
2. Creates a concise summary
3. Adds `type: "summary"` entry at file **start**
4. Original messages remain in file (but not loaded into context)
5. New messages continue appending

### Compaction File Structure

```
┌─────────────────────────────────────────────┐
│ {"type":"summary","summary":"..."}          │  ← Added by compaction
│ {"type":"summary","summary":"..."}          │  ← Multiple if compacted multiple times
├─────────────────────────────────────────────┤
│ {"type":"user","message":{...}}             │  ← Original messages (still present)
│ {"type":"assistant","message":{...}}        │
│ ...                                         │
│ {"type":"user","message":{...}}             │  ← New messages after compaction
│ {"type":"assistant","message":{...}}        │
└─────────────────────────────────────────────┘
```

**Critical insight for search:** Old messages are still in the file! They're just not loaded into Claude's context. This means we can search the full history.

### Known Compaction Issues (from GitHub)

| Issue | Problem |
|-------|---------|
| #6641 | Resume picker shows generic message after compaction |
| #10948 | Auto-compact triggers mid-task, causes derailment |
| #1069 | Post-compaction "personality changes" |
| #2423 | Compaction timeouts on large sessions |
| #2597 | Cross-session summary contamination |

---

## Session Lifecycle

```
1. SESSION START
   ├─ New [uuid].jsonl created in project folder
   ├─ First user message written
   └─ history.jsonl updated

2. ACTIVE SESSION
   ├─ Messages appended to JSONL
   ├─ Tool uses and results recorded
   └─ File grows (can reach 20-30MB for long sessions)

3. CONTEXT LIMIT APPROACHING
   ├─ At ~95%: Auto-compact may trigger
   └─ Or user runs /compact manually

4. COMPACTION
   ├─ Summary entry prepended to file
   ├─ Old messages retained but not in context
   └─ Session continues with summary + new messages

5. SESSION RESUME
   ├─ history.jsonl checked for recent sessions
   ├─ JSONL loaded, summary entries processed
   └─ Context rebuilt from summary + recent messages
```

---

## Useful Fields for Metadata Extraction

### From User Messages

| Field | Use |
|-------|-----|
| `message.content[].text` | Topic/keyword extraction |
| `timestamp` | Session timeline |
| `cwd` | Project context |
| `gitBranch` | Code context |

### From Assistant Messages

| Field | Use |
|-------|-----|
| `message.content[].name` | Tools used (Edit, Bash, etc.) |
| `message.content[].input` | Files touched, commands run |
| `requestId` | API request correlation |

### From Summary Entries

| Field | Use |
|-------|-----|
| `summary` | Pre-made topic summary |
| `leafUuid` | Identify compaction boundaries |

---

## Extraction Strategies

### Fast Metadata Extraction (grep-based)

```bash
# Get all user message texts
grep '"type":"user"' session.jsonl | \
  jq -r '.message.content[0].text'

# Get all summaries
grep '"type":"summary"' session.jsonl | \
  jq -r '.summary'

# Get tool usage
grep -o '"name":"[A-Za-z]*"' session.jsonl | \
  sort | uniq -c | sort -rn
```

### Full Analysis (jq-based)

```bash
# Extract user messages with timestamps
jq -c 'select(.type == "user") | {
  time: .timestamp,
  text: .message.content[0].text
}' session.jsonl

# Get files touched by Edit tool
jq -r 'select(.type == "assistant") |
  .message.content[] |
  select(.name == "Edit") |
  .input.file_path' session.jsonl | sort -u
```

---

## File Size Considerations

| Session Length | Typical Size | Messages |
|----------------|--------------|----------|
| Short (1 hour) | 500KB-2MB | 20-50 |
| Medium (day) | 5-10MB | 100-300 |
| Long (multi-day) | 15-30MB | 500-1000+ |

**Performance note:** For large files, use streaming (grep first, then jq on matches) rather than loading entire file.

---

## Session Retention

- **Default:** 30-day automatic deletion
- **Override:** Set `cleanupPeriodDays` in settings.json

```json
{
  "cleanupPeriodDays": 99999
}
```

---

## Related Documentation

- Session rename investigation: `.claude/docs/claude-code/session-rename-investigation.md`
- Session finder skill: `.claude/skills/session-finder/`
- Official docs: https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-sessions

---

## References

- GitHub Issues: #2112, #3605, #6006, #7441, #10063, #3138
- Anthropic Engineering Blog
- Community deobfuscation projects (archived)
