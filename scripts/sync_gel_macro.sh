#!/usr/bin/env bash
set -euo pipefail

# Sync the current private gel-label macro into this public repository.
# Usage:
#   scripts/sync_gel_macro.sh
#   scripts/sync_gel_macro.sh /path/to/source.ijm
#   scripts/sync_gel_macro.sh /path/to/source.ijm /path/to/destination.ijm

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_SOURCE="/Users/me/Documents/GitHub/imagej-macros/macros/2026_04_23_gel_label_span.ijm"
DEFAULT_DEST="${REPO_ROOT}/tools/fiji/gel_label.ijm"

SOURCE_PATH="${1:-$DEFAULT_SOURCE}"
DEST_PATH="${2:-$DEFAULT_DEST}"

if [[ ! -f "$SOURCE_PATH" ]]; then
  echo "Error: source macro not found: $SOURCE_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST_PATH")"
cp "$SOURCE_PATH" "$DEST_PATH"

echo "Synced macro:"
echo "  from: $SOURCE_PATH"
echo "  to:   $DEST_PATH"
