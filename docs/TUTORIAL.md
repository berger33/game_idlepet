# Tutorial & primeiros passos com a Bia (2026-09-23)

> **Decisão:** sem locução por enquanto. Todo o onboarding é conduzido por uma personagem em tela — **Bia**, a vizinha que ajudou a abrir o petshop e vira a primeira contratação (`data/staff.json`, `core/story/StaffStories.gd`).

## Arte
- `art/characters/bia_{hello,point,cheer,think}.png` — 512², fundo transparente, mesmo estilo dos pets (`docs/ART_STYLE.md`: rosa `#FF8FB1`, azul `#4FC3F7`, contorno marrom-escuro, sem texto).
- Pipeline: sheet 2×2 gerada por IA em fundo creme liso (`art/_gen/bia_sheet_v1.png`, ignorada pelo git) → chroma key por distância de cor com flood fill a partir das bordas (preserva brancos internos) → recorte por célula, âncora inferior central, 512².

## Overlay (`scenes/main/TutorialOverlay.gd`)
- `show_guide(text, mood, rect, button_text, callback, hand, from, to)`: escurece ao redor do alvo (4 retângulos), borda pulsante, seta pontilhada do cartão até o alvo, mãozinha (`tap` pulsante ou `drag` percorrendo o caminho real prateleira→pet, desenhada numa camada acima do cartão).
- Cartão (`PanelContainer` 960 px): retrato em bolha rosa + nome + balão com **máquina de escrever** (42 cps; toque no cartão completa) + botão opcional. Posiciona-se **logo abaixo do alvo** se couber, senão logo acima; sem alvo, centralizado.
- `show_hint(rect, text, seconds)`: dica temporária (ferramenta errada) — ignorada enquanto `locked` (tutorial principal).
- Não bloqueia o jogo (`mouse_filter IGNORE`); só o cartão captura toques, e `Main._input` ignora eventos sobre ele (`blocks_event`).

## Roteiro (`scenes/main/TutorialFlow.gd`)
| Passo | Gatilho de avanço | Fala (chave) |
|---|---|---|
| `STEP_WELCOME` (após splash) | botão “Vamos!” | `GUIDE_WELCOME` |
| `STEP_QUEUE` (spot na fila, mão `tap`) | `_on_queue_pressed` | `GUIDE_QUEUE` |
| `STEP_TOOL` (spot na prateleira, mão `drag` até o pet) | `_start_bath` | `GUIDE_TOOL` |
| `STEP_GESTURE` (spot no pet) | resultado do serviço | `GUIDE_GESTURE` + `SalonTuning.hint` |
- `PULAR TUTORIAL` continua disponível (`tutorial_skip_button`, 64 px). **Confirmação em 2 toques** (T-02): o 1º toque arma (`SKIP_CONFIRM_TAP`, janela 3.5 s), o 2º pula — evita skip acidental. **Ajustes → 🎓 Rever tutorial** reinicia o roteiro sem wipe (`TutorialFlow.replay`). Jogador adiantado (tocou a fila antes da fala) pula o passo já feito (`advance()`).
- **Funil (T-03):** cada transição emite `tutorial_step{step, action}` com `step ∈ welcome|queue|tool|gesture` e `action ∈ show|next|skip_attempt|skip|complete`.
- **Gênero (T-01):** textos neutros de pet + artigo variável da ferramenta (`SalonTuning.tool_with_article`). Em `kids_mode`, `guide_text()` usa as variantes `GUIDE_*_KIDS` mais curtas.
- **Fonte (T-04):** o cartão aplica `SalonTuning.font_scale()` (22/26/30 × fs).
- `teach_service()` (gesto novo, 1× por serviço) usa a Bia com humor `think` e `TEACH_NEW_GESTURE`; marca `services_taught` só após exibir a fala.

## Primeiros passos (dicas 1× cada, `GameState.guide_steps_done`)
| id | evento (`tutorial.notify`) | condição | alvo |
|---|---|---|---|
| `first_done` | `result_dismissed` | 1º atendimento | — (`cheer`) |
| `park` | `result_dismissed` | ≥2 atendimentos e nenhum passeio | botão do passeio |
| `missions` | `result_dismissed` | ≥3 atendimentos | nav Missões |
| `upgrade` | `result_dismissed` | ≥4 e melhoria comprável | botão de melhorias |
| `park_choose` | `park_opened` | painel de escolha visível | painel |
| `park_done` | `park_result_dismissed` | 1º passeio | — (8 min) |
| `contest` | `park_result_dismissed` | votos > 0 | nav Álbum |
- `tick()` (em `Main._process`) só mostra a dica pendente com a tela livre (sem `RevealCard`, meta fechado, sem resultado) e a fecha sozinha quando o contexto muda (meta abre, passeio começa/fecha…).

## Voz
- `AudioManager.VOICE_ENABLED_BUILD = false`: `is_voice_enabled()` sempre falso, cache de `audio/vo/*` não é carregado; botão 🔊 do topo, botão do overlay e linha de Ajustes removidos; `settings.voice` default `false`. Os MP3 permanecem no repositório para uma futura locução.
