#!/usr/bin/env python3
"""Upsert de chaves nas 3 tabelas de localização (pt_BR, en_US, es_ES).

Uso (como módulo):
    from loc_upsert import upsert
    upsert({"KEY": ("pt", "en", "es"), ...})

Mantém a ordem existente, acrescenta chaves novas ao fim, normaliza CRLF→LF e
faz o quoting CSV só quando necessário (vírgula, aspas ou quebra de linha).
"""
from __future__ import annotations

import csv
import io
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGS = ("pt_BR", "en_US", "es_ES")


def _rows(path: Path) -> list[list[str]]:
    with path.open(encoding="utf-8", newline="") as f:
        return [r for r in csv.reader(f) if r]


def _write(path: Path, rows: list[list[str]]) -> None:
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    for row in rows:
        writer.writerow(row)
    path.write_text(buf.getvalue(), encoding="utf-8", newline="\n")


def upsert(entries: dict[str, tuple[str, str, str]]) -> None:
    for index, lang in enumerate(LANGS):
        path = ROOT / "data" / "localization" / f"{lang}.csv"
        rows = _rows(path)
        by_key = {row[0]: row for row in rows}
        for key, values in entries.items():
            value = values[index]
            if key in by_key:
                by_key[key][1:] = [value]
            else:
                rows.append([key, value])
        _write(path, rows)


def remove(keys: list[str]) -> None:
    for lang in LANGS:
        path = ROOT / "data" / "localization" / f"{lang}.csv"
        rows = [r for r in _rows(path) if r[0] not in keys]
        _write(path, rows)


if __name__ == "__main__":
    for lang in LANGS:
        print(lang, len(_rows(ROOT / "data" / "localization" / f"{lang}.csv")) - 1, "chaves")
