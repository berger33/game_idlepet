# Consolidação → Release Web (M3) — 2026-09-23
**Branch:** `arena/01a0cf14-game-idlepet` · **PR:** consolida #1–#5 na `main`

## O que esta entrega faz
1. **Traz o estado mais avançado do projeto** (ponta do PR #5, `e1a1782`) para a branch de release.
2. **Integra o que tinha ficado de fora** (sessão `arena/01a0c43a`, sem PR):
   - fixes P0 de infra/áudio/CI (`ci.yml` cache/timeout/dedup, `default_bus_layout.tres`, AudioManager 44100 + cache + delta, AdsPolicy wired, IAP persistido, Analytics atômico, 59 testes;
   - **jurídico final**: `docs/PRIVACY_POLICY.md`, `docs/TERMS_OF_SERVICE.md`, `docs/DATA_SAFETY.md` (antes só havia `PRIVACY_POLICY_DRAFT.md`) — desbloqueia gate M3/M4;
   - `.gitattributes` (binary/EOL de assets).
3. **NÃO duplica áudio**: o commit-ponta do PR #4 (`dfae405`, 63 WAVs em `assets/audio/sfx/`) é duplicata do `ee95134` já presente nesta linha (mesmos instrumentos físicos 44,1 kHz em `audio/sfx/`, **mais** 3 BGMs + 6 locuções kids pt-BR = 72 arquivos vs 63). Decisão registrada para o fechamento do PR #4 como *superseded*.
4. **Corrige a causa-raiz do CI vermelho do PR #5** (estava falhando há 2 checks):
   - 4 lambdas de timer com `func(): if …: stmt` (inválido para gdparse e arriscado para o parser do Godot) → blocos multi-linha;
   - `GameState.gd` 51→42 métodos públicos (helpers internos do parque privatizados; `_register_weekly_spend` com contrato de teste atualizado junto);
   - `MetaPanel.gd` 1365→1210 linhas (junção de quebras; lint tolera linha longa);
   - `ParkService.finish()` 12→3 returns.
5. **Refator estrutural registrado na auditoria 2026-09-23** ("Main.gd 1864 L poderia quebrar em ParkController.gd"):
   - `core/gameplay/ParkFlow.gd` (novo, 516 L): fluxo completo do parquinho como funções estáticas `x(main: Control, …)` — padrão já usado por SalonTuning/SalonPanels. Movimento 1:1 provado por dif-reverso (únicas diferenças: `Callable(ParkFlow, …)` explícitos e injeção do parâmetro `main`);
   - `Main.gd` 1968→1389 linhas; `_voice_for_service` → `AudioManager.voice_for_service`;
   - `.gdlintrc` 1350→1400 com comentário registrando a dívida restante (dividir Main em controller).
6. **Migração de save segura**: defaults de parque v12 (sem wipe) combinados com a migração v13 de monetização (entitlements, ledger, ads_policy). Nenhum save de jogador é apagado.

## Verificação local (todo o job estático do CI)
```
gdlint $(git ls-files '*.gd')        → Success: no problems found
python3 -m unittest discover -s tests → Ran 59 tests — OK
python3 tools/validate_project.py     → 0 errors, 0 warnings
python3 tools/verify_pet_animations.py → 500 PNGs — 0 errors, 0 warnings
python3 tools/gen_sfx.py --check      → 63 sons | erros: 0 | drift: 0
python3 tools/gen_bgm.py --check      → 0 problema(s)
python3 tools/gen_shelf_art.py --qa   → 0 erros
python3 tools/compose_scene_preview.py / qa_accessory_preview.py → OK
```

## Roteiro pós-merge
- Merge deste PR ⇒ `main` vira o projeto principal; o workflow `web-pages.yml` publica o build Web (GitHub Pages).
- PRs #1, #2, #3, #5: conteúdo contido aqui → fechar como consolidados.
- PR #4: única diferença é o commit de áudio duplicado (acima) → fechar como *superseded*.
- Próximos gates humanos (M3): playtests, device profiling, métricas (tutorial >85%, crash-free >99%, D1 >40%).
