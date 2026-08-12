#!/usr/bin/env python3
"""
Applies a theme variant across the whole system.

    ~/.config/theme/apply.py            # reapply the current variant
    ~/.config/theme/apply.py latte      # switch to Latte
    ~/.config/theme/apply.py --list     # list the variants

The colors live only in palettes.py. This script generates one color file per
application and then tells each one to reload. No config has hex written in the
middle of it — they all point at the generated file:

    waybar/colors.css       (@import)
    swaync/colors.css       (@import)
    rofi/colors.rasi        (@import)
    kitty/theme.conf        (include)
    hypr/conf/colors.lua    (require)
    wlogout/colors.css      (@import)
    btop/themes/tema.theme  (color_theme = "tema")
    newt/palette            (NEWT_COLORS_FILE, set in hypr/conf/env.lua)
    hyprlock.conf           (between markers)
    ~/.local/share/themes/  (GTK3 theme)
    gtk-4.0/colors.css      (libadwaita)
    nvim theme.json         (state file)

Every generated file starts with a warning. Do not edit those files: they are
overwritten on the next theme switch. Edit palettes.py instead.

Reloading immediately: Waybar, swaync, Hyprland, kitty (SIGUSR1), Neovim (it
watches the state file) and GTK3 apps (via the gtk-theme-name change).
Only on next start: libadwaita apps (they flip light/dark right away but pick
up the colors on reopen), wlogout, hyprlock and btop.

Firefox follows the system light/dark setting as long as its own theme is set to
"System theme — auto" (about:addons -> Themes). Pinned to Dark or Light, it
ignores everything else.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from palettes import (  # noqa: E402
    DESCRICAO,
    DEFAULT,
    IS_DARK,
    NVIM_COLORSCHEME,
    get,
    variants,
)

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
STATE = CONFIG / "theme" / "current"

AVISO = "GENERATED FILE from ~/.config/theme/apply.py — do not edit by hand."

#: Prefix of the generated GTK theme. The full name (prefix + variant) is what
#: goes into `gtk-theme-name`, and it is that name CHANGING which makes every
#: open GTK3 app reread the theme from disk. Hence one name per variant.
TEMA_GTK = "Tema-"


# ── Helpers ────────────────────────────────────────────────────────────────

def escrever(caminho: Path, conteudo: str) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    caminho.write_text(conteudo, encoding="utf-8")


def escurecer(hexa: str, fator: float) -> str:
    """Multiplies the RGB channels by `fator`; 0.45 is much darker."""
    r, g, b = (int(hexa[i:i + 2], 16) for i in (0, 2, 4))
    return "".join(f"{min(255, max(0, round(c * fator))):02x}" for c in (r, g, b))


def contraste(a: str, b: str) -> float:
    """
    Contrast ratio between two hex colors, from 1 (identical) to 21 (black on
    white), by the WCAG formula. 4.5 is the threshold for body text.

    Used where a pairing has to hold across all the variants: an accent that
    reads well over the panel in one palette can be nearly the panel's own tone
    in the next, and only the numbers catch that.
    """
    def relativa(hexa: str) -> float:
        canais = []
        for i in (0, 2, 4):
            v = int(hexa[i:i + 2], 16) / 255
            canais.append(v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4)
        r, g, b = canais
        return 0.2126 * r + 0.7152 * g + 0.0722 * b

    claro, escuro = sorted((relativa(a), relativa(b)), reverse=True)
    return (claro + 0.05) / (escuro + 0.05)


def cores_ansi(p: dict[str, str], variante: str) -> dict[str, str]:
    """
    The sixteen terminal colors, under the names the terminal itself, slang and
    newt all use for them.

    The two ends of the ramp — `black` and `lightgray`/`white` — are not
    decoration. Full-screen TUIs paint entire panels with them, black as the
    background and white as the text, so black has to be the palette's dark end
    and white its light end. Putting both on the same side, as happens if
    `black` is picked to be visible over a dark terminal, leaves those programs
    drawing text on a background of the same tone.

    The roles swap between light and dark because the `surface*` ramp runs the
    other way in a light palette: there `surface2` is the light grey and
    `subtext1` the dark ink.
    """
    if IS_DARK[variante]:
        preto, cinza = p["surface1"], p["surface2"]
        claro, branco = p["subtext1"], p["text"]
    else:
        preto, cinza = p["subtext1"], p["subtext0"]
        claro, branco = p["surface2"], p["surface1"]
    return {
        "black": preto, "gray": cinza,
        "lightgray": claro, "white": branco,
        "red": p["red"], "brightred": p["red"],
        "green": p["green"], "brightgreen": p["green"],
        "brown": p["yellow"], "yellow": p["yellow"],
        "blue": p["blue"], "brightblue": p["blue"],
        "magenta": p["pink"], "brightmagenta": p["pink"],
        "cyan": p["teal"], "brightcyan": p["teal"],
    }


def cor_sombra(p: dict[str, str], variante: str) -> str:
    """
    The theme's shadow color.

    In dark themes `crust` is already the palette's near-black and works as is.
    In light themes it is a LIGHT grey, and using it as a shadow produced a
    whitish halo around the Waybar islands instead of a shadow. So a heavily
    darkened version of `base` is derived instead, `base` being the color the
    shadow falls onto.
    """
    return p["crust"] if IS_DARK[variante] else escurecer(p["base"], 0.45)


def rodar(*cmd: str) -> bool:
    """Runs a command, swallowing its output. False if it fails or is missing."""
    try:
        return subprocess.run(cmd, capture_output=True, timeout=10).returncode == 0
    except (FileNotFoundError, subprocess.SubprocessError):
        return False


def entre_marcas(texto: str, marca: str, novo: str) -> str:
    """Replaces the block between `# >>> marker` and `# <<< marker`."""
    padrao = re.compile(
        rf"(#\s*>>>\s*{re.escape(marca)}\b.*?\n).*?(\n\s*#\s*<<<\s*{re.escape(marca)}\b)",
        re.DOTALL,
    )
    return padrao.sub(lambda m: m.group(1) + novo + m.group(2), texto)


# ── Generators, one per application ────────────────────────────────────────

def gerar_css(p: dict[str, str], variante: str) -> str:
    """
    GTK format: @define-color. Used by Waybar, swaync and wlogout.

    On top of the 26 roles from palettes.py it exports `shadow`, a derived color
    (see `cor_sombra`), so the CSS never has to know whether the theme is light
    or dark just to draw a shadow.
    """
    cores = dict(p, shadow=cor_sombra(p, variante))
    linhas = [f"/* {AVISO} */", ""]
    largura = max(len(n) for n in cores)
    for nome, hexa in cores.items():
        linhas.append(f"@define-color {nome:<{largura}} #{hexa};")
    return "\n".join(linhas) + "\n"


def gerar_rasi(p: dict[str, str]) -> str:
    """rofi format."""
    linhas = [f"/* {AVISO} */", "", "* {"]
    largura = max(len(n) for n in p)
    for nome, hexa in p.items():
        linhas.append(f"    {nome+':':<{largura+1}} #{hexa}ff;")
    linhas.append("}")
    return "\n".join(linhas) + "\n"


def gerar_lua(p: dict[str, str], variante: str) -> str:
    """Hyprland format: rgba(RRGGBBAA)."""
    linhas = [
        f"-- {AVISO}",
        "--",
        "-- Used by conf/look.lua. Hyprland wants rgba(RRGGBBAA), where the",
        "-- last two digits are the opacity (ff is opaque).",
        "",
        "return {",
        f'  variant = "{variante}",',
        f"  is_dark = {str(IS_DARK[variante]).lower()},",
    ]
    for nome, hexa in p.items():
        linhas.append(f'  {nome} = "rgba({hexa}ff)",')
    linhas.append("}")
    return "\n".join(linhas) + "\n"


def gerar_kitty(p: dict[str, str], variante: str) -> str:
    """The 16 terminal colors plus kitty's interface colors."""
    # The sixteen slots come from `cores_ansi`, shared with the newt palette so
    # that both agree on which end of the ramp `black` is.
    a = cores_ansi(p, variante)
    return f"""# {AVISO}
# Variant: {variante}

# ── Basics ───────────────────────────────────────────────────────────────
foreground              #{p['text']}
background              #{p['base']}
selection_foreground    #{p['base']}
selection_background    #{p['rosewater']}

# ── Cursor ───────────────────────────────────────────────────────────────
cursor                  #{p['rosewater']}
cursor_text_color       #{p['base']}

# ── Links ────────────────────────────────────────────────────────────────
url_color               #{p['lavender']}

# ── Window borders ───────────────────────────────────────────────────────
active_border_color     #{p['mauve']}
inactive_border_color   #{p['overlay0']}
bell_border_color       #{p['maroon']}

wayland_titlebar_color system
macos_titlebar_color system

# ── Tabs ─────────────────────────────────────────────────────────────────
active_tab_foreground   #{p['crust']}
active_tab_background   #{p['mauve']}
inactive_tab_foreground #{p['text']}
inactive_tab_background #{p['mantle']}
tab_bar_background      #{p['crust']}

# ── Marks ────────────────────────────────────────────────────────────────
mark1_foreground #{p['base']}
mark1_background #{p['blue']}
mark2_foreground #{p['base']}
mark2_background #{p['mauve']}
mark3_foreground #{p['base']}
mark3_background #{p['sapphire']}

# ── The 16 terminal colors ───────────────────────────────────────────────
# black
color0 #{a['black']}
color8 #{a['gray']}
# red
color1 #{a['red']}
color9 #{a['brightred']}
# green
color2  #{a['green']}
color10 #{a['brightgreen']}
# yellow
color3  #{a['brown']}
color11 #{a['yellow']}
# blue
color4  #{a['blue']}
color12 #{a['brightblue']}
# magenta
color5  #{a['magenta']}
color13 #{a['brightmagenta']}
# cyan
color6  #{a['cyan']}
color14 #{a['brightcyan']}
# white
color7  #{a['lightgray']}
color15 #{a['white']}
"""


