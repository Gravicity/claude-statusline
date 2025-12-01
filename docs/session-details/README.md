# Session Details Documentation

**Date:** December 1, 2025
**Purpose:** Documentation for Claude Code session metadata extraction and statusline integration

---

## Document Index

| Document | Description |
|----------|-------------|
| **[IMPLEMENTATION-PLAN-V3.md](./IMPLEMENTATION-PLAN-V3.md)** | **Final plan** - Multi-trigger, non-blocking, evolution tracking |
| [SESSION-METADATA-SPEC.md](./SESSION-METADATA-SPEC.md) | Data structure for enriched session metadata |
| [SESSION-STORAGE-ARCHITECTURE.md](./SESSION-STORAGE-ARCHITECTURE.md) | How Claude Code stores sessions (JSONL, paths, compaction) |
| [EXTRACTION-STRATEGY.md](./EXTRACTION-STRATEGY.md) | Pipeline for extracting meaningful metadata |
| [HOOK-INTEGRATION.md](./HOOK-INTEGRATION.md) | Triggers for automatic metadata updates |
| [SESSION-FINDER-SKILL.md](./SESSION-FINDER-SKILL.md) | Reference for the implemented session-finder skill |

---

## Quick Summary

### The Problem

Claude Code sessions are identified by UUIDs and displayed by their first message. Finding a specific session from days ago is painful - especially with multiple sessions per project.

### The Solution

1. **Session Finder Skill** - Search sessions by keyword
2. **Metadata Extraction** - Generate topic, keywords, milestones, overview
3. **Hook Integration** - Auto-update metadata at context barriers
4. **Statusline Display** - Show meaningful session info

### Key Data Structure

```json
{
  "session_id": "abc-123-def",
  "topic": "Statusline Token Tracking",
  "keywords": ["statusline", "tokens", "cost"],
  "milestones": [
    {"type": "feature", "text": "Added token counter"}
  ],
  "overview": "Built terminal statusline with cost tracking",
  "context_stage": "80%"
}
```

### Update Triggers

- **50% context** - Light extraction
- **80% context** - Full extraction
- **PreCompact** - Final extraction before compaction
- **PostCompact** - Incorporate Claude's summary

---

## Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| Session finder skill | ✅ Implemented | `.claude/skills/session-finder/` |
| Metadata spec | ✅ Documented | This folder |
| Storage architecture | ✅ Researched | This folder |
| Extraction strategy | ✅ Designed | This folder |
| Hook integration | ✅ Designed | This folder |
| **Implementation Plan v3** | ✅ **Approved** | `IMPLEMENTATION-PLAN-V3.md` |
| Multi-trigger system | 🔜 Phase 1 | statusline-command.sh |
| Non-blocking agent | 🔜 Phase 2 | `~/.claude/agents/` |
| Evolution tracking | 🔜 Phase 3 | - |
| AI synthesis | 🔜 Phase 4 (optional) | - |
| Custom resume command | 🔮 Future | - |

---

## Key Findings

1. **Sessions are searchable** - Old messages remain in JSONL after compaction
2. **Summaries are gold** - Claude's compaction summaries are high-quality metadata
3. **Path encoding is simple** - Slashes become hyphens
4. **Tool usage reveals intent** - Edit/Bash/Read patterns indicate activity type
5. **Topic shifts happen** - Need to detect and archive old topics

---

## Next Steps

See **[IMPLEMENTATION-PLAN-V3.md](./IMPLEMENTATION-PLAN-V3.md)** for detailed phases:

1. **Phase 1:** Multi-trigger infrastructure (50%/80% context barriers + hooks)
2. **Phase 2:** Non-blocking extraction agent (fire-and-forget)
3. **Phase 3:** Evolution tracking (drift detection, segments)
4. **Phase 4:** Optional AI synthesis (Haiku)
5. **Future:** Custom `--resume` command with interactive picker

---

## Related Resources

- Session rename investigation: `.claude/docs/claude-code/session-rename-investigation.md`
- Skill research: `.claude/docs/anthropic/skills/research/`
- Statusline implementation: `claude-statusline/`
