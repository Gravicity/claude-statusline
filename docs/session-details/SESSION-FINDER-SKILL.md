# Session Finder Skill Reference

**Date:** December 1, 2025
**Location:** `.claude/skills/session-finder/`
**Status:** Implemented and tested

---

## Overview

The session-finder skill provides search and analysis capabilities for Claude Code sessions. It enables finding lost conversations by keyword and extracting structured metadata from individual sessions.

---

## Skill Structure

```
.claude/skills/session-finder/
├── SKILL.md                    # Skill definition with triggers
├── scripts/
│   └── find-sessions.sh        # Main parsing script (340 lines)
└── README.md                   # Design documentation
```

---

## Usage Modes

### 1. Search Mode (Default)

Find sessions containing a keyword:

```bash
# Basic search (last 14 days)
find-sessions.sh "statusline"

# With options
find-sessions.sh --medium --days 30 --limit 10 "auth"

# Project-scoped
find-sessions.sh --project verivox "api"
```

**Output:**
```
Sessions matching 'statusline'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 2025-11-30 10:45 │ Projects │ 2826 matches
   Summary: Claude statusline box alignment fixes
   claude --resume 3f542803-742f-485d-a220-32fd83a3013a

2. 2025-11-29 04:07 │ Projects │ 1507 matches
   "Let's work on the token counter..."
   claude --resume 701cb12f-7eef-406e-aba2-8ce0b4c175d3
```

### 2. Single File Mode

Deep analysis of one session:

```bash
# Human-readable output
find-sessions.sh --file 3f542803-742f-485d-a220-32fd83a3013a

# JSON output (for integration)
find-sessions.sh --file 3f542803-742f-485d-a220-32fd83a3013a --json
```

**Human Output:**
```
Session Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session ID:  3f542803-742f-485d-a220-32fd83a3013a
Project:     /Users/user/Gravicity/Projects
Modified:    2025-11-30 10:45
Size:        26MB
Messages:    1055 user messages
Tools:       Bash(316) Edit(218) Read(156) Grep(81) Write(21)

First Message:
  This session is being continued from a previous conversation...

Summaries:
  Claude statusline box alignment fixes
  Claude Statusline Box Alignment Debugging
  Claude Code Statusline Alignment & Terminal Width

Resume: claude --resume 3f542803-742f-485d-a220-32fd83a3013a
```

**JSON Output:**
```json
{
  "session_id": "3f542803-742f-485d-a220-32fd83a3013a",
  "project_path": "/Users/user/Gravicity/Projects",
  "last_modified": "2025-11-30 10:45",
  "file_size": "26MB",
  "first_message": "This session is being continued...",
  "summaries": [
    "Claude statusline box alignment fixes",
    "Claude Statusline Box Alignment Debugging",
    "Claude Code Statusline Alignment & Terminal Width"
  ],
  "user_message_count": 1055,
  "tools_used": "Bash(316) Edit(218) Read(156) Grep(81) Write(21)",
  "recent_messages": []
}
```

---

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--quick` | Fast: grep + metadata only | Yes |
| `--medium` | + match context + summaries | |
| `--thorough` | + comprehensive data | |
| `--days N` | Limit to last N days | 14 |
| `--limit N` | Max results | 10 |
| `--project P` | Filter by project path | |
| `--file ID` | Analyze single session | |
| `--json` | Output as JSON | |
| `--help` | Show usage | |

---

## Depth Modes Comparison

| Mode | Speed | Extracts |
|------|-------|----------|
| `--quick` | ~2s | File metadata, match count, first message |
| `--medium` | ~10s | + match context snippets, summaries |
| `--thorough` | ~15s | + tools used, files touched |

---

## Integration Points

### For Statusline Metadata

Use `--file --json` to get structured data for metadata extraction:

```bash
# In hook or extraction script
signals=$(find-sessions.sh --file "$session_id" --json)

# Extract what we need
summaries=$(echo "$signals" | jq -r '.summaries[]')
tools=$(echo "$signals" | jq -r '.tools_used')
msg_count=$(echo "$signals" | jq -r '.user_message_count')
```

### For Session Search

Use in SKILL.md workflow to help users find sessions:

```
User: "find the session where I worked on auth"
Claude: [Uses find-sessions.sh "auth" --medium]
Claude: "Found 5 sessions. The most relevant appears to be..."
```

### For Hook Scripts

Call from PreCompact hook to extract raw signals:

```bash
#!/bin/bash
# In extract-session-metadata.sh hook

signals=$("$SKILL_DIR/scripts/find-sessions.sh" --file "$session_id" --json)
# Process signals...
```

---

## Key Functions in Script

### `decode_path()`
Converts Claude's encoded path back to readable format.
```
-Users-user-Gravicity-Projects → /Users/user/Gravicity/Projects
```

### `get_first_user_msg()`
Extracts the first user message (often the session "name").

### `get_summaries()`
Extracts compaction summaries from file start.

### `get_tools_used()`
Counts tool usage by name.

### `get_match_context()`
Gets text snippets around keyword matches.

---

## Test Results

**Search for "statusline" (7 days):**
- Found: 76 sessions
- Time: ~3 seconds
- Top result: 2826 matches

**Search for "verivox" (14 days):**
- Found: 339 sessions
- Time: ~5 seconds
- Top result: 5279 matches

**Single file analysis (26MB session):**
- Time: ~2 seconds
- Extracted: 1055 user messages, 5 tool types, 3 summaries

---

## Known Limitations

1. **First message extraction:** Shows "(no message)" for some sessions with complex content structure
2. **Result count display:** Off-by-one in "Showing X of Y" message
3. **Recent messages:** JSON extraction for recent messages sometimes returns empty
4. **Large files:** Sessions >50MB may be slow to process

---

## Future Improvements

- [ ] Better first message extraction for compacted sessions
- [ ] Full-text search index for faster queries
- [ ] Integration with AI synthesis (Haiku) for metadata generation
- [ ] Support for date range filtering (not just "days ago")
- [ ] Export to common formats (CSV, Markdown)

---

## File Locations

| Component | Path |
|-----------|------|
| Skill definition | `.claude/skills/session-finder/SKILL.md` |
| Main script | `.claude/skills/session-finder/scripts/find-sessions.sh` |
| Design docs | `.claude/skills/session-finder/README.md` |
| Session storage | `~/.claude/projects/[encoded-path]/` |

---

## Related Documentation

- Session metadata spec: `claude-statusline/docs/session-details/SESSION-METADATA-SPEC.md`
- Storage architecture: `claude-statusline/docs/session-details/SESSION-STORAGE-ARCHITECTURE.md`
- Extraction strategy: `claude-statusline/docs/session-details/EXTRACTION-STRATEGY.md`
- Hook integration: `claude-statusline/docs/session-details/HOOK-INTEGRATION.md`
