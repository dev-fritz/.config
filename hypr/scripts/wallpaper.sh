#!/usr/bin/env bash
#
# Wallpaper picker, rendered with rofi, with thumbnails.
#
# Images are read from ~/Images/Pictures/<active-theme>/, so each theme has its
# own folder: picking "nord" shows only the images in ~/Images/Pictures/nord/.
# If that folder is missing or empty it falls back to ~/Images/Pictures/_geral/.
# To add images, just copy files into the folder — the whole directory is read,
# not a list. Download more with ~/.config/theme/baixar-wallpapers.py <theme>.
# Supported formats: jpg jpeg png webp gif bmp.
#
# Usage:
#   wallpaper.sh          open the picker (SUPER + SHIFT + W)
#   wallpaper.sh random   pick a random image
#   wallpaper.sh restore  reapply the last one (used at autostart)
#
# Thumbnails: rofi in dmenu mode takes one icon per line, written as
# `text\0icon\x1f/path/to/image`. rofi preserves the image aspect ratio, so a
# 16:9 wallpaper would render as a short, wide thumbnail. To get upright cards,
# 2:3 crops are pre-generated and cached in ~/.cache/wallpaper-thumbs/, and rofi
# receives the thumbnail path instead of the original. A thumbnail is only
# regenerated when its source image changes.
#
# Requires: awww (wallpaper daemon), rofi, ffmpeg (for the thumbnails)

set -euo pipefail

RAIZ="$HOME/Images/Pictures"
ESTADO="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"

# ── Which folder to use ─────────────────────────────────────────────────────
# The active theme is the one in ~/.config/theme/. Wallpapers are stored per
# theme, so switching back to a theme restores its wallpaper.
TEMA="$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/theme/current" 2>/dev/null || echo "")"
TEMA="${TEMA//[$'\t\r\n ']}"

PASTA="$RAIZ/$TEMA"
# No theme folder, or an empty one, falls back to the neutral folder.
if [[ -z "$TEMA" || ! -d "$PASTA" ]] || ! find "$PASTA" -maxdepth 1 -type f -print -quit | grep -q .; then
  PASTA="$RAIZ/_geral"
fi

# Each theme remembers its own wallpaper.
ESTADO_TEMA="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper-$TEMA"

avisar() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a "Wallpaper" "$@" || true
}

# ── Apply a wallpaper ───────────────────────────────────────────────────────
aplicar() {
  local img="$1"
  [[ -f "$img" ]] || { avisar -u critical "Image not found" "$img"; exit 1; }

  # awww is a fork of swww: `img` sets the wallpaper on every screen. The
  # transition avoids a hard flash when switching.
  awww img "$img" \
    --transition-type grow \
    --transition-pos 0.5,0.5 \
    --transition-duration 1 \
    --transition-fps 60 2>/dev/null \
    || awww img "$img"   # in case this version lacks the transition options

  mkdir -p "$(dirname "$ESTADO")"
  printf '%s\n' "$img" > "$ESTADO"
  printf '%s\n' "$img" > "$ESTADO_TEMA"
}

# ── Cached portrait thumbnails ──────────────────────────────────────────────
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"
LARGURA=400
ALTURA=600

# Returns the thumbnail path, generating it if missing or stale. Without
# ffmpeg it returns the original image, which renders wide but still works.
miniatura() {
  local origem="$1"
  command -v ffmpeg >/dev/null 2>&1 || { printf '%s' "$origem"; return; }

  mkdir -p "$CACHE"
  # The cache name includes a hash of the path so identically named images in
  # different folders don't overwrite each other.
  local chave
  chave="$(printf '%s' "$origem" | cksum | cut -d' ' -f1)"
  local destino="$CACHE/${chave}_$(basename "${origem%.*}").png"

  # Only regenerate when the source is newer than the cached thumbnail.
  if [[ ! -f "$destino" || "$origem" -nt "$destino" ]]; then
    # `crop` takes the largest centered 2:3 rectangle, `scale` normalizes the
    # size so every thumbnail matches.
    ffmpeg -loglevel error -y -i "$origem" \
      -vf "crop='min(iw,ih*2/3)':'min(ih,iw*3/2)',scale=${LARGURA}:${ALTURA}" \
      -frames:v 1 "$destino" 2>/dev/null || { printf '%s' "$origem"; return; }
  fi

  printf '%s' "$destino"
}

# ── Image list ──────────────────────────────────────────────────────────────
mapfile -t IMAGENS < <(
  find "$PASTA" -maxdepth 2 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
       -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) \
    2>/dev/null | sort
)

case "${1:-menu}" in
  # ── Reapply the last wallpaper (called at login) ─────────────────────────
  restore)
    # Order of preference: this theme's wallpaper, then the last global one,
    # then the first image in the folder.
    if [[ -r "$ESTADO_TEMA" ]] && [[ -f "$(< "$ESTADO_TEMA")" ]]; then
      aplicar "$(< "$ESTADO_TEMA")"
    elif [[ -r "$ESTADO" ]] && [[ -f "$(< "$ESTADO")" ]]; then
      aplicar "$(< "$ESTADO")"
    elif [[ ${#IMAGENS[@]} -gt 0 ]]; then
      aplicar "${IMAGENS[0]}"
    fi
    exit 0
    ;;

  # ── Random pick ──────────────────────────────────────────────────────────
  random)
    [[ ${#IMAGENS[@]} -eq 0 ]] && { avisar -u critical "No images in ${PASTA/#$HOME/\~}"; exit 1; }
    aplicar "${IMAGENS[RANDOM % ${#IMAGENS[@]}]}"
    exit 0
    ;;
esac

# ── Menu ────────────────────────────────────────────────────────────────────
if [[ ${#IMAGENS[@]} -eq 0 ]]; then
  avisar -u critical "No images for the theme $TEMA" \
    "Put images in ${PASTA/#$HOME/\~} or run: ~/.config/theme/baixar-wallpapers.py $TEMA"
  exit 1
fi

ATUAL="$( [[ -r "$ESTADO" ]] && basename "$(< "$ESTADO")" || echo "" )"

ESCOLHA="$(
  for img in "${IMAGENS[@]}"; do
    nome="$(basename "${img%.*}")"
    [[ "$(basename "$img")" == "$ATUAL" ]] && nome="● $nome"
    printf '%s\0icon\x1f%s\n' "$nome" "$(miniatura "$img")"
  done | rofi -dmenu \
    -p "󰸉" \
    -i \
    -show-icons \
    -theme gallery
)" || exit 0

[[ -z "$ESCOLHA" ]] && exit 0
ESCOLHA="${ESCOLHA#● }"

# Find the full path from the extension-less name.
for img in "${IMAGENS[@]}"; do
  if [[ "$(basename "${img%.*}")" == "$ESCOLHA" ]]; then
    aplicar "$img"
    avisar "Wallpaper" "$ESCOLHA"
    exit 0
  fi
done
