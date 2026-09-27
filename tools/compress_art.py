#!/usr/bin/env python3
"""Mede (e opcionalmente gera) versões WebP da arte do jogo.

Contexto — auditoria universal v2 (2026-09-27): os 851 PNGs versionados somam
~261 MB, sendo ~227 MB em `art/pet_animations` (810 frames de 512x512). É o
maior custo de download/instalação do build.

Duas alavancas, com riscos diferentes:

1. IMPORTAÇÃO (recomendado, já ativo): `project.godot -> [importer_defaults]`
   importa as texturas como Lossy (WebP q=0.85) e sem mipmaps. Não muda
   nenhum caminho `res://...png` no código e reduz o PACOTE exportado (Web/
   Android). Este script mede o ganho esperado.
2. REPO (opcional, mexe em paths): converter os PNGs para `.webp` de verdade
   reduz também o repositório, mas exige trocar todas as referências
   `.png` no código/cenas (`core/gameplay/*.gd`, `scenes/...`) — mantenha os
   PNGs como fonte enquanto a migração não for decidida.

Uso:
    python tools/compress_art.py                    # relatório (não escreve nada)
    python tools/compress_art.py --quality 0.8      # mede outra qualidade
    python tools/compress_art.py --write-webp /tmp/webp  # gera cópias p/ avaliar
    python tools/compress_art.py --json relatorio.json   # saída para dashboard
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - ambiente sem Pillow
    print("Pillow é necessário: pip install pillow", file=sys.stderr)
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art"


def human(num_bytes: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if num_bytes < 1024 or unit == "GB":
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024.0
    return f"{num_bytes:.1f} GB"


def collect(art_dir: Path) -> list[Path]:
    return sorted(p for p in art_dir.rglob("*.png") if p.is_file())


def measure(files: list[Path], quality: float, out_dir: Path | None) -> dict:
    rows = []
    total_png = 0
    total_webp = 0
    for path in files:
        total_png += path.stat().st_size
        if out_dir is None:
            import io

            buffer = io.BytesIO()
            with Image.open(path) as img:
                img.save(buffer, format="WEBP", quality=int(quality * 100),
                         method=4, lossless=False)
            webp_size = buffer.tell()
        else:
            target = out_dir / path.relative_to(ART).with_suffix(".webp")
            target.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(path) as img:
                img.save(target, format="WEBP", quality=int(quality * 100),
                         method=4, lossless=False)
            webp_size = target.stat().st_size
        total_webp += webp_size
        rows.append({
            "path": str(path.relative_to(ROOT)),
            "png": path.stat().st_size,
            "webp": webp_size,
        })
    rows.sort(key=lambda r: r["png"] - r["webp"], reverse=True)
    return {"png_bytes": total_png, "webp_bytes": total_webp, "rows": rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--quality", type=float, default=0.85)
    parser.add_argument("--write-webp", metavar="DIR", default=None,
                        help="gera cópias .webp no diretório indicado (para avaliação)")
    parser.add_argument("--json", metavar="ARQUIVO", default=None)
    parser.add_argument("--top", type=int, default=10)
    args = parser.parse_args()

    files = collect(ART)
    if not files:
        print("nenhum PNG encontrado em art/", file=sys.stderr)
        return 1

    out_dir = Path(args.write_webp).resolve() if args.write_webp else None
    result = measure(files, args.quality, out_dir)
    png, webp = result["png_bytes"], result["webp_bytes"]
    ratio = (png / webp) if webp else 0.0

    print(f"arte: {len(files)} PNGs | {human(png)}")
    print(f"webp q={int(args.quality * 100)}: {human(webp)} | ganho {ratio:.1f}x "
          f"(-{100.0 * (1 - webp / png):.1f}%)")
    print("\nmaiores ganhos absolutos:")
    for row in result["rows"][: args.top]:
        print(f"  {human(row['png'] - row['webp']):>10}  {row['path']}")
    if out_dir:
        print(f"\ncópias gravadas em {out_dir} (nada no repositório foi alterado)")
    else:
        print("\n(relatório apenas — use --write-webp DIR para gerar as cópias)")

    if args.json:
        Path(args.json).write_text(json.dumps(result, indent=2), encoding="utf8")
        print(f"json: {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
