#!/usr/bin/env python3
"""Simula a duração da carreira sem usar espera artificial ou anúncios."""
from __future__ import annotations
import csv
from pathlib import Path

MAX_LEVEL = 120
AVERAGE_XP = 13.0  # 60% Perfect (15 XP), 40% Good (10 XP)
SERVICE_SECONDS = 14.5
MANAGEMENT_OVERHEAD = 0.10


def xp_for_level(level: int) -> int:
    return 50 + (level - 1) * 25


def simulate() -> list[dict[str, float]]:
    total_xp = 0
    rows: list[dict[str, float]] = []
    for level in range(1, MAX_LEVEL):
        total_xp += xp_for_level(level)
        services = total_xp / AVERAGE_XP
        mechanical_hours = services * SERVICE_SECONDS / 3600.0
        active_hours = mechanical_hours * (1.0 + MANAGEMENT_OVERHEAD)
        rows.append({
            "reached_level": level + 1,
            "cumulative_xp": total_xp,
            "estimated_services": round(services, 1),
            "estimated_active_hours": round(active_hours, 2),
        })
    return rows


def main() -> None:
    rows = simulate()
    output = Path("docs/career_50h.csv")
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    expert_hours = rows[-1]["cumulative_xp"] / 15.0 * SERVICE_SECONDS / 3600.0 * 1.10
    print(f"level 120 average: {rows[-1]['estimated_active_hours']:.2f} active hours")
    print(f"level 120 expert: {expert_hours:.2f} active hours")


if __name__ == "__main__":
    main()
