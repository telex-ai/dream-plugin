#!/usr/bin/env bash
# Stamp consolidation lock after a successful /dream run.
# Called by the PostToolUse hook that watches for Write/Edit to memory files.
# Updates the lock file mtime so the time gate resets.

set -euo pipefail

DREAM_STATE_DIR="$HOME/.claude/dream-plugin-state"
mkdir -p "$DREAM_STATE_DIR"

LOCK_FILE="$DREAM_STATE_DIR/.consolidate-lock"

# Write PID and touch to reset mtime
echo "$$" > "$LOCK_FILE"
