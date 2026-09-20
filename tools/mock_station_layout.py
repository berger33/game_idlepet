#!/usr/bin/env python3
"""Mock offline do contrato espacial V2 (alinhamento pet/estação e utensílio/prancha).

Replica em PIL a geometria exata de ``core/gameplay/StationArt.gd`` e
``core/gameplay/PetShopCanvas.gd`` (mesmas constantes, mesma ordem de desenho),
usando ``data/service_layouts.json`` como fonte única — igual ao runtime.

Não é o Godot: serve para inspeção visual e para checagens numéricas de
alinhamento sem precisar de binário do engine. O CI (Godot 4.7.2 headless,
``tools/smoke_interact.gd``) é quem valida o comportamento real.

Saída (em ``.preview/``, ignorado pelo git):
    mock_<serviço>.png  — cena completa 1080x1920 por serviço
    mock_contact_sheet.png — grade 3x2 com os 5 serviços + pet grande no banho
"""

from __future__ import annotations

import json
import math
import os
from typing import Sequence

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, ".preview")

WOOD = (0x8D, 0x6E, 0x63)
WOOD_LIGHT = (0xA1, 0x88, 0x7F)
CREAM = (0xFF, 0xF3, 0xE0)
CHARCOAL = (0x26, 0x32, 0x38)
WATER_BLUE = (0x4F, 0xC3, 0xF7)
PINK = (0xFF, 0x8F, 0xB1)
METAL = (0x90, 0xA4, 0xAE)

PLANK_DROP = 34.0
PET_TEXTURE_BASELINE = 479.0 / 512.0
TOOL_ORDER = ["soap", "clipper", "dryer", "perfume", "bow"]
TOOL_LEVELS = {"soap": 1, "clipper": 3, "dryer": 5, "perfume": 7, "bow": 10}
TITLES = {
    "bath": "BANHO DO BAIRRO",
    "groom": "TOSA DO BAIRRO",
    "dry": "SECAGEM ACONCHEGANTE",
    "perfume": "SPA PERFUMADO",
    "style": "ATELIÊ DE LAÇOS",
}
SMALL_BREEDS = ("Pinscher", "Yorkshire", "Pug", "Maltês", "Munchkin", "Shih-tzu")
LARGE_BREEDS = ("Golden", "Labrador", "Samoieda", "Bernês", "Maine Coon")
# Serviço -> pet usado no mock (o 6º azulejo mostra o maior sprite no banho).
TILE_PETS = {
    "bath": "caramelo",
    "groom": "luna_shih_tzu",
    "dry": "thor_pinscher",
    "perfume": "amora_siames",
    "style": "yuki_scottish",
}


def _rgba(color: Sequence[int], alpha: float) -> tuple[int, int, int, int]:
    return (int(color[0]), int(color[1]), int(color[2]), max(0, min(255, int(alpha * 255))))


def _lighten(color: Sequence[int], amount: float) -> tuple[int, int, int]:
    return tuple(int(c + (255 - c) * amount) for c in color[:3])  # type: ignore[return-value]


