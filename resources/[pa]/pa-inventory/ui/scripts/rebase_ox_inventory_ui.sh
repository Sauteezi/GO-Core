#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 /path/to/ox_inventory"
  exit 1
fi

OX_PATH="$1"
SRC="$OX_PATH/web"
DEST="$(cd "$(dirname "$0")/.." && pwd)/upstream"

if [ ! -d "$SRC" ]; then
  echo "Could not find upstream web folder: $SRC"
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/

echo "Refreshed upstream UI snapshot in: $DEST"
