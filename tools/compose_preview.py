#!/usr/bin/env python3
"""Compositor offline que replica o render 2D do PetShopCanvas (Godot).

Reproduz: background esticado para 1080x1920 + pet 512px redimensionado,
centralizado em SERVICE_PET_POSITIONS (lido direto de PetShopCanvas.gd,
fonte única de verdade). Serve para calibrar/validar a composição
"pet dentro da estação" sem precisar rodar o engine.

Uso:
  python3 tools/compose_preview.py --service bath
  python3 tools/compose_preview.py --service bath --pet luna --x 540 --y 900 --size 360
"""
import argparse
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BG = {
    "bath": "petshop_quintal.png",
    "groom": "petshop_tosa.png",
    "dry": "petshop_secagem.png",
    "perfume": "petshop_perfume.png",
    "style": "petshop_estilo.png",
}
CANVAS = (1080, 1920)
PET_BASELINE = 479.0 / 512.0  # espelho de PET_TEXTURE_BASELINE

SMALL_BREEDS = ("chihuahua", "yorkshire", "lulu")
LARGE_BREEDS = ("são bernardo", "mastim", "terra nova")


def _load_pet_positions() -> dict:
    """Lê SERVICE_PET_POSITIONS de PetShopCanvas.gd (fonte única de verdade)."""
    source = (ROOT / "core" / "gameplay" / "PetShopCanvas.gd").read_text(encoding="utf-8")
    block = re.search(r"SERVICE_PET_POSITIONS: Dictionary = \{(.*?)\}", source, re.S)
    positions = {}
    for service, x, y in re.findall(r'&"(\w+)": Vector2\((\d+), (\d+)\)', block.group(1)):
        positions[service] = (int(x), int(y))
    return positions


PET_POSITIONS = _load_pet_positions()


def pet_size_for(profile: dict, override: int | None) -> int:
    if override:
        return override
    breed = str(profile.get("breed", "")).lower()
    if any(name in breed for name in SMALL_BREEDS):
        return 330
    if any(name in breed for name in LARGE_BREEDS):
        return 445
    return 390


def compose(service: str, pet_id: str, x: int, y: int, size: int, marker: bool) -> Path:
    bg_path = ROOT / "art" / "backgrounds" / BG[service]
    pets = json.loads((ROOT / "data" / "pets.json").read_text(encoding="utf-8"))
    profile = next((p for p in pets["pets"] if p["id"] == pet_id), pets["pets"][0])
    pet_path = ROOT / "art" / "pets" / f"{pet_id}.png"

    img = Image.open(bg_path).convert("RGBA").resize(CANVAS, Image.LANCZOS)

    if size <= 0:
        size = pet_size_for(profile, None)

    center = (x, y)
    if pet_path.exists():
        pet = Image.open(pet_path).convert("RGBA").resize((size, size), Image.LANCZOS)
        # draw_texture_rect: sprite centralizado no pet_position; a baseline
        # (479/512) marca os pés — na prática o sprite cobre center ± size/2.
        img.alpha_composite(pet, (center[0] - size // 2, center[1] - size // 2))
    else:
        print(f"AVISO: textura ausente para {pet_id}; desenhando placeholder")

    if marker:
        draw = ImageDraw.Draw(img)
        draw.ellipse([x - 12, y - 12, x + 12, y + 12], outline="red", width=4)

    out = ROOT / ".preview" / f"{service}_{pet_id}_{x}_{y}_{size}.png"
    out.parent.mkdir(exist_ok=True)
    img.save(out)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--service", required=True, choices=sorted(BG))
    parser.add_argument("--pet", default="caramelo")
    parser.add_argument("--x", type=int, default=None, help="override do centro X")
    parser.add_argument("--y", type=int, default=None, help="override do centro Y")
    parser.add_argument("--size", type=int, default=0, help="0 = automático por raça")
    parser.add_argument("--marker", action="store_true", help="desenha o centro do pet")
    args = parser.parse_args()

    code_x, code_y = PET_POSITIONS[args.service]
    x = args.x if args.x is not None else code_x
    y = args.y if args.y is not None else code_y
    out = compose(args.service, args.pet, x, y, args.size, args.marker)
    print(f"ok: {out}  (centro {x},{y} — código {code_x},{code_y})")


if __name__ == "__main__":
    main()
