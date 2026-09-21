#!/usr/bin/env python3
"""Gera as estantes temáticas de cada cenário (art/stations/shelf_<serviço>.png).

A estante é a "prateleira atrás dos produtos": os utensílios (sabão, cortador,
secador, perfume, laço) são desenhados pelo canvas em `(910, shelf_y[i])` e a
arte da estante é ancorada pela 1ª prancha (`StationArt.draw_shelf_unit`), então
as pranchas desta arte têm de cair EXATAMENTE em `shelf_y[i] + PLANK_DROP` no
canvas — é isso que faz cada item parecer apoiado na prateleira.

Geometria (frações da altura da arte, independentes de resolução):
  PLANK0_FRAC = 0.1853 e espaçamento 122/780 por degrau — mesmas constantes do
  StationArt.gd / service_layouts.json (shelf_y = 679..1167, passo 122).

Cada serviço ganha material/paleta próprios, harmônicos com a parede do fundo:
  bath    madeira rústica quente + fundo creme-sálvia (quintal)
  groom   madeira clara + fundo menta (salão de bairro)
  dry     madeira mel + fundo pêssego (espaço charme)
  perfume mármore branco + dourado + fundo lavanda (spa/clínica)
  style   rosewood + blush + dourado (ateliê/boutique)

Saída em 2x (432x1560) para o Godot filtrar para baixo com nitidez.

Uso: python3 tools/gen_shelf_art.py [--qa-only]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "art" / "stations"

# resolução autoral (2x do box 216x780 do jogo)
W, H = 432, 1560
S = 2.0

# frações das pranchas (topo) — idênticas às constantes de StationArt.gd
PLANK0_FRAC = 0.1853
PLANK_STEP_FRAC = 122.0 / 780.0
PLANK_TOPS = [ (PLANK0_FRAC + i * PLANK_STEP_FRAC) * H for i in range(5) ]
BOTTOM_TOP = 0.9474 * H

SIDE_W = 26.0          # pilares laterais (2x)
CORNIC_H = 34.0        # sanca superior
PLANK_LIP = 12.0       # face superior clara da prancha
PLANK_FACE = 34.0      # espelho frontal da prancha


def _vgrad(d, x0, y0, x1, y1, top, bot):
    """Preenche um retângulo com gradiente vertical suave."""
    for yy in range(int(y0), int(y1)):
        t = (yy - y0) / max(1.0, (y1 - y0 - 1))
        c = tuple(int(top[k] + (bot[k] - top[k]) * t) for k in range(3))
        d.line((x0, yy, x1, yy), fill=(*c, 255))


def _hgrad(d, x0, y0, x1, y1, left, right):
    for xx in range(int(x0), int(x1)):
        t = (xx - x0) / max(1.0, (x1 - x0 - 1))
        c = tuple(int(left[k] + (right[k] - left[k]) * t) for k in range(3))
        d.line((xx, y0, xx, y1), fill=(*c, 255))


def _grain(d, x0, y0, x1, y1, color, n, seed=7):
    """Veios de madeira horizontais discretos."""
    import random
    rng = random.Random(seed)
    for _ in range(n):
        yy = rng.uniform(y0 + 2, y1 - 2)
        xx = rng.uniform(x0, x1 - 60)
        ln = rng.uniform(30, 90)
        d.line((xx, yy, xx + ln, yy + rng.uniform(-1, 1)), fill=(*color, 40), width=2)


def _plank_layers(y_top, wood, wood_light, wood_dark):
    """Prancha em duas camadas: sombra de contato (atrás) e tábua (na frente)."""
    x0, x1 = SIDE_W - 4, W - SIDE_W + 4
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x0 + 6, y_top + PLANK_LIP + PLANK_FACE - 2,
                          x1 - 6, y_top + PLANK_LIP + PLANK_FACE + 26), 14,
                         fill=(30, 25, 20, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(9))

    plank = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(plank)
    # face superior (luz)
    _vgrad(d, x0, y_top, x1, y_top + PLANK_LIP, wood_light, wood)
    # espelho frontal com gradiente + veios
    _vgrad(d, x0, y_top + PLANK_LIP, x1, y_top + PLANK_LIP + PLANK_FACE, wood, wood_dark)
    _grain(d, x0 + 4, y_top + PLANK_LIP + 3, x1 - 4, y_top + PLANK_LIP + PLANK_FACE - 3,
           wood_dark, 3)
    # fio de luz no topo e sombra na base da prancha
    d.line((x0, y_top + 1, x1, y_top + 1), fill=(255, 250, 240, 120), width=2)
    d.line((x0, y_top + PLANK_LIP + PLANK_FACE - 1, x1, y_top + PLANK_LIP + PLANK_FACE - 1),
           fill=(0, 0, 0, 70), width=2)
    # mãos-francesas discretas
    for bx in (x0 + 26, x1 - 40):
        d.rounded_rectangle((bx, y_top + PLANK_LIP + PLANK_FACE, bx + 14,
                             y_top + PLANK_LIP + PLANK_FACE + 22), 5,
                            fill=(*wood_dark, 230))
    return plank, shadow


def build_shelf(theme: dict) -> Image.Image:
    wood = theme["wood"]; wood_light = theme["wood_light"]; wood_dark = theme["wood_dark"]
    back_top = theme["back_top"]; back_bot = theme["back_bot"]
    trim = theme.get("trim")

    back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(back)
    # painel traseiro com gradiente vertical suave
    _vgrad(d, SIDE_W, CORNIC_H, W - SIDE_W, H - 6, back_top, back_bot)
    # réguas verticais discretas no fundo
    for xx in range(int(SIDE_W) + 34, int(W - SIDE_W), 68):
        d.line((xx, CORNIC_H, xx, H - 6), fill=(0, 0, 0, 14), width=2)
    d.rectangle((SIDE_W, CORNIC_H, W - SIDE_W - 1, H - 6), outline=(0, 0, 0, 60), width=2)
    if trim:
        d.rectangle((SIDE_W + 3, CORNIC_H + 3, W - SIDE_W - 4, H - 9), outline=(*trim, 90), width=3)

    # ordem de composição: fundo -> sombras -> pranchas -> estrutura
    planks, shadows = [], []
    for y in list(PLANK_TOPS) + [BOTTOM_TOP]:
        plank, shadow = _plank_layers(y, wood, wood_light, wood_dark)
        planks.append(plank)
        shadows.append(shadow)

    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    # pilares laterais com gradiente horizontal + luz interna
    _hgrad(fd, 0, 0, SIDE_W, H, wood_dark, wood_light)
    _hgrad(fd, W - SIDE_W, 0, W, H, wood_light, wood_dark)
    fd.line((SIDE_W - 1, 0, SIDE_W - 1, H), fill=(255, 250, 240, 90), width=2)
    fd.line((W - SIDE_W, 0, W - SIDE_W, H), fill=(0, 0, 0, 60), width=2)
    # sanca superior (coroamento) com luz
    fd.rounded_rectangle((-6, -8, W + 6, CORNIC_H - 6), 12, fill=(*wood_light, 255))
    _vgrad(fd, 0, 4, W, CORNIC_H - 6, wood_light, wood)
    fd.line((4, CORNIC_H - 7, W - 4, CORNIC_H - 7), fill=(0, 0, 0, 70), width=3)
    if trim:
        fd.line((4, CORNIC_H - 12, W - 4, CORNIC_H - 12), fill=(*trim, 150), width=3)
    # contorno externo arredondado
    fd.rounded_rectangle((0, 0, W - 1, H - 1), 18, outline=(0, 0, 0, 90), width=3)

    img = back
    for shadow in shadows:
        img.alpha_composite(shadow)
    for plank in planks:
        img.alpha_composite(plank)
    img.alpha_composite(frame)
    return img


THEMES = {
    "bath": dict(  # quintal: madeira rústica quente + fundo creme-sálvia
        wood=(166, 124, 82), wood_light=(214, 178, 132), wood_dark=(120, 84, 54),
        back_top=(250, 246, 234), back_bot=(232, 230, 210), trim=(143, 168, 132)),
    "groom": dict(  # salão de bairro: madeira clara + fundo menta
        wood=(196, 156, 108), wood_light=(232, 204, 160), wood_dark=(146, 110, 72),
        back_top=(236, 248, 242), back_bot=(214, 236, 226), trim=(128, 200, 176)),
    "dry": dict(  # espaço charme: madeira mel + fundo pêssego
        wood=(206, 148, 92), wood_light=(240, 196, 140), wood_dark=(156, 106, 60),
        back_top=(255, 240, 228), back_bot=(250, 220, 198), trim=(240, 168, 128)),
    "perfume": dict(  # spa/clínica: mármore claro + dourado + fundo lavanda
        wood=(232, 226, 238), wood_light=(250, 248, 252), wood_dark=(196, 186, 210),
        back_top=(244, 240, 250), back_bot=(228, 220, 240), trim=(201, 162, 39)),
    "style": dict(  # ateliê/boutique: rosewood + blush + dourado
        wood=(176, 116, 116), wood_light=(222, 172, 168), wood_dark=(130, 82, 84),
        back_top=(252, 238, 240), back_bot=(244, 220, 226), trim=(201, 162, 39)),
    "unit": dict(  # fallback neutro (madeira clara + fundo creme)
        wood=(186, 146, 104), wood_light=(226, 196, 152), wood_dark=(138, 102, 66),
        back_top=(250, 246, 236), back_bot=(236, 230, 216), trim=None),
}


def qa() -> int:
    """Confere que há tábua opaca exatamente nas frações onde o canvas ancora as
    pranchas (topo = PLANK0_FRAC + i*passo) — é isso que apoia as ferramentas."""
    import numpy as np
    errors = []
    tops = list(PLANK_TOPS) + [BOTTOM_TOP]
    for service in THEMES:
        path = OUT / f"shelf_{service}.png"
        if not path.exists():
            errors.append(f"{service}: arte ausente {path.name}")
            continue
        a = np.array(Image.open(path).convert("RGBA"))
        if a[:, :, 3].max() == 0:
            errors.append(f"{service}: arte totalmente transparente")
            continue
        x0, x1 = int(SIDE_W) + 8, int(W - SIDE_W) - 8
        for i, y in enumerate(tops):
            band = a[int(y) + 4 : int(y) + int(PLANK_LIP + PLANK_FACE) - 2, x0:x1, 3]
            if band.size == 0 or (band > 200).mean() < 0.9:
                errors.append(f"{service}: prancha {i} sem tábua opaca em y={y:.0f}")
    for e in errors:
        print(f"ERRO: {e}")
    print(f"qa estantes: {len(errors)} erros")
    return 1 if errors else 0


def main() -> int:
    qa_only = "--qa-only" in sys.argv
    for service, theme in THEMES.items():
        shelf = build_shelf(theme)
        if not qa_only:
            shelf.save(OUT / f"shelf_{service if service != 'unit' else 'unit'}.png")
        print(f"shelf_{service}: {shelf.size} alpha={shelf.getchannel('A').getbbox()}")
    if "--qa" in sys.argv or qa_only:
        return qa()
    return 0


if __name__ == "__main__":
    sys.exit(main())
