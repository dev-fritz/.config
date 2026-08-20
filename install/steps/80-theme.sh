#!/usr/bin/env bash
#
# Theme — generate the color files.
#
# This is the step nothing works without. Every config in the repository
# imports a file that theme/apply.py writes and that is deliberately not
# versioned: waybar/colors.css, rofi/colors.rasi, kitty/theme.conf,
# hypr/conf/colors.lua and the rest. A fresh clone has none of them, so
# Hyprland fails to parse and the bar has no colors until this runs.

step_theme() {
  section "Theme"

  local apply="$DOT_ROOT/theme/apply.py"
  [[ -x "$apply" ]] || {
    warn "$apply is missing or not executable — skipping"
    return 0
  }

  # With no argument apply.py reapplies the active variant, falling back to the
  # default (catppuccin-mocha) when theme/current does not exist yet — which is
  # exactly the fresh-clone case.
  local variant="${THEME_VARIANT:-}"
  if [[ -n "$variant" ]]; then
    info "applying the $variant variant"
    run "$apply" "$variant"
  else
    info "generating the color files for the default variant"
    run "$apply"
  fi

  ok "colors generated — switch variants later with SUPER + SHIFT + T"

  # ── Wallpapers ───────────────────────────────────────────────────────────
  #
  # The picker reads ~/Images/Pictures/<theme>/, one folder per variant, and
  # says so when a folder is empty. Downloading is optional: any image copied
  # into those folders works just as well.
  local pictures="$HOME/Images/Pictures"
  local count=0
  count="$(find "$pictures" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2> /dev/null | wc -l)"

  if ((count > 0)); then
    ok "$count wallpapers already in ${pictures/#$HOME/\~}"
    return 0
  fi

  if [[ "$WALLPAPERS" == "1" ]] || ask "download a set of wallpapers, one per variant? (~50 images from wallhaven)" n; then
    run "$DOT_ROOT/theme/baixar-wallpapers.py" || warn "the download failed — the desktop works, the background is just plain"
  else
    note "no wallpapers yet: put images in ~/Images/Pictures/<variant>/ or run"
    note "  ~/.config/theme/baixar-wallpapers.py"
  fi
  return 0
}
