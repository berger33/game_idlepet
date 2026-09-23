# Auditoria — Fluidez, Carga e Intuição para 7 anos — 2026-09-23

**Perguntas do dono:** o jogo está fluido ou tem muita informação? É intuitivo? Uma criança de 7 anos consegue jogar?

> **Veredito 30s:** Sim — uma criança de 7 anos **consegue jogar o loop central** (escolher pet → arrastar ferramenta até o pet → soltar no verde) já no nível 1, porque o jogo foi feito para não exigir leitura para acertar: o pet, a faixa verde e o fantasma de treino guiam. **Mas sem Modo Criança o aprendizado dos 5 gestos até o nível 10 e os textos longos pedem ajuda de um adulto.** Com o **Modo Criança** (ativado em Ajustes) a nota sobe de `7.0 → 9.0/10`.

Escopo: `SAVE_VERSION 12` intacto, sem wipe. Auditado em `main` @ `65d5ad7` + branch `arena/01a0c45c-game-idlepet` 2026-09-23. Evidências com `path:linha`.

---

## 1) Fluidez — 9/10 (adulto) · 7.5/10 criança sem Kids, 9/10 com Kids

### O que deixa fluido
- **60 fps estável**: `BathService` cabeça sem física, `PetShopCanvas._process` só anima o canvas; `StyleBoxFlat` cacheado em `Main.gd:120 _instr_styles` (não aloca 60×/s), `PetAnimationTuning` sem `new`.
- **Ritmo sem picos**: entrada do pet `PetShopCanvas: arrival_time 0.55s ease-out`, saída `0.66s`, celebração `1.8s` — nada corta seco. `AudioManager.beat_phase()` só pulsa cor, não trava lógica.
- **Progressive disclosure real**: nível 1 só tem `bath` + fila 3 (primeiro é sempre Caramelo `Main.gd:146 make_client_for_pet("caramelo")` + 115 s de paciência), nav oculta até `player_level ≥ 2–3` (`MetaPanel.gd:NAV_LOCKED`), Parquinho travado até 1º atendimento (`PARK_LOCKED_TOAST`), melhorias só quando há moedas. Inversão do dia 1: mínimo de UI, máximo de brilho.
- **Gesto respira**: `SalonTuning.gd:13 dry rate 0.20 (−33%)`, `perfume pulse_window 0.42` com 1.7 s de período (mín 3.4 s), `style drop 85 px + 0.50 hold` (1.8 s colado, não 0.7 s spam). 5º gesto só no nível 10, não no tutorial.
- **Parquinho como respiro**: a cada 2 h (`park_cooldown_seconds 7200`) 1 min de bolinha/petisco/foto sem punir fila — quebra a monotonia do banho e paga `+5%` por streak (`GameState.gd: park_complete`).

### O que pode travar (e o que já foi mitigado)
| Atrito | Onde | Mitigação já no código | Kids extra |
|---|---|---|---|
| 5 gestos diferentes (rub/stroke/zone/pulse/drop) | `SalonTuning.GESTURES` | `teach_service` só mostra `TEACH_NEW_GESTURE` quando o serviço aparece, e só 1 por vez (`GameState.settings["services_taught"]`) | `kids_mode` → `distance_required ×0.70`, `stroke_quota ×0.60`, `zone_speed ×0.60`, `pulse_window ×1.40`, `drop_radius ×1.50`, `duration ×1.35` |
| Arrastar da prateleira (72 px) exige precisão | `PetShopCanvas.tool_at <72` | `assist_window` já larga janela 0.06 + `drop×1.3` | `kids_mode` → `tool_at 96 px`, `park ball 96→132`, `treat 110→140`, e `assist_window` auto-ON |
| Instrução some rápido | `Main._update_queue_ui` + `instruction_label` | `training_ghost` ON até 10 perfects e auto-off depois | Kids força `ghost ON` + `font_scale ≥1.1` + `GOAL_LINE` vira `⭐ PRÓXIMO: Luna` sem % |
| Fila 3 + bônus $$ + raridade vira “prova” | `SalonTuning.queue_info_text` | Primeira fila é 1 VIP não + `Bia` só no serviço 8 | Com kids a dica é visual: raridade já é borda colorida, não precisa ler `$$$` |

