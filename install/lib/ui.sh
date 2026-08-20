#!/usr/bin/env bash
#
# Terminal output helpers: colors, log levels, prompts, spinner-free progress.
#
# Everything the installer prints goes through here, so the whole run has one
# voice and one place to change it. Nothing in this file touches the system.
#
# The palette is deliberately plain ANSI, not the Catppuccin colors from
# theme/palettes.py: the installer runs before any theming exists, often in a
# bare TTY right after `archinstall`, where only the sixteen basic colors are
# guaranteed to render.

# ── Colors ─────────────────────────────────────────────────────────────────
#
# Disabled when the output is not a terminal (`./install.sh | tee log`) or when
# NO_COLOR is set, so the log file stays readable.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi

# ── Log levels ─────────────────────────────────────────────────────────────

# A step banner. Printed once per step so a long run stays readable when
# scrolling back.
section() {
  printf '\n%s%s══ %s %s%s\n' "$C_BOLD" "$C_BLUE" "$1" \
    "$(printf '═%.0s' $(seq 1 $((60 - ${#1} > 0 ? 60 - ${#1} : 0))))" "$C_RESET"
}

info() { printf '%s::%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok() { printf '%s ✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s ! %s %s\n' "$C_YELLOW$C_BOLD" "$C_RESET" "$*" >&2; }
err() { printf '%s ✘%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; }
note() { printf '   %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# Fatal: print and stop the installer. Every abort goes through here so the
# exit code is always 1 and the message always looks the same.
die() {
  err "$*"
  exit 1
}

# ── Prompts ────────────────────────────────────────────────────────────────

# ask "question" [default]
#
#   default = y  → [Y/n], Enter means yes
#   default = n  → [y/N], Enter means no
#
# With --yes (ASSUME_YES=1) nothing is asked and the default is taken, which is
# what makes an unattended run possible. Reading from /dev/tty instead of stdin
# keeps the prompt working when the installer itself is piped
# (`curl ... | bash`), where stdin is the script, not the keyboard.
ask() {
  local question="$1" default="${2:-y}" reply prompt

  [[ "$default" == "y" ]] && prompt="[Y/n]" || prompt="[y/N]"

  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    note "$question $prompt → $default (--yes)"
    [[ "$default" == "y" ]]
    return
  fi

  if [[ ! -t 0 && ! -r /dev/tty ]]; then
    note "$question $prompt → $default (not a terminal)"
    [[ "$default" == "y" ]]
    return
  fi

  while true; do
    printf '%s?%s %s %s ' "$C_MAGENTA$C_BOLD" "$C_RESET" "$question" "$prompt" >&2
    read -r reply < /dev/tty || reply=""
    reply="${reply:-$default}"
    case "${reply,,}" in
      y | yes | s | sim) return 0 ;;
      n | no | nao | não) return 1 ;;
      *) warn "answer y or n" ;;
    esac
  done
}

# ── Running commands ───────────────────────────────────────────────────────

# run <command...>
#
# Every command that changes the system goes through this wrapper: it echoes
# what it is about to do and, under --dry-run, stops there. That is what makes
# `./install.sh --dry-run` a truthful preview instead of a guess.
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '   %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET"
    return 0
  fi
  printf '   %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET"
  "$@"
}

# Same as run(), but for commands that need root. Kept separate so a reader can
# grep the installer for everything it does with elevated privileges.
sudo_run() {
  run sudo "$@"
}

# Writes <content on stdin> to a file owned by the user. Under --dry-run it
# prints the file instead, indented, so a preview run shows exactly what would
# have been generated.
write_file() {
  local target="$1"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '   %s$ write %s:%s\n' "$C_DIM" "$target" "$C_RESET"
    sed 's/^/     | /'
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  cat > "$target"
  ok "wrote ${target/#$HOME/\~}"
}

# Writes <content on stdin> to a root-owned file, showing a diff-friendly
# header first. Used for /etc/modprobe.d and friends.
sudo_write() {
  local target="$1"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '   %s$ write %s:%s\n' "$C_DIM" "$target" "$C_RESET"
    sed 's/^/     | /'
    return 0
  fi
  sudo tee "$target" > /dev/null
  ok "wrote $target"
}
