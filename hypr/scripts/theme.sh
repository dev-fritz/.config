#!/usr/bin/env bash
#
# Catppuccin variant picker, rendered with rofi.
#
# Calls ~/.config/theme/apply.py, which regenerates the color files for every
# app and tells each one to reload.
#
# Usage:
#   theme.sh          open the picker (SUPER + SHIFT + T)
#   theme.sh <name>   apply a variant directly
#
# List available variants with `~/.config/theme/apply.py --list`.

set -euo pipefail

APPLY="$HOME/.config/theme/apply.py"

[[ -x "$APPLY" ]] || { echo "could not find $APPLY" >&2; exit 1; }

# ── Direct apply ────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  "$APPLY" "$1"
  exit $?
fi

ATUAL="$("$APPLY" --current)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/theme-previews"

# ── Preview cards ───────────────────────────────────────────────────────────
# The picker reuses the wallpaper "gallery" theme, which expects one image per
# entry. A variant has no photo, so a card is drawn from its palette: `base` as
# the background and the accent colors in a grid.
#
# Drawn with ffmpeg (`drawbox` paints rectangles), so ImageMagick isn't needed.
# Cards are cached and generated only once.
#
# Colors come from apply.py, which reads palettes.py — no hex is duplicated
# here. It returns "base red peach yellow green teal blue mauve pink".

gerar_cartao() {
  # Two separate lines on purpose: in `local a="$1" b="$a"` bash expands every
  # argument to `local` before running it, so `$a` would read the global
  # variable instead of the one just declared — an unbound variable under `set -u`.
  local v="$1"
  local destino="$CACHE/$v.png"
  [[ -f "$destino" ]] && { printf '%s' "$destino"; return; }
  command -v ffmpeg >/dev/null 2>&1 || { printf '%s' "$destino"; return; }

  mkdir -p "$CACHE"
  local cores
  read -r -a cores <<< "$("$APPLY" --palette "$v")"
  local base="${cores[0]}"

  # Build a chain of drawbox filters: 8 squares in a 2x4 grid.
  local filtro="" i=0 col linha x y
  local larg=140 alt=115 margem=30 gap=20
  for c in "${cores[@]:1}"; do
    col=$(( i % 2 )); linha=$(( i / 2 ))
    x=$(( margem + col * (larg + gap) ))
    y=$(( margem + linha * (alt + gap) ))
    [[ -n "$filtro" ]] && filtro+=","
    filtro+="drawbox=x=${x}:y=${y}:w=${larg}:h=${alt}:color=0x${c}:t=fill"
    i=$(( i + 1 ))
  done

  ffmpeg -loglevel error -y -f lavfi -i "color=c=0x${base}:s=400x600" \
    -vf "$filtro" -frames:v 1 "$destino" 2>/dev/null || true

  printf '%s' "$destino"
}

# ── Menu ────────────────────────────────────────────────────────────────────
# `--describe` returns one line per variant: "marker<TAB>name<TAB>description".
ESCOLHA="$(
  "$APPLY" --describe | while IFS=$'\t' read -r marca nome descricao; do
    rotulo="$nome"
    [[ "$marca" == "*" ]] && rotulo="● $nome"
    printf '%s\0icon\x1f%s\n' "$rotulo — $descricao" "$(gerar_cartao "$nome")"
  done | rofi -dmenu \
    -p "󰏘" \
    -i \
    -show-icons \
    -theme gallery
)" || exit 0

[[ -z "$ESCOLHA" ]] && exit 0

# Work out which variant was picked by looking for its name inside the line.
#
# `awk '{print $3}'` doesn't work here: for non-active variants the marker is a
# space, awk collapses the whitespace and the columns shift, so $3 becomes the
# description instead of the name. Matching by name avoids that.
VARIANTE=""
while IFS=$'\t' read -r _ nome _; do
  if [[ " $ESCOLHA " == *" $nome "* ]]; then
    VARIANTE="$nome"
    break
  fi
done < <("$APPLY" --describe)

if [[ -z "$VARIANTE" ]]; then
  echo "could not identify the variant in: $ESCOLHA" >&2
  exit 1
fi

SAIDA="$("$APPLY" "$VARIANTE" 2>&1)" || true
command -v notify-send >/dev/null 2>&1 \
  && notify-send -a "Theme" "$VARIANTE" "$SAIDA" || true
