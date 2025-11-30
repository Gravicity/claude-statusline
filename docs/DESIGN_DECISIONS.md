# Design Decisions

## Layout Evolution

### v1: 3-Line Boxed Layout
Original design with closed box borders. Required complex width calculations for right-side alignment.

### v2: 4-Line Compact Layout
```
╭─Model─🧠─%─📚─n─💰/hr
│ Project $cost ─ git
│ ⧗ time 💬 msgs +/-code ※ session
╰─pulse animation─── 🛡 cache%
```

### v3: 4/5-Line Dynamic Layout (Current)
```
╭─Model─🧠─%─📚─n─💰[cycling]
│ 📁 ~/path/to/project
│ 🔀 branch ↑n↓n ●n~n?n +n-n 5m   (only if git repo)
│ ⧗ time 💬 msgs +/-code ※ session
╰─pulse animation─── 🛡 cache%
```

**Why 4/5 lines?**
- Line 2 was getting too wide with path + cost + git
- Git line appears only when in a git repo (5 lines), otherwise 4 lines
- Cost cycles on line 1: `/hr` → session → `Σ project`
- Keeps each line focused and readable

## Color Philosophy

### Model Themes
| Model | Color | Reasoning |
|-------|-------|-----------|
| Opus | Purple | Royal, prestigious - flagship model |
| Sonnet | Orange | Warm, creative - expressive |
| Haiku | Teal | Zen, minimal - clarity |

### Health Colors
Changed from cyan→blue→red to green→yellow→red:
- Universal traffic light convention
- True color (24-bit RGB) enables smooth gradients
- Same colors used for pulse animation gradient

## Pulse Animation

### Design
- Traveling orb moves left-to-right over 24 frames (24 seconds per cycle)
- Gradient trail: theme color → health color
- Fade ahead: health color → theme color
- Burst effect on frames 22-23 when orb hits end

### Box Drawing Characters
```
Behind orb: ───┉━━━━━◉
Ahead of orb: ◉╸╍┈───
```
- `─` thin line (theme color)
- `┉` transition marker
- `━` thick line (gradient)
- `◉` orb (health color)
- `╸╍┈` fade characters

## Project Cost Tracking

### Multi-Session Support
Each Claude session writes its own entry:
```json
{
  "name": "my-project",
  "icon": "📁",
  "color": null,
  "git": "https://github.com/user/repo",
  "parent": "/path/to/umbrella/.claude/statusline-project.json",
  "costs": {
    "sessions": {
      "session-id": { "cost": 28.50, "transcript": "/path/to.jsonl", "updated": "..." }
    },
    "total": 45.20,
    "session_count": 2
  }
}
```

### Parent/Umbrella Projects
- Sub-projects can reference a parent project via `parent` field
- When sub-project costs update, parent is also updated
- Enables tracking aggregate costs across a project ecosystem

### Auto-Initialization
- Git repos: Auto-create config when entering a git repo without one
- New folders: Auto-create config if no project found in path hierarchy
- Detects and links to parent projects automatically

### Atomic Updates
- mkdir-based locking (flock unavailable on macOS)
- Updates every 10 seconds (cycle 0) to reduce file I/O
- Cost cycling on line 1: `/hr` (3s) → session (3s) → `Σ` project (3s)

## Performance Optimizations

### Caching
- Git info: 5-second cache
- Git URL: 60-second cache
- Transcript parsing: cached until file modified

### Efficiency
- Single `case` block for model colors (ANSI + RGB)
- Inline conditionals where possible
- No unused code paths

## Stats Displayed

| Line | Stats |
|------|-------|
| 1 | Model, context %, memory files, cost (cycling: /hr → session → Σproject) |
| 2 | Project icon, truncated path |
| 3 | Git: branch (max 15 chars), ↑ahead ↓behind ●staged ~modified ?untracked +/-diff, commit age |
| 4 | Duration, messages, code changes, session ID |
| 5 | Pulse animation, cache % |

*Line 3 only appears in git repos (4 lines total otherwise)*

### Git Line Details
- **Branch**: Truncated at 15 chars, shows `..` if truncated
- **Stats**: ↑ahead(green) ↓behind(red) ●staged(green) ~modified(yellow) ?untracked(dim) +add-del
- **Commit age**: Health-colored based on staleness score: `(staged + modified) × minutes`
  - Green: score < 100
  - Yellow: score < 500
  - Red: score ≥ 500
- **Long branches**: Stats cycle in groups when branch name is truncated