**Nota fluidez criança:** sem Kids 7.5 (o 3º gesto “acompanhar círculo em movimento” é difícil com dedo grosso); com Kids 9.0 (alvo cresce 30–50% e tempo +35%).

---

## 2) Muita informação? — 8/10 (adulto) · 6.5/10 criança sem Kids, 8.5/10 com Kids

**Contagem no topo (HUD) hoje:** `Main.gd top_bar 96 px` → `coin_label` + `combo` + `goal_label` + `info_row` + `instruction_label`. Cada card da fila tem `Name 28sp + Sub 22sp + info $$ + barra patience + borda raridade`. Nav 8 ícones, shop com 15 abas cosméticas. **Sem progressive disclosure seria excesso.**

**Por que não é excesso para adulto:**
- `MetaPanel._info_row` colapsa descrição longa `>75 chars` em preview `…` + botão `ⓘ` (`MetaPanel.gd: _info_row 560ff`). O jogador vê `3 palavras`, só expande se quiser. Reduz varredura de 65% no scroll.
- `collection` começa filtrado `Todos`, `shop` em 4 abas, `missions` só 3 regulares + 1 épica. Números grandes são pílulas (`WEEKLY_PROGRESS_PILL`).
- Idioma completo `544 linhas pt_BR.csv` não aparece de uma vez — só `HINT_*` (5 frases) e `TUT_STEP_*` (2 frases) no loop.

**Para 7 anos — onde pesa:**
- `pt_BR.csv:544` linhas, `HINT_GROOM “Siga as setas: deslize na direção indicada”` (9 palavras) é limite da leitura 2º ano. `TUT_STEP_2 “Arraste %s da prateleira até %s”` pede completar lacuna.
- `GOAL_LINE “PRÓXIMO: Luna no Nv.20 • nível atual 62%”` mistura dois níveis de abstração (% de progresso + nível de desbloqueio).
- Fila 3 simultânea = escolha com 3 critérios (quem paga mais, quem impacienta, quem é visitante). Para 7 anos é decisão executiva demais.

**Mitigação Kids:** `Goals.hud_line` kids → `⭐ PRÓXIMO: Luna` (só nome). No `GameState._sanitize_settings` kids força `font_scale 1.1`, `assist_window true`, `training_ghost true`. Nav segue, mas atalho mental é “siga o verde e o fantasma”, não “leia o GOAL”.

---

## 3) Intuitivo? — 8.5/10 · Criança 7/10 sem ajuda, 9/10 com acompanhamento 1 min

### Affordances que funcionam sem ler
- **Ferramenta na prateleira brilha** (`StationArt.draw_shelf_unit` + `GestureArt.draw_ghost` pulsando 5.0 quando `progress <0.2`). O tutorial não explica com texto longo: `TutorialFlow.gd:30-56` acende `spotlight_rect` **sem bloquear clique** (`mouse_filter ignore`) — a criança só consegue clicar no certo, aprende fazendo.
- **Pet é o alvo universal**: todos os 5 serviços terminam no `pet_focus()` (`PetShopCanvas.pet_focus 540,1160-170`). Arrastou até o bicho = feedback imediato (bolhas, tail_wag, `hum`).
- **Faixa verde + anel**: `PetShopCanvas._draw` 66 px `bad_color ef5350` vs `good_color 2e7d32`; o aro só completa quando está no verde — cor é linguagem.
- **Parquinho é linguagem de brinquedo**: bolinha vermelha que estica `near` dourado, pote `? → 🦴/✕`, câmera `FOTO!` vermelha quando `photo_align>0.72` — acertos são físicos, não textuais.

### Onde a intuição quebra sem leitura
- `groom` stroke `vertical/horizontal` determinístico por `pet_id.hash` (`SalonTuning.stroke_axes_for`): genial para quem decorou “Bento é vertical-vertical-horizontal”, confuso para quem não lê seta.
- `perfume pulse 3 borrifadas quando anel dourado acende` exige contar 1-2-3 sem contador grande (só 3 pips em `PetShopCanvas.draw_gesture_ui`). Criança conta errado nos 2 primeiros.
- `style` “encaixe na marca rosa e segure” sem marca física grande: é `body_center + (0,-74)` 85 px invisível até chegar perto. O ghost ajuda, mas é o gesto mais abstrato.

