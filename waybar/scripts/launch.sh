#!/usr/bin/env bash
#
# Launcher with a fallback, used by the bar's click actions.
#
# A Waybar `on-click` pointing at a program that isn't installed simply does
# nothing — no error, no warning — so the bar looks broken. This script tries a
# list of graphical programs in order and, if none is installed, falls back to a
# terminal command that always exists.
#
# Usage:
#   launch.sh --terminal "<terminal command>" prog1 [prog2 ...]
#
# Examples:
#   launch.sh --terminal "wpctl status" pavucontrol pwvucontrol wiremix
#   launch.sh --terminal "top" btop htop
#
# Each "prog" may include arguments, quoted:
#   launch.sh --terminal "nmtui" "nm-connection-editor"

set -euo pipefail

TERMINAL_CMD=""

# ── Read the --terminal option ──────────────────────────────────────────────
if [[ "${1:-}" == "--terminal" ]]; then
  TERMINAL_CMD="${2:-}"
  shift 2
fi

# ── Try each graphical candidate ────────────────────────────────────────────
for candidato in "$@"; do
  # Only the first token is the executable; the rest are arguments.
  binario="${candidato%% *}"
  if command -v "$binario" >/dev/null 2>&1; then
    # shellcheck disable=SC2086  # word splitting is intentional here
    exec setsid $candidato >/dev/null 2>&1
  fi
done

# ── None installed: fall back to a terminal ─────────────────────────────────
if [[ -n "$TERMINAL_CMD" ]]; then
  # Find an available terminal emulator.
  for term in kitty alacritty foot wezterm ghostty xterm; do
    if command -v "$term" >/dev/null 2>&1; then
      # The trailing `read` keeps the window open so you can read the output
      # of commands that finish immediately, such as `wpctl status`.
      exec setsid "$term" -e sh -c "$TERMINAL_CMD; printf '\n[Enter to close] '; read _" \
        >/dev/null 2>&1
    fi
  done
fi

exit 0
