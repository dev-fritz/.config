#!/usr/bin/env bash
#
# Package handling: reading the lists, deciding where each package comes from,
# and installing it.
#
# The lists under install/pkg/ carry names only — no repository is written down
# anywhere. Whether a package lives in the official repositories or in the AUR
# is asked to pacman at install time, so a package that moves between the two
# (it happens: `satty` and `yazi` both did) never turns into a stale comment
# nobody updates.

AUR_HELPER="${AUR_HELPER:-}"

# ── Reading the lists ──────────────────────────────────────────────────────

# One package per line. `#` starts a comment, blank lines are ignored, and an
# inline comment after the name is allowed.
pkg_list_read() {
  local file="$1"
  [[ -r "$file" ]] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]\+$//' -e '/^[[:space:]]*$/d' "$file"
}

# ── Queries ────────────────────────────────────────────────────────────────

pkg_installed() { pacman -Qq -- "$1" > /dev/null 2>&1; }

# In the official repositories, either as a package or as a group (base-devel).
pkg_in_repos() {
  pacman -Si -- "$1" > /dev/null 2>&1 && return 0
  [[ -n "$(pacman -Sg -- "$1" 2> /dev/null)" ]] && return 0
  return 1
}

# The sync database has to exist before any of the above means anything. On a
# machine that has never run `pacman -Sy`, every query would say "not in the
# repositories" and the installer would send the whole list to the AUR.
pkg_db_ready() { pacman -Si bash > /dev/null 2>&1; }

# ── Classification ─────────────────────────────────────────────────────────

# Splits a list of names into three arrays the caller can use:
#
#   PKGS_REPO     install with pacman
#   PKGS_AUR      install with the AUR helper
#   PKGS_PRESENT  already installed, nothing to do
#
# Packages that exist in neither place end up in PKGS_UNKNOWN, which the caller
# reports instead of failing the whole run: one renamed package should not stop
# a fresh install.
pkg_classify() {
  PKGS_REPO=()
  PKGS_AUR=()
  PKGS_PRESENT=()
  PKGS_UNKNOWN=()

  local p
  for p in "$@"; do
    [[ -n "$p" ]] || continue
    if pkg_installed "$p"; then
      PKGS_PRESENT+=("$p")
    elif pkg_in_repos "$p"; then
      PKGS_REPO+=("$p")
    elif [[ -n "$AUR_HELPER" ]]; then
      PKGS_AUR+=("$p")
    else
      PKGS_UNKNOWN+=("$p")
    fi
  done
}

# ── Installing ─────────────────────────────────────────────────────────────

pacman_flags() {
  local flags=(--needed)
  [[ "${ASSUME_YES:-0}" == "1" ]] && flags+=(--noconfirm)
  printf '%s\n' "${flags[@]}"
}

pkg_install_repo() {
  [[ $# -gt 0 ]] || return 0
  local flags=()
  mapfile -t flags < <(pacman_flags)
  sudo_run pacman -S "${flags[@]}" -- "$@"
}

pkg_install_aur() {
  [[ $# -gt 0 ]] || return 0
  [[ -n "$AUR_HELPER" ]] || {
    warn "no AUR helper: skipping $*"
    return 0
  }
  local flags=()
  mapfile -t flags < <(pacman_flags)
  # The helper is never run through sudo — it drops privileges itself and
  # refuses to build as root.
  run "$AUR_HELPER" -S "${flags[@]}" -- "$@"
}

# Installs a whole list at once: classifies, reports, then hands the two halves
# to pacman and the AUR helper. Doing it in two transactions instead of one per
# package is what keeps the run from taking an hour.
pkg_install() {
  local title="$1"
  shift
  [[ $# -gt 0 ]] || return 0

  pkg_classify "$@"

  local total=$(($# - ${#PKGS_PRESENT[@]}))
  if ((total == 0)); then
    ok "$title: already installed (${#PKGS_PRESENT[@]} packages)"
    return 0
  fi

  info "$title: ${#PKGS_REPO[@]} from the repositories, ${#PKGS_AUR[@]} from the AUR, ${#PKGS_PRESENT[@]} already there"
  ((${#PKGS_REPO[@]})) && note "pacman: ${PKGS_REPO[*]}"
  ((${#PKGS_AUR[@]})) && note "aur:    ${PKGS_AUR[*]}"
  ((${#PKGS_UNKNOWN[@]})) && warn "not found anywhere, skipped: ${PKGS_UNKNOWN[*]}"

  ((${#PKGS_REPO[@]})) && pkg_install_repo "${PKGS_REPO[@]}"
  ((${#PKGS_AUR[@]})) && pkg_install_aur "${PKGS_AUR[@]}"
  return 0
}

# ── AUR helper ─────────────────────────────────────────────────────────────

# Any of these is fine; paru is the one this setup was built with.
aur_helper_find() {
  local h
  for h in paru yay pikaur trizen; do
    if command -v "$h" > /dev/null 2>&1; then
      AUR_HELPER="$h"
      return 0
    fi
  done
  AUR_HELPER=""
  return 1
}

# Builds paru from the AUR by hand — the one package that cannot be installed
# by an AUR helper, since there is none yet. `paru-bin` is used instead of
# `paru` to skip a full Rust toolchain build on a fresh machine.
aur_helper_bootstrap() {
  local tmp
  tmp="$(mktemp -d)"

  info "building paru-bin (the only package installed without a helper)"
  run git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    note "$ cd $tmp/paru-bin && makepkg -si"
    AUR_HELPER="paru"
    return 0
  fi

  (
    cd "$tmp/paru-bin"
    local mk=(makepkg -si --needed)
    [[ "${ASSUME_YES:-0}" == "1" ]] && mk+=(--noconfirm)
    "${mk[@]}"
  )

  rm -rf "$tmp"
  aur_helper_find || die "paru-bin was built but paru is not on PATH"
  ok "AUR helper: $AUR_HELPER"
}
