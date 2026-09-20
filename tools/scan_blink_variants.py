#!/usr/bin/env python3
"""QA e progresso das variantes de piscada por estado (BLINK_MATRIX).

Para cada ``<estado>_blink.png`` existente em ``art/pet_animations/<pet>/``:
- diff contra o estado de olhos abertos deve ficar na faixa de olhos (0.5%–15%);
- diff contra o blink seco deve ser > 0 quando o estado não é seco (a variante
  precisa herdar a condição: molhado/sujo/peludo);
- contagem de opacos/transparentes dentro do contrato de 512x512 RGBA.

Reporta a matriz de progresso (quantos de 250 criados por fase) sem falhar o CI:
o gate continua sendo ``verify_pet_animations.py`` para os 10 estados autorais.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
S = 128
VARIANTS = ["dirty_blink", "wet_blink", "messy_blink", "sad_blink", "dizzy_blink"]
BASE_OF = {
    "dirty_blink": "dirty",
    "wet_blink": "wet",
    "messy_blink": "messy",
    "sad_blink": "sad",
    "dizzy_blink": "dizzy",
}


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA").resize((S, S), Image.LANCZOS)


def diff_ratio(a: Image.Image, b: Image.Image) -> float:
    da = ImageChops.difference(a.getchannel("A"), b.getchannel("A")).point(
        lambda v: 255 if v > 24 else 0
    )
    dc = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L").point(
        lambda v: 255 if v > 40 else 0
    )
    both = ImageChops.add(da, dc).point(lambda v: 255 if v > 0 else 0)
    return sum(1 for p in both.getdata() if p == 255) / (S * S)


def main() -> None:
    pets = [p["id"] for p in json.load(open(ROOT / "data/pets.json", encoding="utf-8"))["pets"]]
    problems: list[str] = []
    counts = {v: 0 for v in VARIANTS}
    for pet in pets:
        for variant in VARIANTS:
            path = ROOT / "art/pet_animations" / pet / f"{variant}.png"
            if not os.path.exists(path):
                continue
            counts[variant] += 1
            img = load(path)
            opaque = sum(1 for p in img.getchannel("A").getdata() if p > 12)
            if opaque < 3000:
                problems.append(f"{pet}/{variant}: quase transparente ({opaque} opacos)")
            open_state = load(ROOT / "art/pet_animations" / pet / f"{BASE_OF[variant]}.png")
            ratio = diff_ratio(img, open_state)
            if ratio < 0.005:
                problems.append(f"{pet}/{variant}: identico ao estado aberto")
            elif ratio > 0.15:
                problems.append(f"{pet}/{variant}: diff {ratio:.0%} do estado aberto (pose?)")
            dry_blink = ROOT / "art/pet_animations" / pet / "blink.png"
            if os.path.exists(dry_blink) and diff_ratio(img, load(dry_blink)) < 0.005:
                problems.append(f"{pet}/{variant}: identico ao blink seco (nao herdou condicao)")
    total = sum(counts.values())
    print("progresso variantes: %d/250" % total)
    for variant in VARIANTS:
        print("  %-12s %2d/50" % (variant, counts[variant]))
    if problems:
        print("PROBLEMAS (%d):" % len(problems))
        for p in problems:
            print(" -", p)
    else:
        print("QA das variantes existentes: OK")


if __name__ == "__main__":
    main()
