#!/usr/bin/env bash
#
# AUR helper — wlogout, onlyoffice-bin and a couple of tools only exist in the
# AUR, so one helper has to be present before the package step runs.
#
# Skipped entirely with --no-aur, in which case those packages are reported as
# "not found anywhere" and everything else still installs.

step_aur() {
  section "AUR helper"

  if [[ "$USE_AUR" != "1" ]]; then
    info "--no-aur: AUR packages will be skipped"
    AUR_HELPER=""
    return 0
  fi

  if aur_helper_find; then
    ok "using $AUR_HELPER"
    return 0
  fi

  info "no AUR helper found"

  # base-devel is what makepkg needs to build anything at all, and git is what
  # fetches the PKGBUILD. Both are also in core.lst, but the helper is built
  # before the package step runs.
  local flags=()
  mapfile -t flags < <(pacman_flags)
  sudo_run pacman -S "${flags[@]}" base-devel git

  if ask "build paru from the AUR? (needed for wlogout, among others)" y; then
    aur_helper_bootstrap
  else
    warn "continuing without an AUR helper"
    AUR_HELPER=""
  fi
  return 0
}