def gerar_newt(p: dict[str, str], variante: str) -> str:
    """
    Palette for newt, the toolkit that draws nmtui, whiptail and friends.

    This is the one generator that writes no hex. newt understands sixteen
    color NAMES and nothing else, each one a slot in the terminal's palette —
    so what actually colors nmtui is `gerar_kitty`, and what is decided here is
    only which slot each part of the interface takes.

    Without this file newt falls back to its built-in palette, which paints the
    dialogs `black` on `lightgray`. That was written for the grey-on-blue
    terminal of 1996; on a themed terminal those two slots are just the ends of
    one ramp, and the text lands on a background of its own tone.

    Two things are decided by measurement rather than by taste:

    * which accent to use, since a palette's blue can be a light pastel in one
      variant and nearly the panel's own tone in the next (`ACENTOS`);
    * whether a label over that accent should be the panel color or the text
      color, which depends on whether the accent came out light or dark.

    Bright colors are deliberately absent from the right-hand side of every
    pair. newt draws through slang, which turns a bright BACKGROUND into
    blinking text on the Linux console — the one place where reaching nmtui is
    likely to be the only way back onto the network.
    """
    a = cores_ansi(p, variante)
    escuro = IS_DARK[variante]
    fundo = "black" if escuro else "lightgray"   # panel, the darker/lighter end
    texto = "lightgray" if escuro else "black"   # normal text, the other end
    forte = "white" if escuro else "black"       # emphasized text
    fraco = "gray"                               # disabled, fades into the panel

    # Preference order, first one that stands out over the panel wins. The
    # colors themselves are whatever the variant put in those slots.
    ACENTOS = ("blue", "cyan", "magenta")
    LEGIVEL = 4.5

    def acento(*evitar: str) -> str:
        pontos = [(contraste(a[nome], a[fundo]), nome)
                  for nome in ACENTOS if nome not in evitar]
        for pontuacao, nome in pontos:
            if pontuacao >= LEGIVEL:
                return nome
        return max(pontos)[1]   # nothing clears the bar: take the best there is

    principal = acento()             # frame, selected row, buttons
    foco = acento(principal)         # what the keyboard is on right now

    def sobre(nome: str) -> str:
        """Panel or text color over `nome`, whichever pulls further away."""
        return fundo if contraste(a[nome], a[fundo]) >= contraste(a[nome], a[texto]) else texto

    pares = {
        # The screen behind the dialogs.
        "root":          (texto, fundo),
        "roottext":      (texto, fundo),
        "helpline":      (texto, fundo),

        # The dialog frame.
        "window":        (texto, fundo),
        "border":        (principal, fundo),
        "title":         (foco, fundo),
        "shadow":        (fundo, fundo),

        # Static text.
        "label":         (texto, fundo),
        "textbox":       (texto, fundo),
        "acttextbox":    (forte, fundo),

        # Buttons: the accent behind, and in front of it whichever side reads
        # better over it.
        "button":        (sobre(principal), principal),
        "actbutton":     (sobre(foco), foco),
        "compactbutton": (texto, fundo),

        # Editable fields: brighter than the text around them, so it is clear
        # where typing lands.
        "entry":         (forte, fundo),
        "disentry":      (fraco, fundo),

        "checkbox":      (texto, fundo),
        "actcheckbox":   (sobre(foco), foco),

        # Lists. `actlistbox` and `actsellistbox` are the same row in two
        # states that newt tells apart and the eye should not, so both take the
        # accent and the highlight keeps its color from one screen to the next.
        "listbox":       (texto, fundo),
        "actlistbox":    (sobre(principal), principal),
        "sellistbox":    (principal, fundo),
        "actsellistbox": (sobre(principal), principal),

        # Progress bars, which only use the background side.
        "emptyscale":    ("", fundo),
        "fullscale":     ("", principal),
    }

    # No comment header: newt's parser reads the file line by line as
    # `key=fg,bg` and a stray line risks going through as a key.
    return "\n".join(f"{chave}={frente},{tras}"
                     for chave, (frente, tras) in pares.items()) + "\n"


