#!/usr/bin/env bash
#
# ╭───────────────────────────────────────────────────────────────────────────╮
# │  Installer for these dotfiles.                                            │
# │                                                                           │
# │      git clone https://github.com/dev-fritz/.config.git ~/dotfiles        │
# │      ~/dotfiles/install.sh                                                │
# │                                                                           │
# │  Turns a freshly installed Arch into this desktop: installs the packages, │
# │  the driver the detected GPU actually needs, moves the repository into    │
# │  ~/.config, generates the machine-specific configs and the color files.   │
# ╰───────────────────────────────────────────────────────────────────────────╯
#
# Nothing about the hardware is written down anywhere in this repository. The
# GPU vendor, the temperature sensor, the backlight device, whether there is a
# battery or a Bluetooth controller — all of it is read from the running system
# at install time (install/lib/detect.sh) and turned into two generated files
# (install/steps/50-hardware.sh). The same clone therefore works on the laptop
# with an NVIDIA card and on a machine with no discrete GPU at all.
#
# Run `./install.sh --help` for the options, `--detect` to see what it thinks
# the hardware is, and `--dry-run` to watch a full run without changing
# anything.
#
# The steps live in install/steps/, one file each, and are documented there.

set -Eeuo pipefail

# ── Where everything is ────────────────────────────────────────────────────

# readlink -f so the script also works through a symlink or from another
# directory: every path below is derived from this one.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOT_ROOT="$(dirname "$SCRIPT_PATH")"
DOT_INSTALL="$DOT_ROOT/install"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Kept for the re-exec in the relocation step, which has to hand the same
# options to the copy of itself at the new location.
DOT_ARGS=("$@")

# ── Defaults ───────────────────────────────────────────────────────────────

# GROUPS (without the prefix) is a special bash array holding the user's
# group ids — assigning to it silently does nothing useful.
DOT_GROUPS="apps,dev,extras" # on top of core, which is never optional
STEPS_ALL=(relocate preflight aur packages drivers hardware shell services theme summary)
STEPS_RUN=("${STEPS_ALL[@]}")
ASSUME_YES=0
DRY_RUN=0
USE_AUR=1
SKIP_UPGRADE=0
WALLPAPERS=0
GPU_OVERRIDE="auto"
NVIDIA_BRANCH_OVERRIDE=""
THEME_VARIANT=""
DETECT_ONLY=0

usage() {
  cat << 'USAGE'
Usage: ./install.sh [options]

  Installs this desktop on Arch Linux, adapting to the hardware it finds.

Options:
  -y, --yes                 answer every prompt with its default; unattended run
  -n, --dry-run             print every command instead of running it
      --detect              show what the installer sees in this machine, then exit
  -h, --help                this text

  --groups=LIST             optional package groups, comma separated
                            apps  browser, chat, media, desktop utilities
                            dev   toolchains, docker, command line tools
                            extras  printing, firewall, zram, archive tools
                            (default: apps,dev,extras — "core" is always installed)

  --only=LIST               run only these steps, comma separated
  --skip=LIST               run everything except these steps
                            steps: relocate preflight aur packages drivers
                                   hardware shell services theme summary

  --gpu=VENDOR              force the graphics vendor instead of detecting it
                            nvidia | amd | intel | none
  --nvidia-driver=BRANCH    force the NVIDIA branch
                            open      nvidia-open-dkms   (Turing and newer)
                            580xx     AUR, frozen        (Maxwell/Pascal/Volta)
                            470xx     AUR, frozen        (Kepler)
                            nouveau   no NVIDIA driver at all

  --theme=VARIANT           apply this palette instead of the default
                            (catppuccin-mocha, gruvbox-dark, nord, ...)
  --wallpapers              download a wallpaper set without asking
  --no-aur                  do not install or use an AUR helper
  --no-upgrade              do not run `pacman -Syu` first

Examples:
  ./install.sh                          full install, asking before each decision
  ./install.sh --yes                    same, unattended
  ./install.sh --dry-run                preview, changing nothing
  ./install.sh --groups=core            only what the dotfiles need
  ./install.sh --only=hardware          regenerate the machine-specific configs
  ./install.sh --only=theme             regenerate the color files
USAGE
}

