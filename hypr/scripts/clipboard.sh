#!/usr/bin/env bash
#
# Clipboard history browser, rendered with rofi.
#
# cliphist is only a database. It's fed by two watchers running in the
# background (see conf/autostart.lua):
#
#     wl-paste --type text  --watch cliphist store
#     wl-paste --type image --watch cliphist store
#
# Without them the history stays empty — cliphist does not listen on its own.
#
# Usage:
#   clipboard.sh        open the picker (SUPER + V)
#   clipboard.sh wipe   erase the whole history
#
# In the picker, Enter copies the selected entry back to the clipboard and
# Ctrl+Delete removes it from the history.
#
# Requires: cliphist wl-clipboard rofi

set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && notify-send -u critical \
    "cliphist is not installed" "sudo pacman -S cliphist" || true
  exit 1
fi

# ── Wipe the history ────────────────────────────────────────────────────────
if [[ "${1:-}" == "wipe" ]]; then
  cliphist wipe
  command -v notify-send >/dev/null 2>&1 && notify-send "Clipboard" "History cleared" || true
  exit 0
fi

# ── Picker ──────────────────────────────────────────────────────────────────
# `cliphist list` returns lines shaped as "<id>\t<preview>". `decode` needs the
# id later, so the whole line is passed to rofi.
#
# `-display-columns 2` makes rofi display only the second column (the content)
# while still returning the full line, so the list looks clean and decode still
# gets its id.
ESCOLHA="$(
  cliphist list | rofi -dmenu \
    -p "󰅇 clipboard" \
    -i \
    -matching normal \
    -display-columns 2 \
    -theme-str 'window { width: 900px; } listview { lines: 12; } element-icon { size: 0; }' \
    -kb-custom-1 "Control+Delete" \
    -mesg "Enter copies · Ctrl+Delete removes from history"
)" || CODIGO=$?
CODIGO="${CODIGO:-0}"

# rofi exits with 10 when -kb-custom-1 is pressed.
if [[ "$CODIGO" -eq 10 ]]; then
  [[ -n "${ESCOLHA:-}" ]] && printf '%s' "$ESCOLHA" | cliphist delete
  exit 0
fi

[[ -z "${ESCOLHA:-}" ]] && exit 0

# `decode` swaps the id for the real content, images included.
printf '%s' "$ESCOLHA" | cliphist decode | wl-copy