class Canvas:
    """Camada RGBA 1080x1920 com helpers que espelham draw_* do Godot."""

    def __init__(self, size: tuple[int, int] = (1080, 1920)) -> None:
        self.image = Image.new("RGBA", size, (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)
        self.font_cache: dict[tuple[str, int], ImageFont.FreeTypeFont] = {}

    def font(self, name: str, size: int) -> ImageFont.FreeTypeFont:
        key = (name, size)
        if key not in self.font_cache:
            self.font_cache[key] = ImageFont.truetype(
                os.path.join(ROOT, "art", "fonts", name), size
            )
        return self.font_cache[key]

    def _overlay(self, drawfn) -> None:
        """ImageDraw sobrescreve pixels (sem blend); desenha numa camada RGBA
        temporária e compõe por cima — mesmo comportamento do draw_* do Godot."""
        layer = Image.new("RGBA", self.image.size, (0, 0, 0, 0))
        drawfn(ImageDraw.Draw(layer))
        self.image.alpha_composite(layer)

    def box(
        self,
        rect: tuple[float, float, float, float],
        color: Sequence[int],
        alpha: float,
        radius: float,
        border: Sequence[int] | None = None,
        border_alpha: float = 1.0,
        border_width: float = 0.0,
    ) -> None:
        x, y, w, h = rect
        fill = _rgba(color, alpha)
        outline = None
        if border is not None and border_width > 0:
            outline = _rgba(border, border_alpha)

        def _do(draw: ImageDraw.ImageDraw) -> None:
            draw.rounded_rectangle(
                [x, y, x + w, y + h],
                radius=max(0.0, radius),
                fill=fill,
                outline=outline,
                width=max(1, int(border_width)),
            )

        self._overlay(_do)

    def ellipse(
        self, center: tuple[float, float], rx: float, ry: float, color: Sequence[int], alpha: float
    ) -> None:
        cx, cy = center

        def _do(draw: ImageDraw.ImageDraw) -> None:
            draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=_rgba(color, alpha))

        self._overlay(_do)

    def line(
        self,
        a: tuple[float, float],
        b: tuple[float, float],
        color: Sequence[int],
        alpha: float,
        width: float,
    ) -> None:
        def _do(draw: ImageDraw.ImageDraw) -> None:
            draw.line([a, b], fill=_rgba(color, alpha), width=max(1, int(width)))

        self._overlay(_do)

    def circle(
        self, center: tuple[float, float], radius: float, color: Sequence[int], alpha: float
    ) -> None:
        cx, cy = center

        def _do(draw: ImageDraw.ImageDraw) -> None:
            draw.ellipse(
                [cx - radius, cy - radius, cx + radius, cy + radius], fill=_rgba(color, alpha)
            )

        self._overlay(_do)

    def text_centered(
        self,
        text: str,
        center_x: float,
        baseline_y: float,
        size: int,
        color: Sequence[int],
        alpha: float = 1.0,
    ) -> None:
        font = self.font("DejaVuSans-Bold.ttf", size)
        box = self.draw.textbbox((0, 0), text, font=font)
        w = box[2] - box[0]
        h = box[3] - box[1]
        self.draw.text(
            (center_x - w / 2 - box[0], baseline_y - h - box[1]),
            text,
            font=font,
            fill=_rgba(color, alpha),
        )


# --------------------------------------------------------------------------- #
# Mobiliário (espelho de StationArt.gd)
# --------------------------------------------------------------------------- #
def draw_shelf_unit(cv: Canvas, levels: Sequence[float]) -> None:
    if not levels:
        return
    top = float(levels[0]) + PLANK_DROP - 26.0
    bottom = float(levels[-1]) + PLANK_DROP + 48.0
    cv.box((824, top, 192, bottom - top), CREAM, 0.42, 22, CHARCOAL, 0.16, 3)
    for level in levels:
        y = level + PLANK_DROP
        cv.box((824, y, 192, 22), WOOD, 1.0, 9, CHARCOAL, 0.32, 3)
        cv.line((834, y + 4), (1006, y + 4), _lighten(WOOD_LIGHT, 0.22), 1.0, 4)
        cv.line((834, y + 24), (1006, y + 24), CHARCOAL, 0.16, 3)


def draw_title_plaque(cv: Canvas, service: str) -> None:
    cv.box((320, 168, 450, 84), CREAM, 0.94, 26, PINK, 1.0, 4)
    cv.line((340, 178), (750, 178), (255, 255, 255), 0.5, 3)
    cv.text_centered(TITLES[service], 545, 225, 42, CHARCOAL)


