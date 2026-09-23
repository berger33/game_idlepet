# Passeio no quintal (Parquinho) — Especificação (MVP 2026-09-22, cadência 8 min 2026-09-23)

> **Fantasia:** passeio com os pets. Fora da banheira, **a cada 8 minutos** você leva 3 pets para brincar no quintal (o mesmo `petshop_quintal.png` do D7). Sem punir a fila, sem anúncio, só afeto — e agora cada passeio rende **votos no Concurso da Capa** (ver `docs/ALBUM.md`).

## Cadência de 8 minutos (2026-09-23)
- `RemoteConfig.park_cooldown_seconds` **480** (antes 7200). Fallback em `GameState._park_cooldown_seconds()` também 480.
- Quando o cooldown termina durante a sessão, `ParkFlow._announce_ready()` dispara **uma vez por ciclo** o toast `PARK_READY_TOAST` (“🌳 Hora do passeio!”) + som `window` + haptic leve; o botão volta a pulsar verde. Sem toast no boot (`ready_state == -1`) nem antes do 1º passeio/tutorial.
- Resultado do passeio mostra `PARK_NEXT_IN` (“⏳ Próximo passeio em 8:00”) no detalhe e a linha `PARK_VOTES_LINE` (“📰 +3 votos no concurso • 2º lugar”).
- Painel de escolha mostra `ParkFlow.contest_line()` (“📰 Concurso da Capa: 2º lugar • 7 votos • fecha em 3d 4h”) + streak.
- Textos reframeados como **Passeio** (`PARK_BUTTON`, `PARK_TITLE`, `PARK_COOLDOWN*`, `PARK_LOCKED*`, `PARK_PERFECT`…), paridade pt/en/es.
- Economia: `R$ 52` base por passeio a cada 8 min ≈ 1 banho a mais por ciclo — desprezível frente à fila; o cap de afeto (50) chega mais cedo, aceitável.

## Loop
1. **Botão 🌳** no HUD (à direita do botão de melhorias, espelhado em modo canhoto).  
   - Locked D0: `🔒` até o 1º atendimento (post-tutorial). Toast: *“Termine seu primeiro atendimento…”*.  
   - Pronto: `🌳` com pulse verde + badge `!` na primeira vez.  
   - Cooldown: `⏳ 7:42`. Toca e mostra *“Os pets estão descansando — próximo passeio em …”*.
2. **Escolha** (overlay 960×620): mostra `Caramelo, Bento & Mel` (favorito + 2 aleatórios do `unlocked_pets`) e 3 botões:  
   - 🎾 **Jogar bolinha** — arrastar bolinha até o pet do meio (10 fetches).  
   - 🦴 **Esconder petisco** — 3 potes, 1 com petisco (50/50 mas com hint visual após escolha).  
   - 📸 **Foto do grupo** — esperar alinhamento `≥72%` e tocar `FOTO!` (janela pulsa).
3. **Sessão** 10–12 s com barra de progresso + timer. Timeout → `fail`.
4. **Recompensa** via `GameState.park_complete(activity, success, perfect)`:
   - `RemoteConfig.park_reward_coins` base `R$ 52` ( = `bath_base_reward` ), `×1.5` se perfeito, `+5%` por dia de streak.  
   - `+1` afeto nos 3 pets (`+2` se perfeito), brasas `25%` se perfeito, conta para `weekly_progress` (`services` + `perfect`).  
   - Afeto 5/20/50 dá brasas via `register_pet_interaction` já existente.

## Persistência (`autoload/GameState.gd`, SAVE_VERSION 14)
```gdscript
park_pets: Array[String] = []              # 3 pets da sessão
park_cooldown_until: int = 0               # unix
park_plays_total / park_plays_today / park_today_key
park_last_activity: String = "ball"
park_streak / park_best_streak             # dias consecutivos com ≥1 play
```
- `to_dictionary()` / `apply_dictionary()` serializam tudo; campos do concurso migram em `SaveManager._migrate` v13→v14.  
- `park_ensure_pets()` garante 3 distintos (favorito primeiro).  
- `_park_cooldown_seconds()` lê `RemoteConfig.park_cooldown_seconds` (default `480`).
- `park_complete()` chama `Contest.register_walk(activity, success, perfect)` e devolve também `votes` e `rank`.

## RemoteConfig (`autoload/RemoteConfig.gd`)
| key | default | range | efeito |
|---|---|---|---|
| `park_cooldown_seconds` | `480` (8 min) | `60–86400` | LiveOps ajusta sem build; testar com `60` |
| `park_reward_coins` | `52` | `5–500` | escala com streak |
| `park_reward_affection` | `1` | `1–5` | reserva, atual usa 1/2 |

## Arte & Audio
- Fundo: `art/backgrounds/petshop_quintal.png` (reuse, valida em `service_layouts.json`).  
- Pets: `caramelo.png` + qualquer `art/pets/*.png` (fallback caramelo).  
- Sons existentes: `tool_pickup`, `window`, `tap`, `coin`, `perfect`, `error_soft` (sem novos assets).

## Código
- `core/gameplay/ParkService.gd` — estados `IDLE→ACTIVE→COMPLETE/FAILED`, `Activity {BALL,TREAT,PHOTO}`, progress/time/score, hints `Loc.t("PARK_HINT_*")`.
- `core/gameplay/ParkCanvas.gd` — `Control` que desenha quintal + 3 pets + bolinha/potes/foto + HUD progresso/tempo. Sincronizado por `Main._process`.
- `core/gameplay/ParkFlow.gd` — UI/fluxo completo (`setup`, `update_button`, `_announce_ready`, `contest_line`, `open_choose`, `start_activity`, `begin/move/end_pointer`, `finish`, `show_success/fail`, `close`); recebe `main` e mantém `Main.gd` abaixo do teto. Respeita `meta.is_open`, `result_panel`, `queue`, back button. Localizado via `Loc.t("PARK_*")` (paridade pt/en/es).
- `core/progression/Contest.gd` — votos/rivais/fechamento semanal (ver `docs/ALBUM.md`).
- Guia Bia: dicas `park` (botão), `park_choose` (painel), `park_done` (8 min) e `contest` (Álbum) em `scenes/main/TutorialFlow.gd`.
- Validação: `python3 tools/validate_project.py` → `0 errors, 0 warnings`.

## Streak & Retenção
- `park_streak` exibe `🔥 N dias` no botão e no painel; recompensa +5% por dia.  
- Primeira vez: badge `!` + toast `BUDDY_VISIT`.  
- Achievements internos (sem entrada nova em `data/` para não quebrar catálogo): `park_first` (+20), `park_10` (+2 brasas), `park_50` (+5), `park_streak_7` (+3) via `_unlock_achievement`.

## Próximos passos LiveOps (sem código)
- Ajustar `park_cooldown_seconds` p/ evento de fim de semana (ex: `240` no sábado da capa).  
- Rotacionar `park_reward_coins` p/ teste A/B de economia.  
- Notificação push “Hora do passeio!” quando `park_can_play()` volta a true (adapter Android do `NotificationManager`).

## Teste manual
1. Complete 1 atendimento → botão 🌳 deixa de ser 🔒.  
2. Toque 🌳 → escolha 🎾 → arraste bolinha até o pet do meio 4× → celebração + `R$ + afeto`.  
3. Aguarde 8 min (ou edite `RemoteConfig.values["park_cooldown_seconds"] = 60` no console) → `⏳ 0:42` → toast de cooldown se tocar cedo; ao zerar, toast “🌳 Hora do passeio!” uma vez.
