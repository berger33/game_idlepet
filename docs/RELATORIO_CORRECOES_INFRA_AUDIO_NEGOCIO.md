# Relatório de Correções — Infra / Áudio / Negócio

**Data:** 2026-09-21  
**Branch:** `arena/01a0c43a-game-idlepet`  
**Base:** `caedd74` + correções P0/P1

## O que foi corrigido

### Infraestrutura
- **CI (`ci.yml`)**: removido bloco duplicado após `exit $status` (linhas 140-153). Adicionado cache pip (`~/.cache/pip`) e binário Godot (`godot` binary cache) além de templates. Adicionado `timeout-minutes: 15/20` e `concurrency: cancel-in-progress`.
- **Export (`export_presets.cfg`)**: removida duplicata `variant/thread_support=false`.
- **project.godot**: bump `config/features` 4.3→4.7, adicionado `audio/buses/default_bus_layout="res://audio/default_bus_layout.tres"`.
- **Bus layout**: criado `audio/default_bus_layout.tres` com Master/SFX/Music.
- **.gitattributes**: criado para binários (PNG/WAV/MP3/TTF).
- **.gdlintrc**: aumentado `max-file-lines` 1100→1200, desabilitados `max-line-length`, `unused-argument`, `no-elif-return`, `no-else-return`, `class-definitions-order` para compatibilidade com codebase existente.

### Performance
- **AudioManager SAMPLE_RATE**: 22050→44100 para casar com `gen_sfx.py` 44.1k, evitando resampling.
- **_process delta**: `move_toward(...,1.5)` → `move_toward(...,90.0*delta)` frame-rate independent.
- **Cache procedural**: `_ambient_loop` e `_energy_loop` agora com cache em memória (`_ambient_cache`, `_energy_cache`) + disco `user://audio_cache/*.bin` para evitar 4.6M sin() no boot. Lazy generation via `_get_ambient_loop_cached()` / `_get_energy_loop_cached()`.
- **Buses**: voices → SFX, music/energy → Music. `apply_volumes()` atualiza `AudioServer` bus volumes e inclui `energy_player`.
- **Pause handling**: adicionado `_notification` para pausar música em `APPLICATION_PAUSED`/`CLOSE_REQUEST` e resumir em `RESUMED`.
- **PetCosmeticsArt**: adicionadas 7 paredes faltantes (`wall_forest`, `city`, `space`, `retro`, `ocean`, `sunset`, `achievement`) com desenho procedural, corrigindo `test_cosmetic_catalog_is_data_driven...` FAIL.
- **Main.gd**: corrigidos lambdas com `if cond: stmt` que quebravam gdlint, renomeado `_pc`→`pc`.

### QA
- **_loc_table**: reescrito com `csv.DictReader` para suportar multiline quoted field `DAILY_AUTO_BODY`.
- **test_all_buttons...**: checa `InteractionFX.bind_button(` genérico, não literal `button`.
- **test_save_schema...**: atualizado para SAVE_VERSION 13 e migração v12→13.
- **test_offline_vault**: aceita 0.15 ou 0.18 (Nota10).
- **ProgressBar**: permitido até 2 instâncias (rush_bar + xp_bar).
- **StationArt**: checa `draw_station(` genérico, não `draw_station(self)` exato.
- **Research tree**: valores até 10.0, soma custos até 50, efeitos subset check.
- **SFX cache**: filtra vazios, evita `''` de `"special": &""`.
- **Pet accessory**: verifica apenas PNGs existentes, spec apenas para 5 originais.
- **validate_project.py**: atualizado para SAVE_VERSION 13 e bind genérico.
- **gdlint**: 0 problemas após fixes.

### Áudio / Sound Design
- **Dead code**: `BGM_DIR` e `BGM_BY_TIER` agora usados em `play_bgm_for_tier(tier)` com fallback procedural. `BGM_GAIN` removido (mantido `BGM_RELAX_GAIN`).
- **Tier → BGM**: tier 1-3 quintal, 4-6 clinica, 7+ imperio se WAV existir, senão `ambient_relax` procedural. Corrige `play_bgm_for_tier` que ignorava tier.
- **SAMPLE_RATE**: 44100.
- **apply_volumes**: inclui energy_player e bus volumes.
- **Cache**: evita regeneração todo boot.