def gerar_cores_gtk(p: dict[str, str], variante: str, cabecalho: bool = True) -> str:
    """
    The color names GTK and libadwaita know, filled in with the current palette.

    Used in two places: inside the generated GTK3 theme (see `gerar_tema_gtk3`),
    and in ~/.config/gtk-4.0/colors.css, which is the only recoloring hook
    libadwaita respects — it ignores `gtk-theme-name` on purpose.

    Mind the difference between the two GTK generations:

        libadwaita (GTK4)  its stylesheet is written in terms of these names, so
                           redefining them here repaints the whole theme.

        Adwaita (GTK3)     is compiled from SASS and has literal hex inside the
                           rule bodies. Redefining the names repaints nothing on
                           its own — they only apply to CSS we write ourselves.
                           That is why the generated GTK3 theme has to rewrite
                           rule by rule (headerbar, button, entry) instead of
                           just declaring colors.

    `cabecalho=False` returns only the color block, without the warning header;
    that is how the GTK3 theme embeds these definitions inside its own file.
    """
    escuro = IS_DARK[variante]
    aviso = f"/* {AVISO} */\n\n" if cabecalho else ""
    return f"""{aviso}@define-color theme_bg_color            #{p['base']};
@define-color theme_fg_color            #{p['text']};
@define-color theme_base_color          #{p['mantle']};
@define-color theme_text_color          #{p['text']};

@define-color theme_selected_bg_color   #{p['lavender']};
@define-color theme_selected_fg_color   #{p['crust']};

@define-color insensitive_bg_color      #{p['surface0']};
@define-color insensitive_fg_color      #{p['overlay0']};
@define-color insensitive_base_color    #{p['base']};

@define-color theme_unfocused_bg_color      #{p['base']};
@define-color theme_unfocused_fg_color      #{p['subtext1']};
@define-color theme_unfocused_base_color    #{p['mantle']};
@define-color theme_unfocused_text_color    #{p['text']};
@define-color theme_unfocused_selected_bg_color #{p['lavender']};
@define-color theme_unfocused_selected_fg_color #{p['crust']};

@define-color borders                   #{p['surface1']};
@define-color unfocused_borders         #{p['surface0']};

@define-color warning_color             #{p['yellow']};
@define-color error_color               #{p['red']};
@define-color success_color             #{p['green']};

@define-color content_view_bg           #{p['base']};
@define-color text_view_bg              #{p['mantle']};

/* GTK4 / libadwaita names */
@define-color window_bg_color           #{p['base']};
@define-color window_fg_color           #{p['text']};
@define-color view_bg_color             #{p['mantle']};
@define-color view_fg_color             #{p['text']};
@define-color headerbar_bg_color        #{p['mantle']};
@define-color headerbar_fg_color        #{p['text']};
@define-color popover_bg_color          #{p['surface0']};
@define-color popover_fg_color          #{p['text']};
@define-color card_bg_color             #{p['surface0']};
@define-color card_fg_color             #{p['text']};
@define-color accent_bg_color           #{p['lavender']};
@define-color accent_fg_color           #{p['crust']};
@define-color accent_color              #{p['lavender']};
@define-color destructive_bg_color      #{p['red']};
@define-color destructive_fg_color      #{p['crust']};

/* Used by the settings.ini generated alongside this file. */
/* variant: {variante} · dark: {str(escuro).lower()} */
"""


