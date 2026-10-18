#!/bin/bash
# Cloud-Sitzung vorbereiten: Linux-Godot holen und das Projekt importieren,
# damit `node scripts/godot-test.mjs` sofort laeuft. Lokal (Windows) passiert nichts.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

VERSION=4.7.2
DIR="$HOME/.cache/godot-$VERSION"
BIN="$DIR/Godot_v${VERSION}-stable_linux.x86_64"

if [ ! -x "$BIN" ]; then
  mkdir -p "$DIR"
  curl -sSL -o "$DIR/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -q -o "$DIR/godot.zip" -d "$DIR"
  rm -f "$DIR/godot.zip"
  chmod +x "$BIN"
fi

echo "export GODOT_BIN=\"$BIN\"" >> "$CLAUDE_ENV_FILE"

# Import erzeugt .godot/ (Klassen-Cache); ohne ihn schlagen Tests mit Ladefehlern fehl.
"$BIN" --headless --path "$CLAUDE_PROJECT_DIR/godot" --import >/dev/null 2>&1 || true
