#!/usr/bin/env python3
"""
Downloads wallpapers from wallhaven, one folder per theme.

    ~/.config/theme/baixar-wallpapers.py              # every theme
    ~/.config/theme/baixar-wallpapers.py nord         # a single theme
    ~/.config/theme/baixar-wallpapers.py --busca gojo # change the search term
    ~/.config/theme/baixar-wallpapers.py --n 8        # how many per theme

wallhaven can filter by DOMINANT COLOR, and each theme registers its own in
palettes.py (WALLHAVEN_COLOR), so Nord gets bluish images, Gruvbox orange ones,
Dracula purple ones, and so on. That is what makes the wallpaper match the
palette.

Filters that are always on:
    purity=100      SFW content only
    categories=010  the "anime" category only
    atleast         minimum resolution, to avoid downloading small images

Images are saved to ~/Images/Pictures/<theme>/. If the folder already holds
images, the existing ones are counted and only the difference is downloaded, so
running again never duplicates anything.

To add your own, just copy files into the theme folder: the picker
(SUPER+SHIFT+W) reads the whole directory, not a list.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from palettes import WALLHAVEN_COLOR, variants  # noqa: E402

API = "https://wallhaven.cc/api/v1/search"
DESTINO = Path.home() / "Images" / "Pictures"
TIMEOUT = 30

#: wallhaven only accepts colors from this fixed list. The ones in palettes.py
#: have to appear here; the script warns when one doesn't.
CORES_VALIDAS = {
    "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399",
    "333399", "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600",
    "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600",
    "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff",
    "424153",
}


def buscar(termo: str, cor: str | None, minimo: str, pagina: int = 1) -> list[dict]:
    """Queries the API. Returns the list of results, which may be empty."""
    campos = {
        "q": termo,
        "purity": "100",      # SFW only
        "categories": "010",  # anime only
        "atleast": minimo,
        "sorting": "relevance",
        "page": str(pagina),
    }
    if cor:
        campos["colors"] = cor
    params = urllib.parse.urlencode(campos)
    req = urllib.request.Request(f"{API}?{params}", headers={"User-Agent": "curl/8"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8")).get("data", [])


def baixar(url: str, destino: Path) -> bool:
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            destino.write_bytes(resp.read())
        return True
    except (urllib.error.URLError, OSError) as erro:
        print(f"      failed: {erro}")
        return False


def existentes(pasta: Path) -> int:
    if not pasta.is_dir():
        return 0
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    return sum(1 for f in pasta.iterdir() if f.suffix.lower() in exts)


def main() -> None:
    ap = argparse.ArgumentParser(description="Download wallpapers per theme.")
    ap.add_argument("temas", nargs="*", help="themes to process (default: all)")
    ap.add_argument("--busca", default="frieren", help="search term")
    ap.add_argument("--n", type=int, default=5, help="images per theme")
    ap.add_argument("--min", default="1920x1080", help="minimum resolution")
    args = ap.parse_args()

    alvos = args.temas or variants()

    for tema in alvos:
        cor = WALLHAVEN_COLOR.get(tema)
        if not cor:
            print(f"  {tema}: no color registered in WALLHAVEN_COLOR, skipping")
            continue
        if cor not in CORES_VALIDAS:
            print(f"  {tema}: wallhaven does not accept the color {cor}, skipping")
            continue

        pasta = DESTINO / tema
        pasta.mkdir(parents=True, exist_ok=True)
        ja_tem = existentes(pasta)
        faltam = args.n - ja_tem

        if faltam <= 0:
            print(f"  {tema}: already has {ja_tem}, nothing to do")
            continue

        print(f"  {tema}: has {ja_tem}, fetching {faltam} more (color {cor})…")

        # Two passes: first filtered by the theme color, and if that returns
        # little (wallhaven's color filter is quite strict — pink, for example,
        # returns a handful), repeat without the filter to make up the count.
        tentativas = [("color " + cor, cor), ("no color filter", None)]

        baixadas = 0
        for rotulo, filtro in tentativas:
            if baixadas >= faltam:
                break
            try:
                resultados = buscar(args.busca, filtro, args.min)
            except Exception as erro:
                print(f"      search ({rotulo}) failed: {erro}")
                continue

            if not resultados:
                continue
            if filtro is None:
                print(f"      topping up with {rotulo}…")

            for item in resultados:
                if baixadas >= faltam:
                    break
                url = item["path"]
                nome = pasta / f"{args.busca}-{item['id']}{Path(url).suffix}"
                if nome.exists():
                    continue
                if baixar(url, nome):
                    print(f"      {nome.name}  ({item['resolution']})")
                    baixadas += 1
                    time.sleep(0.6)  # be polite to the API

        if baixadas == 0:
            print("      nothing new to download")


if __name__ == "__main__":
    main()