def gerar_tema_gtk3(p: dict[str, str], variante: str) -> str:
    """
    The actual GTK3 theme: ~/.local/share/themes/Tema-<variant>/gtk-3.0/gtk.css

    Why a theme instead of ~/.config/gtk-3.0/gtk.css:

        reloading   GTK3 reads the user stylesheet once, when the app opens. A
                    NAMED theme is reread whenever `gtk-theme-name` changes, and
                    since each variant has its own name, switching themes
                    repaints every open GTK3 app immediately.

        priority    The user stylesheet loads at priority 800, above the
                    application's own CSS (600), so a generic rule written there
                    leaks into any GTK3 app and beats it. That is how a
                    `box.horizontal { background-color: … }` written for swappy
                    ended up painting all of Waybar opaque and hiding the
                    workspace number. A theme loads at priority 200 and never
                    reaches the app's CSS.

    How it is assembled: start from light or dark Adwaita (the `@import` pulls
    the CSS from inside libgtk itself, with no installed file required) and
    rewrite the rules we want in the palette's colors.

    Rewriting rule by rule is required, not laziness: GTK3's Adwaita is compiled
    from SASS and has literal hex in the rule bodies. Declaring
    `@define-color theme_bg_color` alone repaints nothing — the names only apply
    to the CSS below them.

    Golden rule when editing this: no bare, generic widget selectors (`box`,
    `label`, `image`). This CSS enters EVERY GTK3 app, including Waybar, swaync
    and wlogout, which depend on transparent containers. Prefer the specific
    widget (`headerbar`, `entry`, `spinbutton`, `colorswatch`).
    """
    base_adwaita = "gtk-contained-dark.css" if IS_DARK[variante] else "gtk-contained.css"
    return f"""/* {AVISO}
 *
 * GTK3 theme for the "{variante}" variant.
 * Generated from ~/.config/theme/palettes.py.
 */

@import url("resource:///org/gtk/libgtk/theme/Adwaita/{base_adwaita}");

{gerar_cores_gtk(p, variante, cabecalho=False)}
/* ── Main surfaces ───────────────────────────────────────────────────────── */
window,
dialog,
.background {{
  background-color: @theme_bg_color;
  color: @theme_fg_color;
}}

window,
dialog {{
  /* Matches Hyprland's `rounding = 10`. */
  border-radius: 10px;
}}

headerbar {{
  background-color: @headerbar_bg_color;
  color: @headerbar_fg_color;
  border-bottom: 1px solid @borders;
}}

/* ── Controls ────────────────────────────────────────────────────────────── */
button {{
  border-radius: 8px;
  background-image: none;
  background-color: @card_bg_color;
  color: @theme_fg_color;
  border: 1px solid @borders;
}}

button:hover {{
  background-color: shade(@card_bg_color, 1.12);
}}

button:checked,
button:active {{
  background-color: @accent_bg_color;
  color: @accent_fg_color;
  border-color: @accent_bg_color;
}}

button:disabled {{
  background-color: @insensitive_bg_color;
  color: @insensitive_fg_color;
}}

entry,
spinbutton {{
  border-radius: 8px;
  background-image: none;
  background-color: @view_bg_color;
  color: @view_fg_color;
  border: 1px solid @borders;
}}

entry:focus,
spinbutton:focus {{
  border-color: @accent_bg_color;
}}

spinbutton button {{
  background-color: transparent;
  border: none;
}}

/* ── Menus, popovers and tooltips ────────────────────────────────────────── */
popover,
popover > contents,
menu,
.menu {{
  border-radius: 10px;
  background-color: @popover_bg_color;
  color: @popover_fg_color;
  border: 1px solid @borders;
}}

menuitem:hover,
.menu menuitem:hover {{
  background-color: @accent_bg_color;
  color: @accent_fg_color;
}}

tooltip,
tooltip.background {{
  border-radius: 8px;
  background-color: @theme_base_color;
  color: @theme_text_color;
  border: 1px solid @borders;
}}

/* ── Lists and scrollbars ────────────────────────────────────────────────── */
treeview.view,
list,
textview text {{
  background-color: @theme_base_color;
  color: @theme_text_color;
}}

:selected,
treeview.view:selected,
list row:selected {{
  background-color: @theme_selected_bg_color;
  color: @theme_selected_fg_color;
}}

scrollbar {{
  background-color: @theme_bg_color;
}}

scrollbar slider {{
  border-radius: 8px;
  background-color: @borders;
}}

scrollbar slider:hover {{
  background-color: @accent_bg_color;
}}

/* ── Scales (sliders) ────────────────────────────────────────────────────── */
scale trough {{
  background-color: @card_bg_color;
  border-radius: 8px;
}}

scale highlight {{
  background-color: @accent_bg_color;
  border-radius: 8px;
}}

scale slider {{
  background-color: @theme_fg_color;
  border: 1px solid @borders;
}}

/* ── swappy, the screenshot editor ───────────────────────────────────────── */
/* The color swatches in its toolbar: no heavy border, just a subtle outline.
   swappy's side panel is deliberately NOT styled here: it is a plain GtkBox,
   and styling `box` would hit the containers of every GTK3 bar on the system.
   It already inherits the window background.

   To inspect the widgets of any GTK app:
       GTK_DEBUG=interactive swappy -f image.png */
colorswatch,
button.color {{
  border-radius: 6px;
  border: 1px solid @borders;
}}
"""