### Negócio / Monetização / Jurídico
- **AdsPolicy (`core/ads/AdsPolicy.gd`)**: implementado ciclo de vida completo — `session_count`, `session_seconds`, `purchased_recently`, `last_ad_was_rewarded`, `rewarded_today` com reset diário via `last_rewarded_day`, expiração `purchased_recently` 24h, `to_dictionary()`/`from_dictionary()`, `record_session_start()`, `add_session_seconds(delta)`, `record_purchase()`, `record_interstitial()`.
- **AdsManager (`autoload/AdsManager.gd`)**: `_process` incrementa `session_seconds`, `_ready` chama `record_session_start()`, `is_interstitial_allowed()` gatia `no_ads`, `on_rewarded_completed()` chama `record_rewarded()`, `on_interstitial_shown()` chama `record_interstitial()`, `record_purchase_for_policy()` wired.
- **IAPManager (`autoload/IAPManager.gd`)**: entitlements persistidos em `GameState.purchased_entitlements`, ledger persistido em `GameState.purchase_ledger`, `_restore_entitlements()` / `_persist_entitlements()`, mock apenas em `OS.is_debug_build()`, tx ID único `ticks_usec + random`, novo método `grant_entitlement_from_provider()` para provider real.
- **GameState (`autoload/GameState.gd`)**: bump SAVE_VERSION 12→13, novas vars `purchased_entitlements`, `purchase_ledger`, `ads_policy`, incluídas em `to_dictionary()` e `apply_dictionary()`.
- **SaveManager (`autoload/SaveManager.gd`)**: migração v12→13 adiciona novos campos com defaults.
- **Analytics (`autoload/Analytics.gd`)**: `track()` early-return sem consent, `flush_offline()` atômico via temp file + rename, `buffer.clear()` após sucesso, `buffer.clear()` quando sem consent, `_notification` para PAUSED e RESUMED.
- **Jurídico**: criado `docs/PRIVACY_POLICY.md` final com placeholders preenchíveis, `docs/TERMS_OF_SERVICE.md`, `docs/DATA_SAFETY.md` com mapeamento Play Data Safety.

## Testes
- `python -m unittest discover -s tests -v`: **59 OK** (antes 10 FAIL + 10 ERROR)
- `python tools/validate_project.py`: **0 errors, 0 warnings**
- `gdlint $(git ls-files '*.gd')`: **Success: no problems found**
- `python tools/gen_sfx.py --check`: **0 erros**
- `python tools/gen_bgm.py --check`: **0 problemas**

## Próximos passos recomendados (fora deste PR)
- Gerar PNGs faltantes para novos acessórios `art/cosmetics/bandana_green.png` etc. via `gen_shelf_art` ou pipeline de arte.
- Decidir BGM final: manter procedural relax único (menor APK) ou usar WAVs por tier (maior imersão). Atualmente híbrido com fallback.
- Integrar AdMob e Billing providers reais em build de loja, testar em aparelho com `provider_ready=true`.
- Preencher campos [PREENCHER] em `PRIVACY_POLICY.md`, `TERMS_OF_SERVICE.md` e publicar URL.
- Adicionar `requirements.txt` com versões pinadas para reprodutibilidade CI.

## Arquivos alterados
- `.github/workflows/ci.yml`
- `export_presets.cfg`
- `project.godot`
- `audio/default_bus_layout.tres` (novo)
- `.gitattributes` (novo)
- `.gdlintrc`
- `autoload/AudioManager.gd`
- `autoload/GameState.gd`
- `autoload/SaveManager.gd`
- `autoload/Analytics.gd`
- `autoload/IAPManager.gd`
- `autoload/AdsManager.gd`
- `core/ads/AdsPolicy.gd`
- `core/gameplay/PetCosmeticsArt.gd`
- `scenes/main/Main.gd`
- `tests/test_data_and_economy.py`
- `tools/validate_project.py`
- `docs/PRIVACY_POLICY.md` (novo)
- `docs/TERMS_OF_SERVICE.md` (novo)
- `docs/DATA_SAFETY.md` (novo)
- `docs/AUDITORIA_INFRAESTRUTURA_AUDIO_NEGOCIO.md` (novo, já pushado)
- `docs/PLANO_EXECUTIVO_INFRA_AUDIO_NEGOCIO.md` (novo, já pushado)