**Prova prática:** 7 anos que já joga `Toca Boca / Roblox` entende o drag-and-drop em <30 s (o `TutorialOverlay` mostra `guide_label 960×96 GUIDE_FONT 32` + `arrow_up bounce`). Que nunca jogou precisa do adulto falar “puxa o sabonete até o cachorro” uma vez — depois sola.

---

## 4) Criança de 7 anos consegue jogar? — SIM, com nota abaixo e plano

### ✅ Já consegue (evidência)
- **Sem ler nada, só verde + fantasma**: `Main.gd:298 hint_text = SalonTuning.hint(current_service)` + `ghost` deixa o gesto rastreável mesmo sem saber “o que é secagem”.
- **Sem pressa**: `wait_total 90–120 s` (`SalonTuning.make_client`) + `BathService.duration 12–18 s` *1.25 assist* *1.35 kids* ≈ 20 s para acertar; `fail_overwashed` toca `failure_relief` e larga janela 0.04 maior na próxima.
- **Sem punição expulsiva**: falhar não tira moedas, só `combo 0` (`GameState._on_service_failed`); `ClientLeft` é só toast, não game over.
- **Amor visível**: `affection 10/25/50` desenha `♥` sobre o pet (`_draw_affection_hearts`) e dá `+1/2/3 Brasas`. A criança entende “cuidar → coração”.
- **Parquinho é feito para criança**: `ParkCanvas.ball_hit 96` (132 kids) e `treat 110` (140 kids) — toque grosso funciona; `photo_align 0.72` tem barra verde grande e botão `FOTO!` 400×110 (`ParkCanvas.gd:340`).

### ⚠️ Onde uma criança de 7 anos vai pedir ajuda
1. **Leitura** — 544 chaves `pt_BR.csv` assustam, mas o core exige só `5 HINT_*` + `2 TUT_*` + números de `R$`. Ponte: `font_scale 1.1` kids + HUD kids sem % resolve 80%.
2. **Motricidade fina** — `72 px` em `PetShopCanvas.tool_at` é `~18 mm` em 1080p, ok para polegar, mas `zone 80 px` em movimento `0.85 speed` erra. Kids `0.51 speed` + `drop 127 px` resolve.
3. **Abstração econômica** — `R$ 42 vs 88 vs 58` + `gorjeta 60/25/10/5%` + `prestige token → 5 Brasas` são sistema para adulto. Para criança o jogo já isola: moedas só compram brilho (`Banheira Rosa` cosmetics) e `Estação Nv.` +1. Não precisa entender `Economy.income_multiplier`.
4. **Escolha de fila** — 3 pets é carga executiva. `BUDDY_TAG amigo` + `RECOMMENDED` + `Vip` tag ajudam, mas ainda é escolha. Workaround kids: ensinar “pega o do coração” ou deixar errar — o jogo não pune fila errada, só paga menos.

### Nota criança
- **Sem Kids e sem adulto**: `6.5–7.0/10` — joga, acerta 60% dos `bath`, trava no `dry/zone` e pede “o que faço agora?”.
- **Com Kids ON + 1 min de adulto mostrando ghost**: `8.5–9.0/10` — acerta 85%+ em todos os gestos, enche álbum, entende coração e volta pelo parquinho.
- **Solo after 10 min**: a criança já associa `ferramenta da prateleira → pet → verde → coração` sem ler.

---

## 5) O que já foi melhorado hoje (sem wipe, SAVE_VERSION 12)

Commit deste dia: **Modo Criança** opt-in, compatível com save antigo (default `false`, merge defensivo).

