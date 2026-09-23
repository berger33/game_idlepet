# Auditoria de Progressão e Balanceamento

Data: 2026-09-20 · Escopo: riqueza crescente do início ao fim de jogo
(local humilde + raças baratas → locais bonitos + raças caras/bonitas),
equilíbrio econômico e coerência de dados. QA programático (sem inspeção
visual subjetiva): fontes únicas `data/*.json`, `autoload/*.gd`,
`tools/economy_sim.py`, `tools/career_sim.py`.

## 1. Contraste início ↔ fim (o que o jogador vê)

| | Início (capítulo 1) | Fim (capítulo 10) |
|---|---|---|
| Local | Banheiro de Quintal — banheira rústica de madeira/metal | Império Pet Brasil — banheira de porcelana com pés dourados |
| Placa da sala | "BANHO & ESPUMA ★ BANHEIRO DE QUINTAL ★" | "BANHO & ESPUMA ★ IMPÉRIO PET BRASIL ★" |
| Clientes | 4 vira-latas comuns (tips 1,00–1,20) | 1 lendário (tip 4,50) |
| Gorjeta típica | ~14 moedas/serviço | ~61+ moedas/serviço (antes de VIP/prestígio) |

A progressão do local é exibida em três camadas: (a) nome do capítulo na
placa de título (`PetShopCanvas` + `GameState.establishment_tier`),
(b) arte da banheira por capítulo (`StationArt`: rústica no tier 1,
porcelana do tier 2 em diante), (c) catálogo de clientes por nível.

## 2. Capítulos × clientes (career_track.json × pets.json)

| Capítulo | Nível | Nome | Pets | Tips | Raridades |
|---:|---|---|---:|---|---|
| 1 | 1–7 | Banheiro de Quintal | 4 | 1,00–1,20 | 4 comuns |
| 2 | 8–17 | Pet Shop de Bairro | 7 | 1,25–1,40 | 6 incomuns, 1 comum |
| 3 | 18–29 | Clínica Pequena | 6 | 1,42–1,59 | 3 raros, 3 incomuns |
| 4 | 30–44 | Clínica Moderna | 7 | 1,65–2,10 | 4 raros, 2 épicos, 1 incomum |
| 5 | 45–61 | Centro Veterinário | 8 | 2,11–2,30 | 5 raros, 2 épicos, 1 incomum |
| 6 | 62–79 | Hospital Animal | 6 | 2,40–2,65 | 5 épicos, 1 raro |
| 7 | 80–97 | Rede Regional | 5 | 2,80–3,52 | 3 épicos, 2 lendários |
| 8 | 98–109 | Rede Nacional | 4 | 3,60–3,81 | 4 lendários |
| 9 | 110–119 | Instituto de Pesquisa | 2 | 4,00–4,01 | 2 lendários |
| 10 | 120 | Império Pet Brasil | 1 | 4,50 | 1 lendário |

Serviços destravam em 1/3/5/7/10 (bath/groom/dry/perfume/style) — o jogador
experimenta os cinco serviços ainda nos dois primeiros capítulos, e a
riqueza cresce pelo catálogo de clientes e capítulos, não por gates novos.

## 3. Economia (sims determinísticos)

- `tools/economy_sim.py` (custo 25×1,18^N vs receita 12×1,075^N×qualidade):
  upgrade 1 custa 25 (~2 serviços), upgrade 20 custa 581 (~9 serviços);
  20 upgrades em ~20,5 min ativos; saldo sempre positivo (mín. 6 moedas).
  Sem becos sem saída nem explosão de receita.
- `tools/career_sim.py`: nível 120 em ~54–62 horas ativas — cauda longa
  saudável para idle; prestígio (nível 15) reinicia com +10%/nível.
- Multiplicadores: gorjetas esperadas ×1,14; VIP 12% ×2 (teto 35%);
  bairro +3% VIP/+2% gorjeta por tier; combo +2,5%/stack (teto ×20);
  afeto +0,5%/ponto (teto +25%).

## 4. Achados e correções aplicadas

1. **17 inversões de `base_tip` × `unlock_level`** (ex.: Lola nv42 pagava
   1,93 enquanto Sol nv36 pagava 1,90 — ok — mas Kiara nv90 pagava 3,00
   abaixo de Tupa nv86 3,50). Corrigido por envelope monótono (+0,01 sobre
   o máximo anterior): 19 pets ajustados. Regra agora exigida por
   `tools/validate_project.py` ("cliente avançado nunca paga menos").
2. **`data/establishments.json` removido** — rascunho legado (8 tiers por
   moedas, "sistemas" inexistentes no jogo) sem nenhum leitor em código;
   a fonte viva é `career_track.json` (10 tiers por nível, já validada).
   Elimina a discrepância dupla apontada em `docs/ANALISE_COMPLETA.md`.
3. **`data/economy_curves.json` alinhado ao runtime**: `upgrade_cost_base`
   10 → 25 (o jogo usa `RemoteConfig.gd` = 25; sims idem). Demais valores
   (1,075/1,18/0,5/2h/24h, qualidade 0/1,15/1,5, combo 0,025/×20) já
   batiam com `Economy.gd`/`RemoteConfig.gd`.
4. **Progressão visível na cena** (entrega desta auditoria): placa de
   título exibe o capítulo do estabelecimento; banheira troca por capítulo;
   feed `Main._configure_current_service → world.establishment_tier`.

## 5. Recomendações (não bloqueantes)

- Fundos por capítulo (além da banheira/placa) exigiriam arte nova por
  capítulo×serviço — hoje o fundo varia por serviço, o capítulo aparece na
  placa/banheira. Avaliar só se o playtest pedir mais contraste visual.
- Paciência (27–70) não é monótona por nível — proposital (variedade de
  dificuldade dentro do capítulo); não alterar.
- Fonte OFL do título segue pendente de gate de empacotamento (ver
  `art/ASSET_MANIFEST.md`).