# ── Options ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes) ASSUME_YES=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    --detect) DETECT_ONLY=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    --groups=*) DOT_GROUPS="${1#*=}" ;;
    --only=*) IFS=',' read -ra STEPS_RUN <<< "${1#*=}" ;;
    --skip=*)
      IFS=',' read -ra _skip <<< "${1#*=}"
      _keep=()
      for _s in "${STEPS_RUN[@]}"; do
        _drop=0
        for _d in "${_skip[@]}"; do [[ "$_s" == "$_d" ]] && _drop=1; done
        ((_drop)) || _keep+=("$_s")
      done
      STEPS_RUN=("${_keep[@]}")
      ;;
    --gpu=*) GPU_OVERRIDE="${1#*=}" ;;
    --nvidia-driver=*) NVIDIA_BRANCH_OVERRIDE="${1#*=}" ;;
    --theme=*) THEME_VARIANT="${1#*=}" ;;
    --wallpapers) WALLPAPERS=1 ;;
    --no-aur) USE_AUR=0 ;;
    --no-upgrade) SKIP_UPGRADE=1 ;;
    *)
      echo "unknown option: $1" >&2
      echo "try ./install.sh --help" >&2
      exit 2
      ;;
  esac
  shift
done

# ── Libraries and steps ────────────────────────────────────────────────────

for lib in ui detect pkg; do
  # shellcheck source=/dev/null
  source "$DOT_INSTALL/lib/$lib.sh"
done

for step in "$DOT_INSTALL"/steps/*.sh; do
  # shellcheck source=/dev/null
  source "$step"
done

# Is an optional package group turned on? Used by the package and service
# steps; `core` is not a group, it is the baseline.
group_enabled() {
  [[ ",$DOT_GROUPS," == *",$1,"* ]]
}

# ── Failure ────────────────────────────────────────────────────────────────
#
# A failed install should say where it stopped: the next run can then continue
# with --only= instead of starting from the beginning.
on_error() {
  local code=$?
  printf '\n'
  err "the '${CURRENT_STEP:-startup}' step failed (exit $code)"
  note "fix the cause and continue with:"
  note "  $SCRIPT_PATH --only=${CURRENT_STEP:-preflight}"
  exit "$code"
}
trap on_error ERR

# ── Run ────────────────────────────────────────────────────────────────────

main() {
  printf '\n%s%s  dotfiles installer%s  ·  %s\n' \
    "$C_BOLD" "$C_MAGENTA" "$C_RESET" "https://github.com/dev-fritz/.config"

  detect_all

  printf '\n'
  detect_report

  if ((DETECT_ONLY)); then
    printf '\n'
    note "detection only (--detect); nothing was changed"
    exit 0
  fi

  # An unrecognised branch would silently fall through to "no driver", so it is
  # rejected here rather than 200 packages later.
  if [[ -n "$NVIDIA_BRANCH_OVERRIDE" ]]; then
    case "$NVIDIA_BRANCH_OVERRIDE" in
      open | proprietary | 580xx | 470xx | nouveau | none) ;;
      *) die "unknown --nvidia-driver: $NVIDIA_BRANCH_OVERRIDE (see --help)" ;;
    esac
  fi

  printf '\n'
  info "groups: core,$DOT_GROUPS"
  info "steps:  ${STEPS_RUN[*]}"
  ((DRY_RUN)) && warn "dry run: nothing will be installed or written"

  printf '\n'
  ask "start?" y || die "cancelled"

  # Keep the sudo timestamp alive: an AUR build or a full -Syu can easily take
  # longer than the default five minutes, and a password prompt appearing in
  # the middle of an unattended run would just sit there forever.
  if ((DRY_RUN == 0)); then
    (while sudo -n true 2> /dev/null; do
      sleep 50
      kill -0 "$$" 2> /dev/null || exit
    done) &
    SUDO_KEEPALIVE=$!
    trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT
  fi

  local step
  for step in "${STEPS_RUN[@]}"; do
    CURRENT_STEP="$step"
    case "$step" in
      relocate) step_relocate ;;
      preflight) step_preflight ;;
      aur) step_aur ;;
      packages) step_packages ;;
      drivers) step_drivers ;;
      hardware) step_hardware ;;
      shell) step_shell ;;
      services) step_services ;;
      theme) step_theme ;;
      summary) step_summary ;;
      *) die "unknown step: $step (see --help)" ;;
    esac
  done
}

main "$@"
