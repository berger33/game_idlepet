#!/usr/bin/env python3
"""Compõe a folha de QA dos acessórios de pet (canal visual do agente).

Reproduz a geometria do PetShopCanvas para o pet texturizado (fit=1):
sprite 390 com os pés no pivô; âncoras locais neck=(0,-140) e
crown=(0,-390*0.9355-16). As texturas de art/cosmetics são sobrepostas com a
mesma especificação (h/dy/anchor) lida de PetCosmeticsArt.gd, para o preview
não divergir do código.

Uso: python3 tools/qa_accessory_preview.py [--pet caramelo]
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / ".preview" / "accessory_sheet.png"

PET_SIZE = 390.0
BASELINE = 479.0 / 512.0
NECK_Y = {"dog": -140.0, "cat": -125.0}
CROWN_Y = {"dog": -390.0 * BASELINE - 16.0, "cat": -335.0}
NECK_DX = {"dog": 0.0, "cat": -55.0}
CROWN_DX = {"dog": 0.0, "cat": -62.0}

PANEL = (440, 560)
COLS = 6


def parse_spec() -> dict:
    src = (REPO / "core/gameplay/PetCosmeticsArt.gd").read_text(encoding="utf8")
    m_block = re.search(r"ACCESSORY_TEXTURE_SPEC[^=]*=\s*\{(.*?)\n\}", src, re.S)
    block = m_block.group(1) if m_block else ""
    spec = {}
    for m in re.finditer(
        r'"(?P<id>[a-z_]+)":\s*\{"h":\s*(?P<h>[\d.]+),\s*"dy":\s*(?P<dy>-?[\d.]+),'
        r'\s*"anchor":\s*"(?P<anchor>\w+)"',
        block,
    ):
        spec[m["id"]] = {
            "h": float(m["h"]),
            "dy": float(m["dy"]),
            "anchor": m["anchor"],
        }
    return spec


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pet", default="caramelo")
    ap.add_argument("--species", default="dog", choices=["dog", "cat"])
    args = ap.parse_args()

    pet = Image.open(REPO / "art/pets" / f"{args.pet}.png").convert("RGBA")
    spec = parse_spec()
    ids = list(spec)

    rows = (len(ids) + 1 + COLS - 1) // COLS
    sheet = Image.new("RGBA", (PANEL[0] * COLS, PANEL[1] * rows), (246, 244, 240, 255))
    draw = ImageDraw.Draw(sheet)

    feet = (PANEL[0] / 2, PANEL[1] - 90)
    top = feet[1] - PET_SIZE * BASELINE

    for i, acc_id in enumerate(["none"] + ids):
        panel = Image.new("RGBA", PANEL, (0, 0, 0, 0))
        pdraw = ImageDraw.Draw(panel)
        pdraw.rounded_rectangle((14, 14, PANEL[0] - 14, PANEL[1] - 14), 26, (255, 255, 255, 255))
        pet_small = pet.resize((int(PET_SIZE), int(PET_SIZE)), Image.LANCZOS)
        panel.alpha_composite(pet_small, (int(feet[0] - PET_SIZE / 2), int(top)))
        if acc_id != "none":
            tex = Image.open(REPO / "art/cosmetics" / f"{acc_id}.png").convert("RGBA")
            s = spec[acc_id]
            h = s["h"]
            w = h * tex.width / tex.height
            if s["anchor"] == "neck":
                anchor_y, dx = NECK_Y[args.species], NECK_DX[args.species]
            else:
                anchor_y, dx = CROWN_Y[args.species], CROWN_DX[args.species]
            cy = feet[1] + anchor_y + s["dy"]
            box = (int(feet[0] + dx - w / 2), int(cy - h / 2), int(w), int(h))
            panel.alpha_composite(tex.resize((box[2], box[3]), Image.LANCZOS), (box[0], box[1]))
        label = acc_id
        pdraw.text((24, PANEL[1] - 44), label, fill=(60, 50, 40, 255))
        x = (i % COLS) * PANEL[0]
        y = (i // COLS) * PANEL[1]
        sheet.alpha_composite(panel, (x, y))
        draw.rectangle((x, y, x + PANEL[0] - 1, y + PANEL[1] - 1), outline=(200, 195, 188, 255))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"sheet: {OUT} spec={ids}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