def gerar_index_theme(variante: str) -> str:
    """
    index.theme, the theme's name badge.

    Without it the theme still works, but it doesn't show up in nwg-look or
    lxappearance, which scan ~/.local/share/themes/ looking for this file.
    """
    escuro = IS_DARK[variante]
    return f"""# {AVISO}
[Desktop Entry]
Type=X-GNOME-Metatheme
Name={TEMA_GTK}{variante}
Comment=Generated by ~/.config/theme/apply.py ({'dark' if escuro else 'light'})
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme={TEMA_GTK}{variante}
IconTheme=Adwaita
CursorTheme=Adwaita
ButtonLayout=:minimize,maximize,close
"""


def gerar_gtk_settings(variante: str) -> str:
    """
    settings.ini, the fallback path.

    What actually drives already-open apps is gsettings (see `aplicar`); this
    file is for anything that doesn't speak gsettings and has no portal running.
    Keeping it in sync avoids the classic "it opened with the old theme".
    """
    escuro = "1" if IS_DARK[variante] else "0"
    return f"""# {AVISO}
[Settings]
gtk-theme-name={TEMA_GTK}{variante}
gtk-icon-theme-name=Adwaita
gtk-font-name=SpaceMono Nerd Font 11
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme={escuro}
gtk-enable-animations=true
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
"""


