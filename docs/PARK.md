# Parquinho / Creche — Especificação (MVP entregue 2026-09-22)

> **Fantasia:** cuidador no parquinho. Fora da banheira, a cada X tempo você cuida de 3 pets soltos no quintal (o mesmo `petshop_quintal.png` do D7). Sem punir a fila, sem anúncio, só afeto.

## Loop
1. **Botão 🌳** no HUD (à direita do botão de melhorias, espelhado em modo canhoto).  
   - Locked D0: `🔒` até o 1º atendimento (post-tutorial). Toast: *“Termine seu primeiro atendimento…”*.  
   - Pronto: `🌳` com pulse verde + badge `!` na primeira vez.  
   - Cooldown: `⏳ 1:42` / `2h 00m`. Toca e mostra *“volta em … os pets estão tirando soneca”*.
2. **Escolha** (overlay 960×620): mostra `Caramelo, Bento & Mel` (favorito + 2 aleatórios do `unlocked_pets`) e 3 botões:  
   - 🎾 **Jogar bolinha** — arrastar bolinha até o pet do meio (10 fetches).  
   - 🦴 **Esconder petisco** — 3 potes, 1 com petisco (50/50 mas com hint visual após escolha).  
   - 📸 **Foto do grupo** — esperar alinhamento `≥72%` e tocar `FOTO!` (janela pulsa).
3. **Sessão** 10–12 s com barra de progresso + timer. Timeout → `fail`.
4. **Recompensa** via `GameState.park_complete(activity, success, perfect)`:
   - `RemoteConfig.park_reward_coins` base `R$ 52` ( = `bath_base_reward` ), `×1.5` se perfeito, `+5%` por dia de streak.  
   - `+1` afeto nos 3 pets (`+2` se perfeito), brasas `25%` se perfeito, conta para `weekly_progress` (`services` + `perfect`).  
   - Afeto 5/20/50 dá brasas via `register_pet_interaction` já existente.

## Persistência (`autoload/GameState.gd`, SAVE_VERSION 12)
```gdscript
park_pets: Array[String] = []              # 3 pets da sessão
park_cooldown_until: int = 0               # unix
park_plays_total / park_plays_today / park_today_key
park_last_activity: String = "ball"
park_streak / park_best_streak             # dias consecutivos com ≥1 play
```
- `to_dictionary()` / `apply_dictionary()` serializam tudo; saves antigos ganham defaults sem bump de versão (validador exige 12).  
- `park_ensure_pets()` garante 3 distintos (favorito primeiro).  
- `park_cooldown_seconds()` lê `RemoteConfig.park_cooldown_seconds` (default `7200`).

## RemoteConfig (`autoload/RemoteConfig.gd`)
| key | default | range | efeito |
|---|---|---|---|
| `park_cooldown_seconds` | `7200` (2h) | `60–86400` | LiveOps ajusta sem build; testar com `600` (10 min) |
| `park_reward_coins` | `52` | `5–500` | escala com streak |
| `park_reward_affection` | `1` | `1–5` | reserva, atual usa 1/2 |

## Arte & Audio
- Fundo: `art/backgrounds/petshop_quintal.png` (reuse, valida em `service_layouts.json`).  
- Pets: `caramelo.png` + qualquer `art/pets/*.png` (fallback caramelo).  
- Sons existentes: `tool_pickup`, `window`, `tap`, `coin`, `perfect`, `error_soft` (sem novos assets).

## Código
- `core/gameplay/ParkService.gd` — estados `IDLE→ACTIVE→COMPLETE/FAILED`, `Activity {BALL,TREAT,PHOTO}`, progress/time/score, hints `Loc.t("PARK_HINT_*")`.
- `core/gameplay/ParkCanvas.gd` — `Control` que desenha quintal + 3 pets + bolinha/potes/foto + HUD progresso/tempo. Sincronizado por `Main._process`.
- `scenes/main/Main.gd` — `park_button` + `park_choose_panel` + `park_canvas`; `_setup_park()`, `_open_park_choose()`, `_start_park_activity()`, `_park_begin/move/end_pointer()`, `_finish_park()`, `_show_park_success/fail()`, `_close_park()`. Respeita `meta.is_open`, `result_panel`, `queue`, back button. Localizado via `Loc.t("PARK_*")` (528 chaves, paridade pt/en/es).
- Validação: `python3 tools/validate_project.py` → `0 errors, 0 warnings`.

## Streak & Retenção
- `park_streak` exibe `🔥 N dias` no botão e no painel; recompensa +5% por dia.  
- Primeira vez: badge `!` + toast `BUDDY_VISIT`.  
- Achievements internos (sem entrada nova em `data/` para não quebrar catálogo): `park_first` (+20), `park_10` (+2 brasas), `park_50` (+5), `park_streak_7` (+3) via `_unlock_achievement`.

## Próximos passos LiveOps (sem código)
- Ajustar `park_cooldown_seconds` p/ evento de fim de semana (ex: `3600` no sábado).  
- Rotacionar `park_reward_coins` p/ teste A/B de economia.  
- Notificação push “Seu trio está com saudade!” quando `park_can_play()` volta a true (usar `NotificationManager.schedule_return_reminders`).

## Teste manual
1. Complete 1 atendimento → botão 🌳 deixa de ser 🔒.  
2. Toque 🌳 → escolha 🎾 → arraste bolinha até o pet do meio 4× → celebração + `R$ + afeto`.  
3. Aguarde 2h (ou edite `RemoteConfig.values["park_cooldown_seconds"] = 60` no console) → `⏳ 0:42` → toast de cooldown se tocar cedo.