def draw_station(cv: Canvas, service: str, cx: float, surface: float) -> None:
    cv.ellipse((cx, surface + 10), 216, 26, CHARCOAL, 0.16)
    if service == "bath":
        cv.box((cx - 190, surface - 52, 380, 240), CREAM, 0.97, 48, CHARCOAL, 0.32, 4)
        cv.box((cx - 170, surface - 28, 340, 198), WATER_BLUE, 0.16, 40)
        cv.ellipse((cx, surface - 36), 178, 16, WATER_BLUE, 0.45)
        cv.box((cx - 210, surface - 58, 420, 44), CREAM, 1.0, 22, PINK, 1.0, 4)
        cv.line((cx - 192, surface - 50), (cx + 192, surface - 50), (255, 255, 255), 0.6, 4)
        for foot_x in (cx - 150, cx + 114):
            cv.box((foot_x, surface + 180, 36, 26), WOOD, 1.0, 10, CHARCOAL, 0.3, 3)
    elif service == "groom":
        cv.box((cx - 200, surface, 400, 26), WOOD_LIGHT, 1.0, 13, CHARCOAL, 0.32, 4)
        cv.line(
            (cx - 186, surface + 6), (cx + 186, surface + 6), _lighten(WOOD_LIGHT, 0.24), 1.0, 4
        )
        for leg_x in (cx - 176, cx - 64, cx + 40, cx + 152):
            cv.box((leg_x, surface + 26, 24, 118), METAL, 0.95, 8, CHARCOAL, 0.28, 3)
        cv.box((cx - 160, surface + 100, 320, 14), METAL, 0.8, 7)
    elif service == "dry":
        cv.box((cx - 210, surface, 420, 46), CREAM, 1.0, 23, WATER_BLUE, 1.0, 4)
        for stitch_x in (cx - 104, cx, cx + 104):
            cv.line((stitch_x, surface + 9), (stitch_x, surface + 38), CHARCOAL, 0.14, 3)
        for leg_x in (cx - 182, cx - 56, cx + 32, cx + 158):
            cv.box((leg_x, surface + 46, 24, 124), METAL, 0.95, 8, CHARCOAL, 0.28, 3)
    elif service == "perfume":
        cv.box((cx - 150, surface, 300, 168), CREAM, 0.97, 36, CHARCOAL, 0.30, 4)
        cv.ellipse((cx, surface + 4), 148, 20, PINK, 0.85)
        cv.ellipse((cx, surface + 2), 148, 20, CHARCOAL, 0.10)
        for band_y in (surface + 66, surface + 126):
            cv.line((cx - 132, band_y), (cx + 132, band_y), WATER_BLUE, 0.4, 5)
    elif service == "style":
        cv.box((cx - 170, surface, 340, 92), PINK, 0.92, 46, CHARCOAL, 0.30, 4)
        cv.line((cx - 146, surface + 12), (cx + 146, surface + 12), (255, 255, 255), 0.4, 4)
        for tuft_x in (cx - 90, cx, cx + 90):
            cv.circle((tuft_x, surface + 46), 7, CHARCOAL, 0.20)
        for leg_x in (cx - 138, cx + 102):
            cv.box((leg_x, surface + 92, 36, 34), WOOD, 1.0, 9, CHARCOAL, 0.3, 3)


def draw_station_foreground(cv: Canvas, service: str, cx: float, surface: float) -> None:
    if service != "bath":
        return
    cv.box((cx - 210, surface - 32, 420, 58), CREAM, 0.99, 24, CHARCOAL, 0.30, 4)
    cv.line((cx - 190, surface - 24), (cx + 190, surface - 24), (255, 255, 255), 0.55, 4)
    cv.ellipse((cx, surface + 26), 176, 12, WATER_BLUE, 0.35)


# --------------------------------------------------------------------------- #
# Pet e utensílios (espelho de PetShopCanvas.gd)
# --------------------------------------------------------------------------- #
def sprite_size_for(breed: str) -> float:
    if any(token in breed for token in SMALL_BREEDS):
        return 330.0
    if any(token in breed for token in LARGE_BREEDS):
        return 445.0
    return 390.0


def draw_pet(cv: Canvas, pet: dict, foot_x: float, foot_y: float) -> tuple[float, float, float]:
    size = sprite_size_for(pet.get("breed", ""))
    path = os.path.join(ROOT, "art", "pets", f"{pet['id']}.png")
    sprite = Image.open(path).convert("RGBA")
    sprite = sprite.resize((int(size), int(size)), Image.LANCZOS)
    left = foot_x - size * 0.5
    top = foot_y - size * PET_TEXTURE_BASELINE
    cv.image.alpha_composite(sprite, (int(round(left)), int(round(top))))
    return left, top, size


