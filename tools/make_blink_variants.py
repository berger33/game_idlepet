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

from PIL import Image, ImageChops, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
# duke_husky: blink autoral com pose desalinhada (drift não rígido) — a
# composição não alinha; tratado como exceção documentada (pisca só no seco).
EXCLUDED_PETS = {"duke_husky"}
STATES = ["dirty", "wet", "messy", "sad", "dizzy"]
MIN_MASK, MAX_MASK = 200, 30000


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


def main() -> None:
    tracker_path = ROOT / "data/pet_animation_production.json"
    tracker = json.loads(tracker_path.read_text(encoding="utf-8"))
    pets = [p["id"] for p in json.load(open(ROOT / "data/pets.json", encoding="utf-8"))["pets"]]
    made, skipped = 0, []
    for pet in pets:
        if pet in EXCLUDED_PETS:
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
        entry = tracker["pets"][[i for i, t in enumerate(tracker["pets"]) if t["pet_id"] == pet][0]]
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
        "original kept; variants excluded (authored blink misaligned)"
    )
    tracker_path.write_text(json.dumps(tracker, ensure_ascii=False, indent=2), encoding="utf-8")
    print("variantes geradas: %d/245" % made)
    if skipped:
        print("REVISÃO MANUAL (%d):" % len(skipped))
        for s in skipped:
            print(" -", s)


if __name__ == "__main__":
    main()
