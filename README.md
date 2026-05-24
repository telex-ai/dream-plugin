# Dream

Background memory consolidation for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Periodically reviews, deduplicates, prunes, and reindexes Claude Code's file-based memory system so it stays useful instead of accumulating drift.

## The Problem

Claude Code's auto-memory saves context across sessions into `~/.claude/projects/<repo>/memory/`. Over time this system suffers from:

- **Drift** — facts go stale as the codebase evolves
- **Duplication** — multiple sessions record overlapping information
- **Bloat** — MEMORY.md grows past its useful size
- **Date rot** — relative dates ("last week") lose meaning

Dream fixes this by running a 4-phase consolidation pass — orient, audit, consolidate, prune — either automatically or on demand.

## Install

### Quick start (session-only)

```bash
claude --plugin-dir /path/to/dream-plugin
```

### Permanent install

```bash
# Clone to plugin cache
git clone https://github.com/colindickson/dream-plugin.git ~/.claude/plugins/cache/dream
```

Then enable in your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "enabledPlugins": {
    "dream@inline": true
  }
}
```

## Usage

### Commands

| Command | What it does |
|---------|-------------|
| `/dream` | Run consolidation now |
| `/dream-status` | Show gate status, last run time, memory stats |
| `/dream-reset` | Clear state so gates reopen immediately |

### Auto-trigger

A **SessionStart hook** checks three gates when you start Claude Code:

| Gate | Default | What it checks |
|------|---------|---------------|
| Time | 24h | Hours since last consolidation |
| Sessions | 5 | New session transcripts since last run |
| Cooldown | 8h | Prevents repeated prompts within a window |

When all gates pass, Claude sees a context injection: "Memory consolidation is due." It handles your request first, then consolidates.

A **PostToolUse hook** watches for Write/Edit calls to files in `memory/` directories and stamps the lock file — resetting the time gate after each consolidation.

### The 4-Phase Consolidation

1. **Orient** — list memory files, read MEMORY.md, skim topic files
2. **Audit** — check each memory for staleness, duplication, bloat, broken links, date rot
3. **Consolidate** — merge duplicates, fix stale facts, delete obsolete memories, convert relative dates
4. **Prune & Index** — trim MEMORY.md to under 200 lines / 25KB, one-line entries, verify all links

## Configuration

Set via environment variables in your shell profile:

| Variable | Default | Description |
|----------|---------|-------------|
| `DREAM_MIN_HOURS` | `24` | Hours between consolidations |
| `DREAM_MIN_SESSIONS` | `5` | New sessions needed to trigger |
| `DREAM_COOLDOWN_HOURS` | `8` | Hours between auto-trigger prompts |

## How It Works

```
Session starts
  └─> SessionStart hook fires gate-check.sh
       ├─ Time gate:    stat lock file mtime, skip if < MIN_HOURS
       ├─ Session gate:  find transcripts newer than lock, skip if < MIN_SESSIONS  
       ├─ Cooldown gate: stat nag file mtime, skip if < COOLDOWN_HOURS
       └─ All pass → inject additionalContext into session
            └─> Claude runs dream:dream skill after user's request
                 ├─ Phase 1: Orient (read existing memories)
                 ├─ Phase 2: Audit (verify each memory)
                 ├─ Phase 3: Consolidate (merge/fix/delete)
                 └─ Phase 4: Prune (trim MEMORY.md index)
                      └─> PostToolUse hook stamps lock file
```

### State

All state lives in `~/.claude/dream-plugin-state/`:

| File | Purpose |
|------|---------|
| `.consolidate-lock` | mtime = last consolidation timestamp |
| `.last-nag` | mtime = last auto-trigger prompt |

## Project Structure

```
dream-plugin/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/dream/
│   └── SKILL.md                 # 4-phase consolidation prompt
├── commands/
│   ├── dream.md                 # /dream command
│   ├── dream-status.md          # /dream-status command
│   └── dream-reset.md           # /dream-reset command
├── hooks/
│   └── hooks.json               # SessionStart + PostToolUse hooks
├── scripts/
│   ├── gate-check.sh            # Gate evaluation logic
│   ├── stamp-consolidation.sh   # Lock file update
│   ├── check-dream-active.sh    # Detect memory directory writes
│   └── dream-status.sh          # Diagnostic output
├── LICENSE
└── README.md
```

## Background

Claude Code has a built-in dream feature (behind feature flags) that runs as a forked background subagent with its own task UI, PID-based locking, and GrowthBook configuration. This plugin reproduces the same consolidation logic using the public plugin API — hooks for auto-triggering, skills for the consolidation prompt, and shell scripts for gate evaluation. The tradeoff: no background execution or progress UI, but works with any Claude Code install without feature flags.

## License

MIT
