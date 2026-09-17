#!/usr/bin/env python3
"""Simulador determinístico da economia early-game. Sem dependências externas."""
from __future__ import annotations
import argparse, csv, math
from dataclasses import dataclass

@dataclass
class Config:
    reward: float = 12.0
    perfect_rate: float = 0.55
    service_seconds: float = 14.0
    cost_base: float = 25.0
    cost_growth: float = 1.18
    income_growth: float = 1.15

def quality_mult(rate: float) -> float:
    return rate * 1.5 + (1-rate) * 1.15

def simulate(cfg: Config, levels: int = 20):
    elapsed = 0.0
    coins = 0.0
    rows = []
    for level in range(levels):
        cost = math.ceil(cfg.cost_base * cfg.cost_growth**level)
        income = cfg.reward * cfg.income_growth**level * quality_mult(cfg.perfect_rate)
        services = math.ceil(max(0, cost-coins) / income)
        earned = services * income
        elapsed += services * cfg.service_seconds
        coins += earned-cost
        rows.append((level+1, cost, round(income,2), services, round(elapsed/60,2), round(coins,2)))
    return rows

def main():
    p=argparse.ArgumentParser(); p.add_argument('--levels',type=int,default=20); p.add_argument('--csv')
    a=p.parse_args(); rows=simulate(Config(),a.levels)
    header=['upgrade_level','cost','avg_reward','services_to_buy','cumulative_minutes','coins_after']
    if a.csv:
        with open(a.csv,'w',newline='',encoding='utf-8') as f: csv.writer(f).writerows([header,*rows])
    else:
        print(','.join(header)); [print(','.join(map(str,r))) for r in rows]
if __name__=='__main__': main()
