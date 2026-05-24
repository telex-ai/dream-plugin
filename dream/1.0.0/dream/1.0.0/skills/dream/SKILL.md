---
name: dream
description: >
  On-demand memory consolidation. Reviews accumulated memories for staleness,
  duplication, bloat, and missing signal from recent sessions. Merges, prunes,
  and reindexes MEMORY.md. Use when user says /dream, when memory feels cluttered,
  when MEMORY.md exceeds ~150 lines, or when the SessionStart hook injects a
  dream-due notice.
---

# Dream: Memory Consolidation

You are performing a dream — a reflective pass over your memory files.
Synthesize recent experience into durable, well-organized memories so that
future sessions can orient quickly without repeating discoveries.

## Phase 1 — Orient

1. List the memory directory to see what exists:
   ```
   ls -la ~/.claude/projects/*/memory/ 2>/dev/null || ls -la "$CLAUDE_MEMORY_DIR" 2>/dev/null
   ```
2. Read `MEMORY.md` to understand the current index
3. Skim every existing topic file (read first ~30 lines of each) to gauge coverage, freshness, and detect near-duplicates
4. Count lines in MEMORY.md — note if over 150

## Phase 2 — Audit

For **each** memory file, evaluate:

| Check | Action |
|-------|--------|
| **Staleness** | Does this fact still match the codebase? Grep/read to verify key claims. If wrong, mark for update or deletion. |
| **Duplication** | Do two files cover the same topic? Flag the pair for merge. |
| **Bloat** | Is any MEMORY.md entry over ~200 chars? Flag for demotion — move detail into the topic file, shorten the index line. |
| **Missing links** | Are there `[[name]]` references to memories that don't exist? Either create the referenced memory or remove the dead link. |
| **Type drift** | Does the `metadata.type` still match the content? (e.g., a "project" memory that's really "feedback") |
| **Date rot** | Any relative dates ("last week", "recently") that should be absolute? |

## Phase 3 — Consolidate

For each issue found in Phase 2:

- **Merge near-duplicates**: Keep the richer file, absorb the other's unique content, delete the redundant file
- **Fix stale facts**: Update to match current code/git state. If the entire memory is obsolete, delete the file
- **Convert relative dates** to absolute dates (use today's date as reference)
- **Remove memories that violate save rules**: code patterns derivable from reading files, git history available via `git log`, debugging solutions already in committed code, anything already in CLAUDE.md
- **Fix type fields** and update descriptions to match current content
- **Resolve contradictions**: if two files disagree, trust current code over old memory

## Phase 4 — Prune & Index

Update `MEMORY.md`:
- Each entry: one line, under ~150 characters: `- [Title](file.md) — one-line hook`
- Stay under 200 lines total and under ~25KB
- Remove pointers to deleted files
- Add pointers to any new files created during consolidation
- Sort semantically by topic, not chronologically
- Verify every link target exists

## Rules

- Do NOT create new memories about the current task or conversation
- Do NOT read full JSONL transcripts — only grep narrowly for specific terms if needed
- Focus on quality of existing memories, not creating new ones
- If everything looks clean and well-organized, say "Memory is clean — no changes needed" and stop
- Report a summary of changes: files merged, updated, deleted, and index lines changed

## When Triggered by Hook

If you see a `<dream-gate-check>` or `<user-prompt-submit-hook>` message indicating
dream is due, handle the user's request first, then run this consolidation at the
end of your turn. Mention briefly that you're consolidating memories.
