# Álbum & Concurso da Capa — semanal com rivais (redesenho 2026-09-23)

> **Objetivo: retenção.** Toda semana (segunda → domingo) os passeios rendem **votos** para a *Capa da Revista Pets*. Três petshops rivais simulados sobem o placar ao longo da semana; no domingo a votação fecha e o resultado vira um **cartão de prêmio no próximo login**, coletável em qualquer dia (também pelo Álbum). Sem servidor, 100% local e determinístico.

## Por que assim (decisão de design)
- **Motivo para voltar hoje:** cada passeio (8 min) soma votos e mostra a colocação na hora (`📰 +3 votos • 2º lugar`).
- **Motivo para voltar amanhã:** rivais crescem com o tempo (curvas diferentes) → o jogador é ultrapassado se sumir; toast `CONTEST_OVERTAKEN_TOAST` (1×/dia) e badge `📰` no Álbum.
- **Motivo para voltar no sábado:** `Sábado da Capa` = votos em dobro (toast + tag no Álbum).
- **Motivo para voltar na segunda:** o resultado da semana fica **pendente** até ser coletado (cartão `RevealCard` no boot + botão no Álbum + badge `🏆`). Nada se perde: se outra semana fechar antes de coletar, o prêmio antigo é entregue automaticamente (`CONTEST_AUTO_CLAIM`).
- **1ª capa alcançável:** metas dos rivais escalam com o estágio do jogador (nível < 5 e < 5 passeios reduzem as metas até 50%).

## Regras (`core/progression/Contest.gd`, estático)
| Evento | Votos |
|---|---|
| passeio bom | +1 |
| passeio perfeito (🎾/🦴) | +2 |
| foto 📸 perfeita | +3 (e entra no Álbum) |
| sábado | ×2 |

- **Semana:** `Contest.week_key()` = mesma fórmula de `GameState._week_key()` (segunda, UTC). `seconds_to_close()` → contagem regressiva.
- **Rivais** (`RIVALS`): `Spa Pet da Dona Cida` (24–40, curva 1.15 — cresce no fim), `Focinho Limpo` (12–22, curva 0.7 — larga na frente), `Patas & Laços` (5–10, linear). Meta semanal = hash determinístico de `week_key:id` × escala do jogador, gravada em `park_contest_rivals` no `sync()`. Placar exibido = `meta × progresso_da_semana^curva`.
- **Colocação:** `rank()` = 1 + rivais com placar > votos (empate favorece o jogador); sem votos = 4º (“fora da disputa”).
- **Fechamento:** `sync()` detecta virada de semana → `_close_week()` grava `park_contest_pending {week, points, photos, rank, coins, embers}` e zera a semana nova. Chamado no boot (`ContestFeedback.on_boot`), em `register_walk`, em `status()` e no badge do HUD.
- **Prêmios** (`reward_coins_for`): 1º = `Rewards.for_kind(weekly_chest, 200)` + 3 brasas + 1 troféu + achievement `park_contest_win`; 2º = 50% + 1 brasa; 3º = 30%; 4º = 15% (participação). `claim()` paga, registra em `park_contest_history` (8 últimas) e limpa a pendência.

## Superfícies
1. **Álbum (`MetaPanel._build_contest`)**: linha do prêmio pendente com `🏆 COLETAR PRÊMIO` → cabeçalho `📰 CONCURSO DA CAPA` (descrição colapsável + pílula `⏱ 3d 4h`) → tag de sábado → **placar** você × 3 rivais (medalhas, votos, barra proporcional; sua linha em destaque dourado) → dica (`CONTEST_LEADING` / `CONTEST_TO_FIRST` / `CONTEST_NOT_ENTERED`) → regra curta → `🏆 Capas conquistadas` + melhor colocação → `ÚLTIMAS SEMANAS` → grid de fotos (inalterado). `Contest.mark_seen()` ao abrir (zera o nudge de ultrapassagem).
2. **Passeio (`ParkFlow`)**: linha do concurso no painel de escolha; `📰 +N votos • colocação` no resultado.
3. **Boot (`core/ui/ContestFeedback.on_boot`)**: cartão de resultado (`CONTEST_RESULT_TITLE_1..4`, botão coleta via `RevealCard.on_primary`), toast `Sábado da Capa` ou toast de ultrapassagem (1×/dia, `settings.contest_nudge_date`).
4. **HUD (`Main._process`)**: badge no nav Álbum via `Contest.badge_text()` — `🏆` pendente, `📰` ultrapassado.
5. **Guia Bia**: dica `contest` aponta para o Álbum após o 1º passeio com votos.

## Persistência (`autoload/GameState.gd`, SAVE_VERSION 14)
```gdscript
park_photos: Array[Dictionary] = []      # inalterado
park_trophies: int = 0
park_contest_week: String = ""           # semana aberta
park_contest_points: int = 0             # votos
park_contest_photos: int = 0             # fotos perfeitas na semana
park_contest_rivals: Array[int] = []     # metas dos 3 rivais
park_contest_pending: Dictionary = {}    # resultado fechado a coletar
park_contest_history: Array[Dictionary]  # {week, rank, points} × 8
park_contest_last_rank: int = 0          # última colocação vista (nudge)
```
- `SaveManager._migrate` v13→v14 cria os campos e apaga `park_contest_claimed_week` (legado do concurso só-sábado).
- Métodos antigos removidos do GameState: `park_can_claim_contest`, `park_contest_progress`, `park_claim_contest` (substituídos por `Contest.*`); novo `GameState.unlock_achievement()` público para sistemas externos.

## Localização (paridade pt/en/es)
`CONTEST_*` (título, descrição, tempo, `RANK_1..4`, placar, dicas, sábado, ultrapassagem, prêmio pendente, cartão de resultado, histórico), `PARK_CONTEST_LINE*`, `PARK_VOTES_LINE`, `ALBUM_*` atualizados; removidos `ALBUM_WEEK*`, `ALBUM_CLAIM*`, `ALBUM_SATURDAY_*`.

## Testes
- `tests/DomainTests.gd::_test_contest` (runtime Godot na CI): sync abre a semana, votos, falha não pontua, virada de semana gera pendência, 999 votos vencem, claim paga/troféu/histórico, claim duplo vazio.
- `tests/test_data_and_economy.py`: migração v14 e presença de `park_contest_pending`.

## Teste manual
1. Faça um passeio → resultado mostra `📰 +N votos • Xº lugar`; abra o Álbum → placar com rivais e contagem regressiva.
2. Mude a data do sistema para a semana seguinte e reabra → cartão “📰 VOCÊ É A CAPA…”/“🥈…” → `COLETAR PRÊMIO` → moedas/brasas/troféu; Álbum mostra histórico.
3. Sábado: toast “📸 Sábado da Capa!” no boot e votos dobrados no resultado.
