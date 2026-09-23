# Auditoria de UX — Tutorial Bia (2026-09-23)

> Escopo: re-auditoria do tutorial após os 5 P0s anteriores já corrigidos
> (seta ✔, mãozinha com gesto real ✔, cartão reposicionado ✔, skip reposicionado ✔,
> RevealCard do 1º cliente ✔). Achados novos T-01…T-04 + P2/P3, com correções
> aplicadas nesta branch e cobertura de testes.

## Status dos achados

| ID | Severidade | Achado | Correção | Evidência |
|---|---|---|---|---|
| **T-01** | 🔴 | Gramática por gênero quebrada: "arraste **o** máquina de tosa", "até **o** Luna", "chamá-**lo**", "**ele** precisa" — erra p/ ~metade dos 50 pets nos 3 idiomas | Textos neutros (sem pronome de pet) + `SalonTuning.tool_with_article()` com artigo variável (`o sabonete`/`a máquina de tosa`, `el jabón`/`la máquina`, `the …`) | `SalonTuning.gd tool_with_article`; `GUIDE_QUEUE/TOOL/WRONG_TOOL`, `DRAG_TOOL_TO` em pt/en/es |
| **T-02** | 🔴 | Skip com 1 toque, sem confirmação e sem volta (sem "rever tutorial" nos Ajustes) | Skip em 2 toques (`on_skip_pressed` → arma por 3.5 s → 2º toque pula; botão fica vermelho "TOQUE DE NOVO…") + **Ajustes → 🎓 Rever tutorial** reinicia o roteiro sem wipe | `TutorialFlow.gd on_skip_pressed/_arm_skip/replay`; `MetaPanel._build_settings` |
| **T-03** | 🔴 | Funil incompleto: só "completou/pulou" — impossível medir em qual passo o jogador desiste (`UX_FLOW.md` prometia) | Evento `tutorial_step{step, action}` com `step ∈ welcome\|queue\|tool\|gesture` e `action ∈ show\|next\|skip_attempt\|skip\|complete` | `TutorialFlow._track_step`; `ANALYTICS_PLAN.md` |
| **T-04** | 🔴 | Cartão ignora `font_scale` (fixo 22/26/30 px); skip 56 px | `_apply_font_scale()` no cartão (kids ≥1.1 funciona); skip `_button(..., 220, 64)` | `TutorialOverlay._apply_font_scale`; `Main.gd` skip 64 |
| P2 | 🟡 | Textos longos p/ kids | Variantes `GUIDE_*_KIDS` (5 chaves × 3 idiomas) com fallback em `TutorialFlow.guide_text()` | CSVs + `guide_text()` |
| P2 | 🟡 | Emoji "👆" vira □ no web (DejaVuSans sem emoji) | Mãozinha vetorial `_draw_pointing_hand()` (polígonos) | `TutorialOverlay._draw_pointing_hand` |
| P2 | 🟡 | Zero testes comportamentais do tutorial | `TutorialUXTests` (9 testes Python) + `_test_tutorial_ux` no runtime Godot | `tests/test_data_and_economy.py`, `tests/DomainTests.gd` |
| P2 | 🟡 | "Gesto ensinado" salvo antes de exibir | `taught.append` **depois** de `show_guide` em `teach_service` | `TutorialFlow.teach_service` |
| P3 | ⚪ | Guard faltando num painel | `_can_select` agora bloqueia com `upsell_panel.visible` | `Main._can_select` |
| P3 | ⚪ | 2 chaves órfãs `TUT_STEP_1/2` do tutorial antigo | Removidas dos 3 CSVs (paridade mantida) | `data/localization/*.csv` |
| P3 | ⚪ | Animações ignoram "movimento reduzido" | `_reduced_motion()` (eco/reduced_particles): sem tween de entrada, pulso congelado | `TutorialOverlay` |

## Como validar

```bash
python3 -m unittest discover -s tests -v   # inclui TutorialUXTests
python3 tools/validate_project.py          # 0 errors
gdlint $(git ls-files '*.gd')              # limpo
godot --headless --path . res://tests/domain_tests.tscn  # inclui _test_tutorial_ux
```

## Fora do escopo desta rodada (próximo polish)

- Contador 1-2-3 grande do perfume; marca física do laço (kids).
- Voz curta kids (`audio/kids/*`); voz segue desligada na build.
- Dashboard/funil no backend para `tutorial_step` (evento já emitido com consentimento).