def gerar_satty(p: dict[str, str]) -> str:
    """
    satty's palette (the screenshot editor). TOML format, colors as RRGGBBAA.

    `palette` is the row of color buttons in the toolbar; `custom` holds the
    extra options inside the color picker.
    """
    barra = ["red", "peach", "yellow", "green", "blue", "mauve", "text"]
    extra = ["rosewater", "pink", "teal", "sky", "lavender", "crust"]
    linhas = ["[color-palette]", "palette = ["]
    linhas += [f'    "#{p[c]}ff",' for c in barra]
    linhas += ["]", "custom = ["]
    linhas += [f'    "#{p[c]}ff",' for c in extra]
    linhas += ["]"]
    return "\n".join(linhas)


def gerar_hyprlock(p: dict[str, str]) -> str:
    """The hyprlock variable block, in `$name = rgba(...)` format."""
    nomes = ["base", "crust", "surface0", "text", "subtext0",
             "lavender", "mauve", "red", "green"]
    return "\n".join(f"${n:<9}= rgba({p[n]}ff)" for n in nomes)


def gerar_btop(p: dict[str, str], variante: str) -> str:
    """
    btop's theme. Its own format: `theme[key]="#hex"`, one per line.

    Unlike the other generators this one has to invent gradients. btop draws
    every graph and meter as a three-stop ramp (start -> mid -> end), and it
    reads meaning into the direction: a ramp that ends in red says "this is
    filling up". So the ramps are built from palette ROLES that carry the same
    meaning in any variant — green to red for load, blue to purple for network
    — rather than from literal colors.

    The file is always written as `tema.theme`, one fixed name overwritten on
    every switch, so btop.conf never has to be rewritten to point somewhere new.

    btop reads the theme once at startup: an open instance keeps the old colors
    until you quit and reopen it.
    """
    escuro = IS_DARK[variante]

    # In light themes `surface0` is a light grey that disappears against the
    # background; `overlay0` keeps the box borders visible.
    linha = p["surface1"] if escuro else p["overlay0"]

    cores = {
        # ── Base ─────────────────────────────────────────────────────────
        "main_bg": p["base"],
        "main_fg": p["text"],
        "title": p["text"],
        "hi_fg": p["mauve"],          # the highlighted letter of each shortcut
        "selected_bg": p["surface1"],
        "selected_fg": p["text"],
        "inactive_fg": p["overlay0"],
        "graph_text": p["subtext0"],
        "meter_bg": p["surface0"],
        "proc_misc": p["teal"],

        # ── Box borders ──────────────────────────────────────────────────
        "cpu_box": linha,
        "mem_box": linha,
        "net_box": linha,
        "proc_box": linha,
        "div_line": linha,

        # ── Temperature: calm -> hot ─────────────────────────────────────
        "temp_start": p["green"],
        "temp_mid": p["yellow"],
        "temp_end": p["red"],

        # ── CPU load: same reading as temperature ────────────────────────
        "cpu_start": p["teal"],
        "cpu_mid": p["yellow"],
        "cpu_end": p["red"],

        # ── Memory: each slice keeps its own hue ─────────────────────────
        # free and available go up when things are healthy, so they stay on
        # the cool side; `used` is the one that has to draw the eye.
        "free_start": p["green"],
        "free_mid": p["green"],
        "free_end": p["teal"],
        "cached_start": p["sapphire"],
        "cached_mid": p["sapphire"],
        "cached_end": p["blue"],
        "available_start": p["sky"],
        "available_mid": p["sky"],
        "available_end": p["teal"],
        "used_start": p["peach"],
        "used_mid": p["maroon"],
        "used_end": p["red"],

        # ── Network ──────────────────────────────────────────────────────
        "download_start": p["blue"],
        "download_mid": p["lavender"],
        "download_end": p["mauve"],
        "upload_start": p["pink"],
        "upload_mid": p["flamingo"],
        "upload_end": p["peach"],

        # ── Process list ─────────────────────────────────────────────────
        "process_start": p["teal"],
        "process_mid": p["blue"],
        "process_end": p["mauve"],

        # ── Process detail bars (btop 1.3+) ──────────────────────────────
        "proc_banner_bg": p["surface0"],
        "proc_banner_fg": p["text"],
        "proc_follow_bg": p["surface1"],
        "proc_pause_bg": p["surface2"],
        "followed_bg": p["surface1"],
        "followed_fg": p["yellow"],
    }

    # No padding around the `=`: btop's parser expects `theme[key]="#hex"`
    # exactly, and silently ignores any line it doesn't recognize — a
    # misalignment here would show up as a half-themed screen, not as an error.
    linhas = [f"# {AVISO}", f"# Variant: {variante}", ""]
    for nome, hexa in cores.items():
        linhas.append(f'theme[{nome}]="#{hexa}"')
    return "\n".join(linhas) + "\n"