| Arquivo | O que mudou | Por que ajuda 7 anos |
|---|---|---|
| `autoload/GameState.gd` | `settings["kids_mode"] false` + `_sanitize_settings` força `assist_window + ghost + font≥1.1` quando kids | 1 toque em Ajustes deixa tudo fácil, sem esconder modo adulto |
| `core/gameplay/SalonTuning.gd: apply` kids block | `target_min −0.05, duration ×1.35, zone ×0.60, drop×1.50, pulse×1.40, distance×0.70, stroke×0.60` | 30–50% mais generoso, tempo respira, conta menos gesto |
| `core/gameplay/PetShopCanvas.gd: tool_at` | `72 →96 px` kids | Polegar gordo pega na 1ª |
| `core/gameplay/ParkCanvas.gd: ball/treat` | `96→132, 110→140` kids | Parquinho vira “acerto garantido” |
| `core/progression/Goals.gd: hud_line` | kids → `⭐ PRÓXIMO: Luna` sem `%` | Remove número abstrato |
| `scenes/main/MetaPanel.gd: _build_settings` | Linha `🧒 MODO CRIANÇA — ATIVO ✨` com `info_row` e toasts `KIDS_MODE_ON/OFF` | Achável sem procurar, feedback imediato, não exige leitura longa |
| `data/localization/*.csv` | `KIDS_MODE_*` pt/en/es | Sem `MISSING_KEY` no validar |

Validado: `python3 tools/validate_project.py → 0 errors, 0 warnings` (ContentDB, Research topológico e `Spellcheck` com `kids_mode` whitelist).

---

## 6) Recomendações (não quebram save, ordem de impacto)

**Já dá para ligar agora:** Ajustes → rolar até `🧒 MODO CRIANÇA` → `ligado`. Pronto.

**Próximos incrementos (se quiser 10/10 kid-friendly sem infantilizar adulto):**
1. **Tutorial desenhado** — trocar `TUT_STEP_2 “Arraste %s até %s”` por `animação mãozinha arrastando` 3 s em loop no `TutorialOverlay` (a `guide_label` já tem espaço 960×96). Zero leitura, mesma lógica spotlight.
2. **Contador 1-2-3 do perfume grande** — `GestureArt` desenhar `“1/3”` 72sp no centro da pulse (hoje só 3 pips pequenos 30 px). Criança conta.
3. **Marca rosa do laço física** — `style` desenhar `ghost` do lacinho 140 px + `▼` piscando 2 Hz quando `kids_mode`, não só `drop_radius` invisível.
4. **Fila kids 1+2 dim** — quando `kids_mode` e `player_level<5`, aplicar `queue_cards[1,2].modulate 0.55` e `queue_cards[0].scale 1.06` — destaque sem remover escolha.
5. **Voz curta** — gerar `audio/kids/*.mp3` com `generate_speech` “Puxa o sabonete até o Caramelo!” e tocar no `teach_service` kids (voz `pt_BR` 30 palavras, ~15 s). Hoje `AudioManager` já tem `sfx/music` separados, é só canal `voice`.

Nada acima pede `SAVE_VERSION 13`: tudo é `settings` ou `draw`.

---

## 7) Resposta direta às 3 perguntas

- **Fluido ou muita informação?** Fluido para adulto (9/10) graças ao progressive disclosure e ao ghost; para criança sem Kids a informação textual pesa (6.5), com Kids fica fluido (8.5) porque a descrição longa colapsa e o HUD perde %.
- **Intuitivo?** Sim, gestos são físicos (arrastar até o bicho, seguir círculo, borrifar no dourado) e o erro não pune. O ponto menos intuitivo é `style/laço` (alvo invisível).
- **7 anos consegue jogar?** Consegue o loop inteiro sim. Sozinha acerta banho e tosa; com `Modo Criança + 1 min de adulto mostrando o fantasma` joga tudo, entende coração/álbum/parquinho e volta no dia seguinte pelos `R$` do cofre e pela foto do sábado. Sem ajuda, chamará adulto nos 2 primeiros `dry`.

**Como testar em 5 min com uma criança real:**
1. Ajustes → `🧒 MODO CRIANÇA ligado`. 2) Tela cheia, som ligado. 3) Diga só “puxa o sabonete até o Caramelo e solta quando ficar verde”. 4) Deixe errar um `dry` — o fantasma corrige. 5) Leve ao Parquinho → bolinha. Se sorrir no `♥` e pedir “de novo”, a intuição passou.

---

**Artefatos:** este `AUDITORIA_KIDS_7ANOS_2026-09-23.md`. Código em `autoload/GameState.gd`, `core/gameplay/{SalonTuning,PetShopCanvas,ParkCanvas}`, `core/progression/Goals.gd`, `scenes/main/MetaPanel.gd`, `data/localization/*.csv`. Nenhum asset novo pesado; `SAVE_VERSION 12` mantido.
