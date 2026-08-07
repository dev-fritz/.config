#!/usr/bin/env bash
#
# Take a screenshot, copy it to the clipboard and open an editor to annotate it.
#
# grim takes the picture, the image goes to the clipboard right away (so Ctrl+V
# works even if you close the editor without doing anything), and satty opens
# for annotation. In satty: Ctrl+C or Enter copies the edited version and quits,
# Ctrl+S saves to ~/Images/Screenshots, Esc quits leaving the clipboard alone.
#
# satty is preferred over swappy for its cleaner interface, real undo/redo and
# configurable palette, which follows the active Catppuccin variant (see
# ~/.config/satty/config.toml). swappy is used as a fallback if satty is missing.
#
# Usage:
#   screenshot.sh area     select a region (default)
#   screenshot.sh full     the focused monitor
#   screenshot.sh window   the active window
#   screenshot.sh all      every monitor side by side
#
# Requires: grim slurp wl-clipboard satty

set -euo pipefail

MODO="${1:-area}"
DIR="$HOME/Images/Screenshots"
ARQUIVO="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

mkdir -p "$DIR"

# ── Notifications ───────────────────────────────────────────────────────────
# Uses the notification daemon if one is running, otherwise does nothing.
avisar() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a "Screenshot" "$@" || true
}

falhar() {
  avisar -u critical "Screenshot failed" "$1"
  echo "error: $1" >&2
  exit 1
}

# ── Capture area for each mode ──────────────────────────────────────────────
geometria() {
  case "$MODO" in
    area)
      # `slurp -d` draws the selection borders while you drag.
      slurp -d || falhar "selection cancelled"
      ;;
    full)
      # Only the focused monitor. python3 is used instead of jq so the script
      # doesn't pull in another package just to read two lines of JSON.
      hyprctl -j monitors 2>/dev/null | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m.get("focused"):
        x, y, w, h = m["x"], m["y"], m["width"], m["height"]
        print("%d,%d %dx%d" % (x, y, w, h))
        break
' || falhar "could not determine the focused monitor"
      ;;
    window)
      hyprctl -j activewindow 2>/dev/null | python3 -c '
import json, sys
w = json.load(sys.stdin)
x, y = w["at"]; cx, cy = w["size"]
print(f"{x},{y} {cx}x{cy}")
' || falhar "could not determine the active window"
      ;;
    all)
      echo "" # no -g, so grim captures everything
      ;;
    *)
      falhar "unknown mode: $MODO (use area, full, window or all)"
      ;;
  esac
}

GEO="$(geometria)"

# ── Capture ─────────────────────────────────────────────────────────────────
if [[ -n "$GEO" ]]; then
  grim -g "$GEO" "$ARQUIVO" || falhar "grim failed to capture"
else
  grim "$ARQUIVO" || falhar "grim failed to capture"
fi

# ── Copy to the clipboard ───────────────────────────────────────────────────
# Done before opening the editor on purpose: if you give up, the original
# image is already copied.
wl-copy --type image/png < "$ARQUIVO"

# ── Editor ──────────────────────────────────────────────────────────────────
if command -v satty >/dev/null 2>&1; then
  # Appearance and output options come from ~/.config/satty/config.toml;
  # this only says which file to open and where to save it.
  satty --filename "$ARQUIVO" --output-filename "$ARQUIVO"
  avisar "Screenshot ready" "Copied and saved to ${ARQUIVO/#$HOME/\~}"
elif command -v swappy >/dev/null 2>&1; then
  # Fallback when satty isn't installed.
  swappy -f "$ARQUIVO" -o "$ARQUIVO"
  avisar "Screenshot ready (swappy)" \
    "For the better editor:  sudo pacman -S satty"
else
  avisar "Screenshot copied" \
    "Install an editor to annotate:  sudo pacman -S satty"
fi