# ── Applying ───────────────────────────────────────────────────────────────

def aplicar(variante: str) -> list[str]:
    p = get(variante)
    feitos: list[str] = []

    # ── Generated files ───────────────────────────────────────────────────
    css = gerar_css(p, variante)
    escrever(CONFIG / "waybar" / "colors.css", css); feitos.append("waybar")
    escrever(CONFIG / "swaync" / "colors.css", css); feitos.append("swaync")
    escrever(CONFIG / "wlogout" / "colors.css", css); feitos.append("wlogout")
    escrever(CONFIG / "rofi" / "colors.rasi", gerar_rasi(p)); feitos.append("rofi")
    escrever(CONFIG / "kitty" / "theme.conf", gerar_kitty(p, variante)); feitos.append("kitty")
    escrever(CONFIG / "hypr" / "conf" / "colors.lua", gerar_lua(p, variante)); feitos.append("hyprland")
    escrever(CONFIG / "btop" / "themes" / "tema.theme", gerar_btop(p, variante)); feitos.append("btop")
    escrever(CONFIG / "newt" / "palette", gerar_newt(p, variante)); feitos.append("newt")

    # ── GTK ───────────────────────────────────────────────────────────────
    # One theme per variant, in ~/.local/share/themes/. It is the theme NAME
    # changing that makes every open GTK3 app reread from disk; see
    # `gerar_tema_gtk3`.
    tema = DATA / "themes" / f"{TEMA_GTK}{variante}"
    escrever(tema / "gtk-3.0" / "gtk.css", gerar_tema_gtk3(p, variante))
    escrever(tema / "index.theme", gerar_index_theme(variante))

    # libadwaita ignores `gtk-theme-name` on purpose: for it, the only
    # recoloring hook is ~/.config/gtk-4.0/.
    escrever(CONFIG / "gtk-4.0" / "colors.css", gerar_cores_gtk(p, variante))

    for versao in ("gtk-3.0", "gtk-4.0"):
        escrever(CONFIG / versao / "settings.ini", gerar_gtk_settings(variante))

    # Leftover from the older layout, when the GTK3 colors lived in the user
    # stylesheet. If it stays behind it loads at USER priority and overrides the
    # new theme with the old theme's colors.
    (CONFIG / "gtk-3.0" / "colors.css").unlink(missing_ok=True)

    feitos.append("gtk")

    # ── satty: TOML has no import, so the block between markers is swapped ─
    satty = CONFIG / "satty" / "config.toml"
    if satty.exists():
        texto = satty.read_text(encoding="utf-8")
        novo = entre_marcas(texto, "CORES", gerar_satty(p))
        if novo != texto:
            satty.write_text(novo, encoding="utf-8")
        feitos.append("satty")

    # ── hyprlock: no import either, same marker swap ──────────────────────
    lock = CONFIG / "hypr" / "hyprlock.conf"
    if lock.exists():
        texto = lock.read_text(encoding="utf-8")
        novo = entre_marcas(texto, "CORES", gerar_hyprlock(p))
        if novo != texto:
            lock.write_text(novo, encoding="utf-8")
            feitos.append("hyprlock")

    # ── Neovim ────────────────────────────────────────────────────────────
    # Only the state file is written; Neovim itself reacts, since it watches
    # this path (see ~/.config/nvim/lua/config/theme.lua). An open instance
    # recolors on its own, with no :Theme and no restart.
    #
    # `mkdir` rather than `if parent.exists()`: previously, applying a theme
    # before the very first `nvim` run simply wrote nothing, and the editor
    # opened with the wrong theme for no visible reason.
    estado_nvim = Path.home() / ".local" / "state" / "nvim" / "theme.json"
    escrever(
        estado_nvim,
        json.dumps({
            "colorscheme": NVIM_COLORSCHEME[variante],
            "background": "dark" if IS_DARK[variante] else "light",
        }),
    )
    feitos.append("neovim")

    # ── Remember the choice ───────────────────────────────────────────────
    escrever(STATE, variante + "\n")

    # ── Reload whatever can be reloaded ───────────────────────────────────
    rodar("killall", "-SIGUSR2", "waybar")      # Waybar rereads the CSS
    rodar("swaync-client", "-rs")                # swaync rereads the CSS
    rodar("hyprctl", "reload")                   # Hyprland rereads everything
    rodar("killall", "-SIGUSR1", "kitty")        # kitty rereads its config

    # ── GTK and apps that follow the system ───────────────────────────────
    #
    # `gtk-theme` is the trigger: every open GTK3 app listens to this key and,
    # when the NAME changes, rereads the theme from disk. Since each variant
    # generates a theme with its own name, switching variants repaints swappy,
    # nwg-look, blueman and friends immediately.
    #
    # Note that reapplying the SAME variant repaints nothing, because the name
    # did not change and GTK caches themes by name. After editing palettes.py,
    # reopen the app to see the effect.
    #
    # `color-scheme` is the other half: it drives libadwaita's light/dark and
    # what xdg-desktop-portal announces as `org.freedesktop.appearance`. That is
    # the key Firefox listens to.
    esquema = "prefer-dark" if IS_DARK[variante] else "prefer-light"
    iface = "org.gnome.desktop.interface"
    rodar("gsettings", "set", iface, "gtk-theme", f"{TEMA_GTK}{variante}")
    rodar("gsettings", "set", iface, "color-scheme", esquema)

    return feitos


