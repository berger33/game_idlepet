#!/usr/bin/env python3
"""Compositor de QA das cenas: replica a ordem de _draw() do PetShopCanvas
em PIL (fundo → placa+título → estante → ferramentas → estação → pet →
água+fatia frontal) e verifica numericamente o posicionamento validado:

  * pranchas da estante sob as ferramentas (apoio de ~24px);
  * fatia frontal da banheira oclui as patas do pet (leitura "dentro d'água");
  * corpo do pet visível acima do aro;
  * aro frontal contínuo através da largura do pet;
  * sem colisão estação × estante × placa de título.

Gera folhas de contato em .preview/ para inspeção visual.

Uso: python3 tools/compose_scene_preview.py [--pet caramelo] [--pet2 luna_husky]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / ".preview"

CANVAS = (1080, 1920)
SURFACE = 1160.0
CX = 540.0
PET_SIZE = 390.0
PET_BASELINE = 479.0  # linha dos pés dentro do sprite 512
PET_TOP = SURFACE - PET_BASELINE * (PET_SIZE / 512.0)

RIM_LINE = SURFACE - 36.0
SHELF_X, SHELF_W, SHELF_H = 812.0, 216.0, 786.0
SHELF_PLANK0_FRAC = 0.1853
PLANK_DROP = 34.0
SHELF_Y = [679, 801, 923, 1045, 1167]

STATION_BOXES = {
    "bathtub_rustic": (320.0, SURFACE - 87.0, 440.0, 314.0),
    "bathtub_spa": (320.0, SURFACE - 109.0, 440.0, 305.0),
    "groom": (340.0, SURFACE, 400.0, 121.0),
    "dry": (330.0, SURFACE, 420.0, 169.0),
    "perfume": (390.0, SURFACE, 300.0, 179.0),
    "style": (370.0, SURFACE, 340.0, 110.0),
}
BATHTUB_RIM_FRACS = {"bathtub_rustic": 0.1624, "bathtub_spa": 0.2393}

SERVICE_BG = {
    "bath": "petshop_quintal.png",
    "groom": "petshop_tosa.png",
    "dry": "petshop_secagem.png",
    "perfume": "petshop_perfume.png",
    "style": "petshop_estilo.png",
}
SERVICE_TITLES = {
    "bath": "BANHO & ESPUMA",
    "groom": "TOSA & APARO",
    "dry": "SECAGEM ACONCHEGANTE",
    "perfume": "SPA PERFUMADO",
    "style": "ATELIÊ DE LAÇOS",
}
TOOLS = ["tool_soap.png", "tool_clipper.png", "tool_dryer.png", "tool_perfume.png", "tool_bow.png"]

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def paste(dst: Image.Image, src: Image.Image, box: tuple[float, float, float, float]) -> None:
    x, y, w, h = (int(round(v)) for v in box)
    layer = src.resize((w, h), Image.LANCZOS)
    dst.alpha_composite(layer, (x, y))


def compose(service: str, pet_id: str, tier: int, establishment: str) -> tuple[Image.Image, dict]:
    scene = Image.new("RGBA", CANVAS, (255, 255, 255, 255))

    # 1. fundo esticado para o canvas (igual draw_texture_rect_region)
    bg = Image.open(REPO / "art/backgrounds" / SERVICE_BG[service]).convert("RGBA")
    scene.alpha_composite(bg.resize(CANVAS, Image.BILINEAR))

    # 2. placa de título + serviço + capítulo do estabelecimento
    d = ImageDraw.Draw(scene)
    d.rounded_rectangle((310, 160, 770, 266), 26, fill=(255, 243, 224, 240), outline=(255, 143, 177, 255), width=4)
    d.line((330, 170, 750, 170), fill=(255, 255, 255, 128), width=3)
    title_font = ImageFont.truetype(FONT_BOLD, 34)
    sub_font = ImageFont.truetype(FONT_BOLD, 22)
    d.text((540, 188), SERVICE_TITLES[service], font=title_font, fill=(38, 50, 56, 255), anchor="ma")
    d.text((540, 238), f"★ {establishment.upper()} ★", font=sub_font, fill=(141, 90, 119, 255), anchor="ma")

    # 3. estante (arte raster) ancorada pela 1ª prancha
    first_plank_top = SHELF_Y[0] + PLANK_DROP
    shelf_top = first_plank_top - SHELF_PLANK0_FRAC * SHELF_H
    shelf = Image.open(REPO / "art/stations/shelf_unit.png").convert("RGBA")
    paste(scene, shelf, (SHELF_X, shelf_top, SHELF_W, SHELF_H))

    # 4. utensílios (116px, centro em 910, shelf_y)
    for tool_png, level_y in zip(TOOLS, SHELF_Y):
        tool = Image.open(REPO / "art/props" / tool_png).convert("RGBA")
        paste(scene, tool, (910 - 58, level_y - 58, 116, 116))

    # 5. estação (atrás do pet)
    key = "bathtub_rustic" if (service == "bath" and tier <= 1) else ("bathtub_spa" if service == "bath" else service)
    STATION_FILES = {
        "bathtub_rustic": "station_bathtub_rustic.png",
        "bathtub_spa": "station_bathtub_spa.png",
        "groom": "station_groom_table.png",
        "dry": "station_drying_table.png",
        "perfume": "station_spa_pedestal.png",
        "style": "station_ottoman.png",
    }
    station = Image.open(REPO / "art/stations" / STATION_FILES[key]).convert("RGBA")
    box = STATION_BOXES[key]
    station_only = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    paste(station_only, station, box)
    scene.alpha_composite(station_only)

    # 6. pet (sprite 512, pés na surface)
    pet = Image.open(REPO / "art/pets" / f"{pet_id}.png").convert("RGBA")
    pet_layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    paste(pet_layer, pet, (CX - PET_SIZE / 2, PET_TOP, PET_SIZE, PET_SIZE))
    pet_np = np.array(pet_layer)
    scene.alpha_composite(pet_layer)

    # 7. água translúcida + fatia frontal (banho)
    if service == "bath":
        d.ellipse((CX - 168, RIM_LINE - 8, CX + 168, RIM_LINE + 20), fill=(79, 195, 247, 90))
        frac = BATHTUB_RIM_FRACS[key]
        sw, sh = station.size
        top = round(frac * sh)
        src = station.crop((0, top, sw, sh))
        paste(scene, src, (box[0], RIM_LINE, box[2], sh - top))

    # --------------------------- QA numérico ---------------------------
    checks: dict[str, object] = {}
    arr = np.array(scene)
    shelf_arr = np.array(shelf.resize((int(SHELF_W), int(SHELF_H)), Image.LANCZOS))

    # pranchas sob ferramentas
    planks_ok = True
    for level_y in SHELF_Y:
        y_local = int(level_y + PLANK_DROP - shelf_top)
        band = shelf_arr[y_local : y_local + 20, 30:186, 3]
        planks_ok &= bool((band > 120).mean() > 0.7)
    checks["planks_under_tools"] = planks_ok

    # apoio: fundo do sprite da ferramenta invade a prancha ~24px
    checks["tool_plank_overlap"] = 58 - PLANK_DROP  # =24 por construção

    if service == "bath":
        x0, x1 = int(CX - 100), int(CX + 100)
        # patas ocluídas pela parede frontal (pet some abaixo do aro)
        # banda ABAIXO da elipse d'água (termina em RIM_LINE+20) para o check
        front = arr[int(RIM_LINE) + 22 : int(RIM_LINE) + 52, x0:x1, :3]
        stat = np.array(station_only)[int(RIM_LINE) + 22 : int(RIM_LINE) + 52, x0:x1, :3]
        # tolera a elipse d'água translúcida e a franja anti-halo da arte
        match = float((np.abs(front.astype(int) - stat.astype(int)).max(axis=2) <= 12).mean())
        checks["legs_occluded_by_tub"] = bool(match >= 0.92)
        checks["legs_match_frac"] = round(match, 3)
        # corpo visível acima do aro (pet aparece sobre a estação)
        visible = bool(
            (pet_np[900:1080, x0:x1, 3] > 100).mean() > 0.05
        )
        checks["pet_visible_above_rim"] = visible
        # aro contínuo na linha d'água
        slice_alpha = arr[int(RIM_LINE) + 2 : int(RIM_LINE) + 6, 340:740, 3]
        checks["rim_continuous"] = bool((slice_alpha > 200).mean() > 0.9)

    # sem colisões horizontais estação × estante × placa
    checks["station_shelf_gap"] = SHELF_X - (box[0] + box[2])
    checks["plaque_shelf_gap"] = SHELF_X - 770

    return scene, checks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pet", default="caramelo")
    ap.add_argument("--pet2", default="luna_shih_tzu")
    args = ap.parse_args()
    OUT.mkdir(exist_ok=True)

    scenes = [
        ("bath", args.pet, 1, "Banheiro de Quintal"),
        ("bath", args.pet2, 4, "Pet Shop da Vila"),
        ("groom", args.pet2, 2, "Salão do Bairro"),
        ("dry", args.pet, 3, "Espaço Pet Charme"),
        ("perfume", args.pet2, 5, "Clínica Veterinária"),
        ("style", args.pet, 6, "Spa & Boutique Pet"),
    ]
    ok = True
    tiles = []
    for service, pet_id, tier, est in scenes:
        if not (REPO / "art/pet_animations" / pet_id).is_dir():
            print(f"[skip] pet {pet_id} não existe")
            continue
        scene, checks = compose(service, pet_id, tier, est)
        scene.save(OUT / f"scene_{service}_t{tier}.png")
        tiles.append((scene, f"{service} t{tier}"))
        bad = [k for k, v in checks.items() if v is False]
        ok &= not bad
        print(f"{service:8s} tier{tier} → {checks}")
        if bad:
            print(f"  FALHOU: {bad}")

    # folha de contato 3x2
    if tiles:
        sheet = Image.new("RGBA", (3 * 540 + 40, 2 * 960 + 60), (24, 24, 24, 255))
        for i, (scene, label) in enumerate(tiles[:6]):
            col, row = i % 3, i // 3
            thumb = scene.resize((540, 960), Image.LANCZOS)
            sheet.alpha_composite(thumb, (10 + col * 550, 30 + row * 980))
        sheet.convert("RGB").save(OUT / "scene_sheet.png", quality=90)
        print(f"folha: {OUT / 'scene_sheet.png'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
