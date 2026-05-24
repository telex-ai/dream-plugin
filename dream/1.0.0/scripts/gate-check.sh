#!/usr/bin/env bash
# Dream gate check — called by SessionStart hook.
# Checks time + session gates. Outputs JSON with additionalContext if dream is due.
#
# Gate order (cheapest first):
#   1. Time: hours since last consolidation >= MIN_HOURS
#   2. Sessions: transcript count with mtime > last consolidation >= MIN_SESSIONS
#   3. Cooldown: don't nag more than once per COOLDOWN_HOURS
#
# Environment:
#   DREAM_MIN_HOURS    — minimum hours between consolidations (default: 24)
#   DREAM_MIN_SESSIONS — minimum new sessions required (default: 5)
#   DREAM_COOLDOWN_HOURS — hours between nag injections (default: 8)

set -euo pipefail

MIN_HOURS="${DREAM_MIN_HOURS:-24}"
MIN_SESSIONS="${DREAM_MIN_SESSIONS:-5}"
COOLDOWN_HOURS="${DREAM_COOLDOWN_HOURS:-8}"

# Resolve memory directory — same path convention as Claude Code
resolve_memory_dir() {
  local cwd
  cwd="$(pwd)"

  # Check for git root first
  local git_root
  git_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")"

  local project_path="${git_root:-$cwd}"
  # Claude Code slugifies the path: replace / with -Users-colindickson-... etc
  local slug
  slug="$(echo "$project_path" | sed 's|^/||; s|/|-|g')"

  local mem_dir="$HOME/.claude/projects/-${slug}/memory"

  # Fall back to scanning for any matching project dir
  if [ ! -d "$mem_dir" ]; then
    # Try to find an existing memory dir for this project
    local found
    found="$(find "$HOME/.claude/projects" -maxdepth 2 -name "memory" -type d 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
      mem_dir="$found"
    fi
  fi

  echo "$mem_dir"
}

# Resolve transcripts directory
resolve_transcript_dir() {
  local cwd
  cwd="$(pwd)"
  local git_root
  git_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")"
  local project_path="${git_root:-$cwd}"
  local slug
  slug="$(echo "$project_path" | sed 's|^/||; s|/|-|g')"

  local dir="$HOME/.claude/projects/-${slug}"
  if [ ! -d "$dir" ]; then
    dir="$(find "$HOME/.claude/projects" -maxdepth 1 -name "*${slug}*" -type d 2>/dev/null | head -1)"
  fi
  echo "${dir:-}"
}

DREAM_STATE_DIR="$HOME/.claude/dream-plugin-state"
mkdir -p "$DREAM_STATE_DIR"

LOCK_FILE="$DREAM_STATE_DIR/.consolidate-lock"
NAG_FILE="$DREAM_STATE_DIR/.last-nag"

MEM_DIR="$(resolve_memory_dir)"
TRANSCRIPT_DIR="$(resolve_transcript_dir)"

# --- Gate 1: Time ---
last_consolidated=0
if [ -f "$LOCK_FILE" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    last_consolidated=$(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)
  else
    last_consolidated=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
  fi
fi

now=$(date +%s)
hours_since=$(( (now - last_consolidated) / 3600 ))

if [ "$hours_since" -lt "$MIN_HOURS" ]; then
  exit 0
fi

# --- Gate 2: Sessions ---
session_count=0
if [ -n "$TRANSCRIPT_DIR" ] && [ -d "$TRANSCRIPT_DIR" ]; then
  if [ -f "$LOCK_FILE" ]; then
    session_count=$(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" -newer "$LOCK_FILE" 2>/dev/null | wc -l | tr -d ' ')
  else
    session_count=$(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

if [ "$session_count" -lt "$MIN_SESSIONS" ]; then
  exit 0
fi

# --- Cooldown: Don't nag too often ---
last_nag=0
if [ -f "$NAG_FILE" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    last_nag=$(stat -f %m "$NAG_FILE" 2>/dev/null || echo 0)
  else
    last_nag=$(stat -c %Y "$NAG_FILE" 2>/dev/null || echo 0)
  fi
fi
nag_hours_since=$(( (now - last_nag) / 3600 ))

if [ "$nag_hours_since" -lt "$COOLDOWN_HOURS" ]; then
  exit 0
fi

# --- All gates passed ---
# Update nag timestamp
touch "$NAG_FILE"

# Output structured hook response
cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Memory consolidation is due: ${hours_since}h since last consolidation (threshold: ${MIN_HOURS}h), ${session_count} new sessions (threshold: ${MIN_SESSIONS}). Use the dream:dream skill to consolidate after handling the user's request. Memory directory: ${MEM_DIR}"
  }
}
HOOK_JSON
