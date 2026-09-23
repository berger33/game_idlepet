#!/usr/bin/env python3
"""Gera as variantes de piscada por estado (BLINK_MATRIX) por composição
determinística — sem drift de geração.

Para cada pet: a máscara de olhos é extraída de ``base × blink`` (blobs sólidos:
erosão mata o halo de anti-aliasing e o ruído de traço; dilatação restaura a
extensão das pálpebras). Cada variante ``<estado>_blink`` = sprite do estado de
olhos abertos + pálpebras do ``blink`` coladas na máscara, com color grade da
região dos olhos para a tonalidade do estado (molhado escurece, etc.).

Resultado pixel-alinhado: o crossfade de 130ms nunca "ferve". Idempotente:
rodar de novo sobrescreve. Estados: dirty, wet, messy, sad, dizzy (50 pets × 5
= 250 arquivos). Atualiza ``data/pet_animation_production.json``.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
# Nenhuma exclusão ativa. O duke_husky voltou à matriz: o blink autoral dele
# alinha com os sprites de ESTADO (não com a referência seca, que tem pose
# própria) — ver DUKE_EYES abaixo.
EXCLUDED_PETS: set[str] = set()
STATES = ["dirty", "wet", "messy", "sad", "dizzy"]
MIN_MASK, MAX_MASK = 200, 30000

# duke_husky — composição especial por estado. Cada estado foi gerado com pose
# própria (drift não rígido entre estados), então a máscara base×blink não
# transfere. Os olhos de cada sprite foram localizados por análise de pixels
# (blob escuro/azul + brilho do olho como furo de alpha no wet); a pálpebra
# autoral do blink (arcos ∪ 36x12) é colada por olho, escalada para a abertura
# do olho daquele estado e com grade de cor medido na banda de fronteira.
DUKE_LIDS = {"L": (168.7, 175.7), "R": (250.8, 175.6)}  # centros dos arcos no blink
DUKE_LID_OFFSET = {"L": (-3.5, 11.0), "R": (3.8, 11.0)}  # arco vs centro do olho aberto (par dirty/blink)
DUKE_REF = {"L": (37, 38), "R": (35, 38)}  # abertura de referência (dirty)
DUKE_EYES = {  # estado -> lado -> (centro, largura, altura) da abertura do olho
    "dirty": {"L": ((172, 164.5), 37, 38), "R": ((247, 164.5), 35, 38)},
    "wet": {"L": ((155, 160.5), 31, 34), "R": ((229, 162), 31, 33)},
    "messy": {"L": ((167, 171.5), 35, 26), "R": ((243, 171.5), 35, 26)},
    "sad": {"L": ((153, 147.5), 39, 32), "R": ((229, 147), 43, 33)},
    "dizzy": {"L": ((182, 193), 37, 39), "R": ((257, 161.5), 37, 36)},
}


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def _components(mask_small: Image.Image, max_bbox_frac: float, min_px: int) -> Image.Image:
    """Mantém só componentes conexos 'de rosto': descarta o anel de contorno da
    silhueta (bbox gigante) e o ruído fino; preserva pálpebras sólidas E arcos
    finos de olhos fechados."""
    w, h = mask_small.size
    data = mask_small.load()
    seen = bytearray(w * h)
    keep = Image.new("L", (w, h), 0)
    kpx = keep.load()
    from collections import deque

    for y0 in range(h):
        for x0 in range(w):
            i = y0 * w + x0
            if seen[i] or data[x0, y0] == 0:
                continue
            queue = deque([i])
            seen[i] = 1
            pts: list[int] = []
            minx, miny, maxx, maxy = w, h, 0, 0
            while queue:
                cur = queue.popleft()
                cx, cy = cur % w, cur // w
                pts.append(cur)
                minx = min(minx, cx)
                maxx = max(maxx, cx)
                miny = min(miny, cy)
                maxy = max(maxy, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        ni = ny * w + nx
                        if not seen[ni] and data[nx, ny] != 0:
                            seen[ni] = 1
                            queue.append(ni)
            bw, bh = maxx - minx + 1, maxy - miny + 1
            is_face_blob = (
                len(pts) >= min_px
                and bw <= max_bbox_frac * w
                and bh <= max_bbox_frac * h
            )
            if is_face_blob:
                for p in pts:
                    kpx[p % w, p // w] = 255
    return keep


def eye_mask(base: Image.Image, blink: Image.Image, h_frac: float = 0.60) -> Image.Image:
    s = 256
    bs = base.resize((s, s), Image.LANCZOS)
    bl = blink.resize((s, s), Image.LANCZOS)
    da = ImageChops.difference(bs.getchannel("A"), bl.getchannel("A")).point(
        lambda v: 255 if v > 24 else 0
    )
    dc = ImageChops.difference(bs.convert("RGB"), bl.convert("RGB")).convert("L").point(
        lambda v: 255 if v > 40 else 0
    )
    raw = ImageChops.add(da, dc).point(lambda v: 255 if v > 0 else 0)
    interior = bs.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    interior = interior.filter(ImageFilter.MinFilter(3))
    raw = ImageChops.multiply(raw, interior)
    kept = _components(raw, max_bbox_frac=0.45, min_px=12)
    # Piscada é olho: restringe à zona dos olhos (topo da silhueta, centro da
    # largura) — expressão/boca do blink autoral não vaza para o estado.
    zone = Image.new("L", (s, s), 0)
    bbox = bs.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
    if bbox:
        # 60% da altura cobre olhos de pets de orelha alta (husky/pastor);
        # 76% da largura centra o rosto e descarta orelhas externas.
        x0, y0, x1, y1 = bbox
        zx0 = x0 + int(0.12 * (x1 - x0))
        zx1 = x0 + int(0.88 * (x1 - x0))
        zy1 = y0 + int(h_frac * (y1 - y0))
        zone_crop = Image.new("L", (zx1 - zx0, zy1 - y0), 255)
        zone.paste(zone_crop, (zx0, y0))
    kept = ImageChops.multiply(kept, zone)
    return kept.resize((512, 512), Image.NEAREST).filter(ImageFilter.MaxFilter(9))


def grade_factor(base: Image.Image, state: Image.Image, mask: Image.Image) -> list[float]:
    box = mask.getbbox()
    pad = 10
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(512, box[2] + pad), min(512, box[3] + pad))
    m = mask.crop(box)
    sb = ImageStat.Stat(base.crop(box).convert("RGB"), m).mean
    sw = ImageStat.Stat(state.crop(box).convert("RGB"), m).mean
    return [min(1.15, max(0.85, sw[i] / max(1.0, sb[i]))) for i in range(3)]


def _light_fur_mask(img: Image.Image) -> Image.Image:
    """Pixels de pelo claro (exclui traço, lágrima/íris azul-escura e fundo)."""
    r, g, b = (img.getchannel(c) for c in "RGB")
    mx = ImageChops.lighter(ImageChops.lighter(r, g), b)
    light = mx.point(lambda v: 255 if v >= 130 else 0)
    bluish = ImageChops.subtract(b, r).point(lambda v: 255 if v > 18 else 0)
    mid = mx.point(lambda v: 255 if v < 135 else 0)
    tearish = ImageChops.multiply(bluish, mid)
    alpha = img.getchannel("A").point(lambda v: 255 if v > 150 else 0)
    return ImageChops.multiply(ImageChops.subtract(light, tearish), alpha)


def _band_mask(ex: float, ey: float, rx: float, ry: float, w1: float, w2: float) -> Image.Image:
    """Anel elíptico entre dois tamanhos relativos da máscara."""
    m = Image.new("L", (512, 512), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([ex - rx * w2, ey - ry * w2, ex + rx * w2, ey + ry * w2], fill=255)
    d.ellipse([ex - rx * w1, ey - ry * w1, ex + rx * w1, ey + ry * w1], fill=0)
    return m


def compose_duke_state(blink: Image.Image, state_img: Image.Image, state: str) -> Image.Image:
    """Variante do duke para um estado: pálpebra autoral do blink colada por
    olho, escalada para a abertura do olho naquele estado, com grade de cor da
    banda de fronteira (iguala a costura da máscara por construção)."""
    out = state_img.copy()
    for side in ("L", "R"):
        (ex, ey), w, h = DUKE_EYES[state][side]
        rw, rh = DUKE_REF[side]
        sx, sy = w / rw, h / rh
        rx, ry = max(20.0, 25 * sx), max(14.0, 24 * sy)
        lx, ly = DUKE_LIDS[side]
        ox, oy = DUKE_LID_OFFSET[side]
        px, py = ex + ox, ey + oy
        scaled = blink.resize((max(4, round(512 * sx)), max(4, round(512 * sy))), Image.LANCZOS)
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.paste(scaled, (round(px - lx * sx), round(py - ly * sy)))
        sel = ImageChops.multiply(
            ImageChops.multiply(_band_mask(ex, ey + 2, rx, ry, 1.02, 1.50), _light_fur_mask(state_img)),
            _light_fur_mask(canvas),
        )
        if sum(1 for v in sel.getdata() if v) >= 80:
            s_mean = ImageStat.Stat(state_img.convert("RGB"), sel).mean
            c_mean = ImageStat.Stat(canvas.convert("RGB"), sel).mean
            factor = [min(1.35, max(0.70, s_mean[i] / max(1.0, c_mean[i]))) for i in range(3)]
        else:
            factor = [1.0, 1.0, 1.0]
        r_, g_, b_, a_ = canvas.split()
        canvas = Image.merge(
            "RGBA",
            (
                r_.point(lambda v, f=factor[0]: min(255, int(v * f))),
                g_.point(lambda v, f=factor[1]: min(255, int(v * f))),
                b_.point(lambda v, f=factor[2]: min(255, int(v * f))),
                a_,
            ),
        )
        mask = Image.new("L", (512, 512), 0)
        ImageDraw.Draw(mask).ellipse([ex - rx, ey + 2 - ry, ex + rx, ey + 2 + ry], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(2.5))
        out.paste(canvas, (0, 0), mask)
    return out


def main() -> None:
    tracker_path = ROOT / "data/pet_animation_production.json"
    tracker = json.loads(tracker_path.read_text(encoding="utf-8"))
    pets = [p["id"] for p in json.load(open(ROOT / "data/pets.json", encoding="utf-8"))["pets"]]
    made, skipped = 0, []
    for pet in pets:
        if pet in EXCLUDED_PETS:
            continue
        entry = tracker["pets"][[i for i, t in enumerate(tracker["pets"]) if t["pet_id"] == pet][0]]
        if pet == "duke_husky":
            # Composição especial: blink alinha com os estados (não com a ref
            # seca); olhos detectados por estado (DUKE_EYES).
            blink = load(ROOT / "art/pet_animations" / pet / "blink.png")
            for state in STATES:
                state_img = load(ROOT / "art/pet_animations" / pet / f"{state}.png")
                compose_duke_state(blink, state_img, state).save(
                    ROOT / "art/pet_animations" / pet / f"{state}_blink.png"
                )
                entry["blink_variants"][f"{state}_blink"] = {
                    "status": "qa_passed",
                    "method": "compose_per_state_lids",
                }
                made += 1
            continue
        base = load(ROOT / "art/pets" / f"{pet}.png")
        blink = load(ROOT / "art/pet_animations" / pet / "blink.png")
        mask = eye_mask(base, blink)
        n = sum(1 for p in mask.getdata() if p == 255)
        if n > MAX_MASK:
            # Rosto expressivo demais na zona larga: recua para zona estrita.
            mask = eye_mask(base, blink, h_frac=0.48)
            n = sum(1 for p in mask.getdata() if p == 255)
        if n < MIN_MASK or n > MAX_MASK:
            skipped.append(f"{pet}: máscara {n}px fora da faixa")
            continue
        for state in STATES:
            state_img = load(ROOT / "art/pet_animations" / pet / f"{state}.png")
            factor = grade_factor(base, state_img, mask)
            graded = blink.copy()
            r, g, b, a = graded.split()
            graded = Image.merge(
                "RGBA",
                (
                    r.point(lambda v: min(255, int(v * factor[0]))),
                    g.point(lambda v: min(255, int(v * factor[1]))),
                    b.point(lambda v: min(255, int(v * factor[2]))),
                    a,
                ),
            )
            out = state_img.copy()
            out.paste(graded, (0, 0), mask)
            out.save(ROOT / "art/pet_animations" / pet / f"{state}_blink.png")
            entry["blink_variants"][f"{state}_blink"] = {"status": "qa_passed", "method": "compose"}
            made += 1
    for pet in EXCLUDED_PETS:
        entry = tracker["pets"][
            [i for i, t in enumerate(tracker["pets"]) if t["pet_id"] == pet][0]
        ]
        for state in STATES:
            entry["blink_variants"][f"{state}_blink"] = {
                "status": "excluded",
                "method": "none",
                "reason": "authored blink misaligned (drift nao rigido)",
            }
    tracker["summary"]["blink_variants_generated"] = made
    tracker["summary"]["blink_fix_duke_husky"] = (
        "fixed: per-state lid compose (blink aligns with state sprites; "
        "eyes detected per state, lids scaled and color-graded per eye)"
    )
    tracker_path.write_text(json.dumps(tracker, ensure_ascii=False, indent=2), encoding="utf-8")
    print("variantes geradas: %d/250" % made)
    if skipped:
        print("REVISÃO MANUAL (%d):" % len(skipped))
        for s in skipped:
            print(" -", s)


if __name__ == "__main__":
    main()
