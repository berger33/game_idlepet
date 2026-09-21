#!/usr/bin/env python3
"""Normaliza as ilustrações geradas dos acessórios de pet para assets RGBA.

Pipeline por peça (mesma filosofia de tools/normalize_station_art.py):
  1. Flood-fill a partir das bordas remove o fundo quase branco (o branco
     INTERNO da arte — brilhos, bolhas, poás — permanece opaco).
  2. Recorta o bounding box do objeto.
  3. Salva RGBA em art/cosmetics/<id>.png (tamanho canônico 512).

Uso: python3 tools/normalize_cosmetics_art.py [--qa-only]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "art" / "_gen"
OUT = REPO / "art" / "cosmetics"

# id do cosmético (data/cosmetics.json) -> arquivo gerado.
ITEMS = {
    "bandana_blue": "bandana_blue_raw.png",
    "bandana_red": "bandana_red_raw.png",
    "scarf_caramel": "scarf_caramel_raw.png",
    "crown_gold": "crown_gold_raw.png",
    "crown_bubbles": "crown_bubbles_raw.png",
}

CANON = 512
BG_TOL = 24  # distância máxima ao branco do fundo no flood-fill


def _flood_remove_bg(img: Image.Image) -> Image.Image:
    """Torna transparente o fundo conectado às bordas (quase branco)."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    # cor de referência: média dos 4 cantos
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    ref = tuple(sum(c[k] for c in corners) // 4 for k in range(3))
    seen = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        r, g, b, _ = px[x, y]
        if abs(r - ref[0]) + abs(g - ref[1]) + abs(b - ref[2]) > BG_TOL * 3:
            continue
        px[x, y] = (r, g, b, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return rgba


def normalize(item_id: str, src_name: str) -> Image.Image:
    raw = Image.open(SRC / src_name)
    cut = _flood_remove_bg(raw)
    bbox = cut.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"{item_id}: recorte vazio (flood-fill comeu tudo?)")
    cropped = cut.crop(bbox)
    # recorte justo (aspecto real da peça) com maior dimensão = CANON
    w, h = cropped.size
    scale = CANON / max(w, h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    return cropped.resize((nw, nh), Image.LANCZOS)


def main() -> int:
    qa_only = "--qa-only" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    for item_id, src_name in ITEMS.items():
        art = normalize(item_id, src_name)
        if not qa_only:
            art.save(OUT / f"{item_id}.png")
        bbox = art.getchannel("A").getbbox()
        print(f"{item_id}: {art.size} bbox={bbox}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