def atual() -> str:
    try:
        return STATE.read_text(encoding="utf-8").strip() or DEFAULT
    except OSError:
        return DEFAULT


def main() -> None:
    args = sys.argv[1:]

    if args and args[0] in ("-l", "--list"):
        for v in variants():
            print(f"{'*' if v == atual() else ' '} {v}")
        return

    if args and args[0] in ("-c", "--current"):
        print(atual())
        return

    # Used by theme.sh to draw the preview cards without duplicating any hex:
    # it asks for the colors here.
    if args and args[0] == "--palette":
        alvo = args[1] if len(args) > 1 else atual()
        p = get(alvo)
        ordem = ["base", "red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink"]
        print(" ".join(p[c] for c in ordem))
        return

    if args and args[0] == "--describe":
        for v in variants():
            marca = "*" if v == atual() else " "
            print(f"{marca}\t{v}\t{DESCRICAO[v]}")
        return

    variante = args[0] if args else atual()
    if variante not in variants():
        print(f"Unknown variant: {variante}", file=sys.stderr)
        print("Available:", ", ".join(variants()), file=sys.stderr)
        sys.exit(1)

    feitos = aplicar(variante)
    print(f"Theme {variante} applied to: {', '.join(feitos)}")
    print("Already-open libadwaita apps only pick up the new colors on reopen.")


if __name__ == "__main__":
    main()
