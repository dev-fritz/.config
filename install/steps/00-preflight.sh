#!/usr/bin/env bash
#
# Preflight — everything that has to be true before the first package is
# installed. Each check fails loudly here rather than halfway through, when
# half the desktop is on disk.

step_preflight() {
  section "Preflight"

  # ── Who is running this ──────────────────────────────────────────────────
  #
  # Running the whole installer as root would leave ~/.config, ~/.cache and the
  # AUR build directory owned by root, and the AUR helper refuses to build as
  # root anyway. Individual commands call sudo when they need it.
  [[ ${EUID:-$(id -u)} -ne 0 ]] || die "run this as your normal user, not with sudo — the script calls sudo itself where needed"

  # ── Which distribution ───────────────────────────────────────────────────
  #
  # Every package name in install/pkg/ is an Arch name and every command below
  # is pacman. On anything else this would fail one command at a time; better
  # to say so now.
  if ! distro_is_arch; then
    err "this installer is written for Arch Linux and Arch-based distributions"
    note "detected: $DOT_DISTRO_NAME"
    note "the configuration files themselves are portable — only the package"
    note "installation is not. Install the equivalents by hand and run:"
    note "  ./install.sh --only=hardware,shell,theme"
    die "unsupported distribution"
  fi
  command -v pacman > /dev/null 2>&1 || die "pacman not found"
  ok "$DOT_DISTRO_NAME"

  # ── sudo ─────────────────────────────────────────────────────────────────
  command -v sudo > /dev/null 2>&1 || die "sudo not found — install it and add your user to /etc/sudoers"

  if [[ "$DRY_RUN" != "1" ]]; then
    info "asking for sudo once, up front"
    sudo -v || die "sudo failed"
  fi

  # ── Network ──────────────────────────────────────────────────────────────
  #
  # Bash's /dev/tcp does this without curl or ping, neither of which is
  # guaranteed on a fresh install (and ICMP is blocked on plenty of networks).
  if [[ "$DRY_RUN" != "1" ]]; then
    if ! timeout 5 bash -c 'exec 3<>/dev/tcp/archlinux.org/443' 2> /dev/null; then
      warn "cannot reach archlinux.org — connect to the network first"
      ask "continue anyway?" n || die "no network"
    else
      ok "network reachable"
    fi
  fi

  # ── Disk space ───────────────────────────────────────────────────────────
  #
  # A full run with every group is roughly 8 GB unpacked, plus whatever the AUR
  # builds need. 15 GB free is a comfortable floor.
  local free_gb
  free_gb="$(df -BG --output=avail / 2> /dev/null | tail -1 | tr -dc '0-9')"
  if [[ -n "$free_gb" ]] && ((free_gb < 15)); then
    warn "only ${free_gb}G free on / — a full run needs about 15G"
    ask "continue anyway?" n || die "not enough disk space"
  fi

  # ── Keyring and mirrors ──────────────────────────────────────────────────
  #
  # An out-of-date keyring is the single most common reason a fresh install
  # fails on the first `pacman -S`: signatures made after the ISO was built are
  # rejected. Syncing the keyring package first fixes it.
  if [[ "$SKIP_UPGRADE" == "1" ]]; then
    info "skipping the system upgrade (--no-upgrade)"
  elif ask "sync the package database and upgrade the system first? (recommended)" y; then
    sudo_run pacman -Sy --needed --noconfirm archlinux-keyring
    local flags=()
    mapfile -t flags < <(pacman_flags)
    sudo_run pacman -Syu "${flags[@]}"
  else
    # Installing into a database that was never synced gives "target not found"
    # for perfectly real packages, so at minimum -Sy has to run.
    sudo_run pacman -Sy
  fi

  pkg_db_ready || warn "the pacman database still looks empty — package lookups may be wrong"
  return 0
}
