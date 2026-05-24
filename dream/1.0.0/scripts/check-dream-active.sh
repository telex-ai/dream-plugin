#!/usr/bin/env bash
# Check if the current tool use is writing to the memory directory during a dream.
# Used by PostToolUse hook to stamp consolidation after memory writes.
#
# Reads $ARGUMENTS (JSON) to check if file_path is inside the memory directory.
# If so, stamps the consolidation lock.

set -euo pipefail

# Parse the hook input — $ARGUMENTS is set by Claude Code
INPUT="${ARGUMENTS:-}"
if [ -z "$INPUT" ]; then
  exit 0
fi

# Extract file_path from the tool input JSON
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if the file is in a memory directory
if echo "$FILE_PATH" | grep -q "/memory/"; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  bash "$SCRIPT_DIR/stamp-consolidation.sh"
fi
