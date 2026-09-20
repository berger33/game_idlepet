#!/usr/bin/env python3
"""Normaliza as artes geradas de mobiliário para assets RGBA do jogo.

Pipeline por peça:
  1. Remove o fundo branco por flood-fill a partir das bordas (o branco
     interno da arte permanece opaco).
  2. Recorta o bounding box do objeto.
  3. Redimensiona (LANCZOS) para a caixa-alvo do canvas — ancoragem por peça.
  4. Mede geometria interna (aro frontal da banheira, pranchas da estante) e
     imprime as constantes de layout para o StationArt.gd/service_layouts.json.

Uso: python3 tools/normalize_station_art.py [--qa-only]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
PREVIEW = REPO / ".preview"
OUT_DIR = REPO / "art" / "stations"

# Canvas do jogo: 1080x1920; surface = pet_position.y = 1160 (pés do pet).
SURFACE = 1160.0
CX = 540.0

# (nome do arquivo gerado, nome do asset, caixa-alvo (x0, y0, x1, y1)).
# As âncoras preservam o posicionamento validado da arte vetorial:
#   - banheiras: aro frontal cruza o pet em SURFACE-36; largura 440.
#   - mesas/pedestal/otomana: topo da arte em SURFACE (pet em pé sobre).
#   - estante: largura 216 centrada em 920 (ferramentas ficam em x=910).
TARGETS = {
    "gen_bathtub_rustic": ("station_bathtub_rustic.png", (320, 0, 760, 0), "bathtub_rustic"),
    "gen_bathtub_spa": ("station_bathtub_spa.png", (320, 0, 760, 0), "bathtub_spa"),
    "gen_groom_table": ("station_groom_table.png", (340, 1160, 740, 0), "top"),
    "gen_drying_table": ("station_drying_table.png", (330, 1160, 750, 0), "top"),
    "gen_spa_pedestal": ("station_spa_pedestal.png", (390, 1160, 690, 0), "top"),
    "gen_ottoman": ("station_ottoman.png", (370, 1160, 710, 0), "top"),
    "gen_shelf_unit": ("shelf_unit.png", (812, 568, 1028, 0), "shelf"),
}

# Linha onde o aro frontal da banheira deve cruzar o pet (canvas).
RIM_LINE = SURFACE - 36.0  # 1124
# Perna do pet “na água”: banda translúcida desenhada na frente do pet.
FRONT_WATER_TOP = RIM_LINE
FRONT_WATER_BOTTOM = RIM_LINE + 26.0


def _dilate(mask: np.ndarray, iters: int) -> np.ndarray:
	out = mask.copy()
	h, w = out.shape
	for _ in range(iters):
		grown = out.copy()
		grown[1:, :] |= out[:-1, :]
		grown[:-1, :] |= out[1:, :]
		grown[:, 1:] |= out[:, :-1]
		grown[:, :-1] |= out[:, 1:]
		out = grown
	return out


def flood_white_to_alpha(im: Image.Image) -> Image.Image:
	"""Flood-fill de branco a partir das bordas -> transparente (BFS).

	O contorno escuro da arte é "parede": dilatamos os pixels claramente do
	objeto (escuros/saturados) para selar micro-falhas do contorno antes do
	flood — sem isso o flood atravessa e come partes brancas do próprio
	objeto (ex.: porcelana da banheira)."""
	a = np.array(im.convert("RGBA"))
	h, w = a.shape[:2]
	rgb = a[..., :3].astype(int)
	near_white = (rgb.min(2) > 228) & ((rgb.max(2) - rgb.min(2)) < 14)
	wall = (rgb.min(2) < 200) | ((rgb.max(2) - rgb.min(2)) > 30)
	wall = _dilate(wall, 4)
	floodable = near_white & ~wall
	visited = np.zeros((h, w), bool)
	stack: list[tuple[int, int]] = []
	for x in range(w):
		for y in (0, h - 1):
			if floodable[y, x] and not visited[y, x]:
				visited[y, x] = True
				stack.append((y, x))
	for y in range(h):
		for x in (0, w - 1):
			if floodable[y, x] and not visited[y, x]:
				visited[y, x] = True
				stack.append((y, x))
	while stack:
		y, x = stack.pop()
		if y > 0 and floodable[y - 1, x] and not visited[y - 1, x]:
			visited[y - 1, x] = True
			stack.append((y - 1, x))
		if y < h - 1 and floodable[y + 1, x] and not visited[y + 1, x]:
			visited[y + 1, x] = True
			stack.append((y + 1, x))
		if x > 0 and floodable[y, x - 1] and not visited[y, x - 1]:
			visited[y, x - 1] = True
			stack.append((y, x - 1))
		if x < w - 1 and floodable[y, x + 1] and not visited[y, x + 1]:
			visited[y, x + 1] = True
			stack.append((y, x + 1))
	# Suaviza a franja: pixels semi-brancos ADJACENTES ao fundo ganham alpha
	# proporcional à distância do branco puro (remove halo). Regiões brancas
	# enclausuradas (interior do objeto) permanecem opacas — são arte.
	dist = 255 - rgb.min(2)
	alpha = a[..., 3].astype(float)
	boundary = _dilate(visited, 2)
	fringe = near_white & boundary & ~wall
	alpha[fringe] = np.clip(dist[fringe] * 1.6, 0, 255)
	alpha[visited] = 0
	a[..., 3] = alpha.astype(np.uint8)
	return Image.fromarray(a)


def trim(im: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    a = np.array(im)
    opaque = a[..., 3] > 12
    rows = np.where(opaque.sum(1) > a.shape[1] * 0.01)[0]
    cols = np.where(opaque.sum(0) > a.shape[0] * 0.01)[0]
    y0, y1, x0, x1 = rows.min(), rows.max(), cols.min(), cols.max()
    return im.crop((x0, y0, x1 + 1, y1 + 1)), (x0, y0, x1, y1)


def _enclosed_holes_frac(a: np.ndarray) -> float:
	"""Fração de pixels transparentes ENCLAUSURADOS por pixels opacos
	(buracos internos indesejados no corpo do mobiliário)."""
	h, w = a.shape[:2]
	transp = a[..., 3] < 50
	visited = np.zeros((h, w), bool)
	stack: list[tuple[int, int]] = []
	for x in range(w):
		for y in (0, h - 1):
			if transp[y, x] and not visited[y, x]:
				visited[y, x] = True
				stack.append((y, x))
	for y in range(h):
		for x in (0, w - 1):
			if transp[y, x] and not visited[y, x]:
				visited[y, x] = True
				stack.append((y, x))
	while stack:
		y, x = stack.pop()
		for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
			if 0 <= ny < h and 0 <= nx < w and transp[ny, nx] and not visited[ny, nx]:
				visited[ny, nx] = True
				stack.append((ny, nx))
	return float((transp & ~visited).mean())


def measure_rim_frac(a: np.ndarray) -> float:
    """Fração da altura onde começa o ARO FRONTAL: primeira linha larga o
    bastante (>=85% da largura máxima) e sólida (buracos <6% do vão) — a
    elipse da borda traseira e a torneira acima dela ficam ATRÁS do pet."""
    opaque = a[..., 3] > 100
    h, w = a.shape[:2]
    widths = opaque.sum(1)
    maxw = float(widths.max())
    for y in range(h):
        xs = np.where(opaque[y])[0]
        if len(xs) == 0 or widths[y] < 0.85 * maxw:
            continue
        span = int(xs.max()) - int(xs.min()) + 1
        if 1.0 - float(widths[y]) / span < 0.06:
            return float(y) / float(h)
    return 0.0


def measure_planks_fullres(im: Image.Image) -> list[float]:
    """Pranchas medidas na arte em resolução original: bandas Curtas e grossas
    de madeira (as seções altas entre pranchas são o painel traseiro)."""
    a = np.array(im)
    h, w = a.shape[:2]
    rgb = a[..., :3].astype(int)
    op = a[..., 3] > 40
    wood = (rgb[..., 0] > 110) & (rgb[..., 0] < 240) & (rgb[..., 0] - rgb[..., 2] > 20) & (
        rgb[..., 1] - rgb[..., 2] > 8
    ) & op
    cov = wood.sum(1) / w
    band = cov > 0.22
    runs: list[tuple[int, int]] = []
    s = None
    for y in range(h):
        if band[y] and s is None:
            s = y
        elif not band[y] and s is not None:
            runs.append((s, y - 1))
            s = None
    if s is not None:
        runs.append((s, h - 1))
    # bandas de madeira com espessura entre 20px e 90px (pranchas ~33px,
    # trilhos do capitel ~47px também entram e são filtrados pelo passo 2)
    mids: list[float] = []
    for r0, r1 in runs:
        if 20 <= (r1 - r0 + 1) <= 90:
            mids.append((r0 + r1) / 2 / h)
    # passo 2: escolhe 5 centros (em ordem) com espaçamento uniforme.
    # Bandas de suporte decorativas intercalam as pranchas, então uma janela
    # deslizante simples não basta — testa todas as combinações de 5.
    import itertools

    best: list[float] = []
    best_score = 1e9
    for combo in itertools.combinations(mids, 5):
        gaps = [combo[k + 1] - combo[k] for k in range(4)]
        if min(gaps) < 0.05:
            continue  # bandas quase adjacentes = contorno+face da mesma prancha
        mean = sum(gaps) / 4
        score = max(abs(g - mean) / mean for g in gaps)
        if score < best_score:
            best_score = score
            best = list(combo)
    if best_score > 0.12:
        return []  # estrutura não confiável — mantém layout atual
    return best


def measure_planks(a: np.ndarray) -> list[float]:
    """Centros das pranchas (linhas de madeira largas) em fração da altura."""
    h, w = a.shape[:2]
    rgb = a[..., :3].astype(int)
    opaque = a[..., 3] > 40
    # madeira quente: R>B+30, R médio
    wood = (rgb[..., 0] > 120) & (rgb[..., 0] < 235) & (rgb[..., 0] > rgb[..., 2] + 25) & (
        rgb[..., 1] > 80
    ) & opaque
    cov = wood.sum(1) / w
    band = cov > 0.30
    runs: list[tuple[int, int]] = []
    s = None
    for y in range(h):
        if band[y] and s is None:
            s = y
        elif not band[y] and s is not None:
            runs.append((s, y - 1))
            s = None
    if s is not None:
        runs.append((s, h - 1))
    # pranchas = bandas grossas (>= 3.5% da altura) e espaçadas
    thick = [(r0, r1) for r0, r1 in runs if (r1 - r0 + 1) >= max(6, h * 0.012)]
    # agrupa bandas quase adjacentes (contorno + face)
    merged: list[list[int]] = []
    for r0, r1 in thick:
        if merged and r0 - merged[-1][1] <= h * 0.012:
            merged[-1][1] = r1
        else:
            merged.append([r0, r1])
    planks = []
    for r0, r1 in merged:
        if r1 - r0 + 1 >= h * 0.012:
            planks.append((r0 + r1) / 2 / h)
    return planks


def build(name: str, qa_only: bool) -> dict:
    out_name, (x0, y_top, x1, _), anchor = TARGETS[name]
    src = PREVIEW / f"{name}.png"
    im = flood_white_to_alpha(Image.open(src))
    im, bbox = trim(im)
    aw, ah = im.size
    target_w = x1 - x0
    target_h = round(target_w * ah / aw)
    scaled = im.resize((target_w, target_h), Image.LANCZOS)
    arr = np.array(scaled)

    info: dict = {
        "name": out_name,
        "art_size": (aw, ah),
        "box": [x0, y_top, x1, y_top + target_h],
        "internal_holes": _enclosed_holes_frac(arr),
    }

    if anchor in ("bathtub_rustic", "bathtub_spa"):
        rim = measure_rim_frac(arr)
        # ancora o ARO FRONTAL em RIM_LINE em vez do topo da caixa
        box_y = round(RIM_LINE - rim * target_h)
        info["rim_frac"] = round(rim, 4)
        info["box"] = [x0, box_y, x1, box_y + target_h]
        info["slice_src"] = [round(rim, 4)]
    elif anchor == "shelf":
        planks = measure_planks_fullres(im)
        info["plank_fracs"] = [round(p, 4) for p in planks]
        info["box"] = [x0, y_top, x1, y_top + target_h]

    if not qa_only:
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        out = OUT_DIR / out_name
        Image.fromarray(arr).save(out, optimize=True)
        info["saved"] = str(out.relative_to(REPO))
    return info


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--qa-only", action="store_true")
    args = ap.parse_args()
    results = [build(name, args.qa_only) for name in TARGETS]
    print(json.dumps(results, indent=1))

    # Deriva shelf_y (data segue a arte): prancha_top = shelf_y + PLANK_DROP(34)
    shelf = [r for r in results if "plank_fracs" in r][0]
    bx0, by0, bx1, by1 = shelf["box"]
    h = by1 - by0
    shelf_y = []
    for frac in shelf["plank_fracs"][:5]:
        plank_top = by0 + frac * h
        shelf_y.append(round(plank_top - 34.0))
    print("shelf_y sugerido:", shelf_y)
    return 0


if __name__ == "__main__":
    sys.exit(main())
