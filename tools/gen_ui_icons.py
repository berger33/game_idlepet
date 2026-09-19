#!/usr/bin/env python3
"""Gera o set de ícones de navegação (PNG 64px, branco sobre transparente).

Ícones geométricos desenhados com supersampling 8x (antialiasing) para uso
via Button.icon — nunca glifos Unicode, que dependem da cobertura da fonte
instalada no dispositivo (causa do "□" em vários Androids).

Uso: python3 tools/gen_ui_icons.py
Saída: art/ui/icons/{missions,collection,map,settings}.png
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "art" / "ui" / "icons"
SIZE = 64
SS = 8  # supersampling
BIG = SIZE * SS
WHITE = (255, 255, 255, 255)


def render(name: str, painter) -> None:
    big = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    painter(draw, BIG)
    small = big.resize((SIZE, SIZE), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    small.save(OUT / f"{name}.png")
    print(f"ok: {OUT / name}.png")


def star(draw: ImageDraw.ImageDraw, s: int) -> None:
    cx, cy, r_out, r_in = s / 2, s / 2, s * 0.46, s * 0.19
    points = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=WHITE)


def heart(draw: ImageDraw.ImageDraw, s: int) -> None:
    points = []
    for i in range(240):
        t = 2 * math.pi * i / 240
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        points.append((s / 2 + x * s / 40, s / 2 - y * s / 40 + s * 0.02))
    draw.polygon(points, fill=WHITE)


def house(draw: ImageDraw.ImageDraw, s: int) -> None:
    m = s * 0.10
    # telhado
    draw.polygon(
        [(s / 2, m), (s - m, s * 0.52), (m, s * 0.52)],
        fill=WHITE,
    )
    # corpo com porta recortada
    body = (s * 0.20, s * 0.50, s * 0.80, s * 0.90)
    draw.rectangle(body, fill=WHITE)
    door = (s * 0.42, s * 0.62, s * 0.58, s * 0.90)
    draw.rectangle(door, fill=(0, 0, 0, 0))


def gear(draw: ImageDraw.ImageDraw, s: int) -> None:
    cx = cy = s / 2
    teeth = 8
    for i in range(teeth):
        angle = 2 * math.pi * i / teeth
        x1 = cx + s * 0.28 * math.cos(angle - 0.22)
        y1 = cy + s * 0.28 * math.sin(angle - 0.22)
        x2 = cx + s * 0.46 * math.cos(angle - 0.14)
        y2 = cy + s * 0.46 * math.sin(angle - 0.14)
        x3 = cx + s * 0.46 * math.cos(angle + 0.14)
        y3 = cy + s * 0.46 * math.sin(angle + 0.14)
        x4 = cx + s * 0.28 * math.cos(angle + 0.22)
        y4 = cy + s * 0.28 * math.sin(angle + 0.22)
        draw.polygon([(x1, y1), (x2, y2), (x3, y3), (x4, y4)], fill=WHITE)
    draw.ellipse([cx - s * 0.32, cy - s * 0.32, cx + s * 0.32, cy + s * 0.32], fill=WHITE)
    draw.ellipse([cx - s * 0.13, cy - s * 0.13, cx + s * 0.13, cy + s * 0.13], fill=(0, 0, 0, 0))


def person(draw: ImageDraw.ImageDraw, s: int) -> None:
    draw.ellipse([s * 0.32, s * 0.10, s * 0.68, s * 0.46], fill=WHITE)
    draw.pieslice(
        [s * 0.14, s * 0.42, s * 0.86, s * 1.16], start=180, end=360, fill=WHITE
    )
    draw.rectangle([s * 0.14, s * 0.76, s * 0.86, s * 0.90], fill=WHITE)


def bag(draw: ImageDraw.ImageDraw, s: int) -> None:
    draw.arc([s * 0.30, s * 0.08, s * 0.70, s * 0.48], start=180, end=360, fill=WHITE, width=int(s * 0.09))
    draw.polygon(
        [
            (s * 0.16, s * 0.34),
            (s * 0.84, s * 0.34),
            (s * 0.78, s * 0.90),
            (s * 0.22, s * 0.90),
        ],
        fill=WHITE,
    )


def main() -> None:
    render("missions", star)
    render("collection", heart)
    render("map", house)
    render("settings", gear)
    render("staff", person)
    render("shop", bag)


if __name__ == "__main__":
    main()