def draw_tools(cv: Canvas, levels: Sequence[float], player_level: int) -> None:
    for index, tool in enumerate(TOOL_ORDER):
        cx, cy = 910.0, float(levels[index])
        path = os.path.join(ROOT, "art", "props", f"tool_{tool}.png")
        sprite = Image.open(path).convert("RGBA")
        draw_size = 116.0
        sprite = sprite.resize((int(draw_size), int(draw_size)), Image.LANCZOS)
        unlocked = player_level >= TOOL_LEVELS[tool]
        if not unlocked:
            sprite.putalpha(sprite.getchannel("A").point(lambda a: int(a * 0.28)))
        cv.image.alpha_composite(
            sprite, (int(round(cx - draw_size / 2)), int(round(cy - draw_size / 2)))
        )
        if not unlocked:
            cv.circle((cx, cy), 29, CHARCOAL, 0.76)
            cv.text_centered("Nv.%d" % TOOL_LEVELS[tool], cx, cy + 10, 20, (255, 255, 255))


def draw_upgrades_button(cv: Canvas) -> None:
    """Botão redondo do HUD (Main.gd: position 952,150, 86x86, ícone 60%)."""
    icon = Image.open(os.path.join(ROOT, "art", "ui", "icons", "upgrades.png")).convert("RGBA")
    icon = icon.resize((52, 52), Image.LANCZOS)
    cv.circle((995, 193), 43, (0x7E, 0xD9, 0x57), 0.96)
    cv.image.alpha_composite(icon, (995 - 26, 193 - 26))


# --------------------------------------------------------------------------- #
# Composição
# --------------------------------------------------------------------------- #
def compose(service: str, stage: dict, pet: dict, player_level: int = 10) -> Canvas:
    cv = Canvas()
    bg_path = os.path.join(ROOT, "art", "backgrounds", stage["background"])
    bg = Image.open(bg_path).convert("RGBA").resize((1080, 1920), Image.LANCZOS)
    cv.image.alpha_composite(bg, (0, 0))
    draw_title_plaque(cv, service)
    levels = stage["shelf_y"]
    draw_shelf_unit(cv, levels)
    draw_tools(cv, levels, player_level)
    cx, surface = float(stage["pet_position"][0]), float(stage["pet_position"][1])
    draw_station(cv, service, cx, surface)
    draw_pet(cv, pet, cx, surface)
    draw_station_foreground(cv, service, cx, surface)
    draw_upgrades_button(cv)
    return cv


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    layouts = json.load(open(os.path.join(ROOT, "data", "service_layouts.json"), encoding="utf-8"))
    pets = {p["id"]: p for p in json.load(open(os.path.join(ROOT, "data", "pets.json"), encoding="utf-8"))["pets"]}
    stages = {s["service"]: s for s in layouts["stages"]}

    tiles: list[Image.Image] = []
    for service in ("bath", "groom", "dry", "perfume", "style"):
        stage = stages[service]
        pet = pets[TILE_PETS[service]]
        cv = compose(service, stage, pet)
        cv.image.save(os.path.join(OUT_DIR, f"mock_{service}.png"))
        tiles.append(cv.image.resize((360, 640), Image.LANCZOS))
        print(
            "mock_%s.png  pet=%s (%s) sprite=%.0f  pés=(%.0f,%.0f)  pranchas=%s"
            % (
                service,
                pet["id"],
                pet.get("breed", "?"),
                sprite_size_for(pet.get("breed", "")),
                stage["pet_position"][0],
                stage["pet_position"][1],
                stage["shelf_y"],
            )
        )
    # 6º azulejo: maior sprite (445px) no banho — leitura da borda frontal.
    big = compose("bath", stages["bath"], pets["apolo_bernese"])
    tiles.append(big.image.resize((360, 640), Image.LANCZOS))

    sheet = Image.new("RGBA", (360 * 3, 640 * 2), (30, 34, 38, 255))
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, ((index % 3) * 360, (index // 3) * 640))
    sheet_path = os.path.join(OUT_DIR, "mock_contact_sheet.png")
    sheet.save(sheet_path)
    print("contact sheet:", sheet_path, sheet.size)


if __name__ == "__main__":
    main()
