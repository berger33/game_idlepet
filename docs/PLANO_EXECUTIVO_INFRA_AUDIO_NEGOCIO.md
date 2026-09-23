# Plano Executivo — Infra / Performance / QA + Áudio + Monetização/Jurídico

**Data:** 2026-09-21 (America/Sao_Paulo)  
**Branch base:** `arena/01a0c43a-game-idlepet` @ `caedd74` (feat animações vivas)  
**Regra de ouro:** plano e auditoria sobem no GitHub **antes** de qualquer fix de código.

## Objetivo
Transformar o vertical slice jogável em base **publicável** com CI reprodutível, performance de boot <2s, áudio com contrato determinístico e monetização/LGPD segura sem PII. Tudo offline-first, sem credenciais no repo.

## Escopo não-negociável
- Nenhum SDK binário ou `google-services.json` versionado.
- Saves continuam atômicos XOR+Base64+SHA256 com 3 backups.
- SFX continuam fonte única `tools/gen_sfx.py` → `audio/sfx/*.wav` (44.1k).
- Nenhuma compra real concedida sem provider pronto (mock só em debug com flag explícita).

## Fases

### Fase 0 — Preparação (hoje)
- [x] Recuperar árvore completa via `git reset --hard origin/arena/01a0c221-game-idlepet`
- [x] Rodar `unittest discover`, `validate_project.py`, `gdlint` baseline
- [x] Produzir `AUDITORIA_INFRAESTRUTURA_AUDIO_NEGOCIO.md` + este plano
- [ ] Commit/push dos dois docs

**Critério:** 2 docs em `docs/` com evidência `file:line` e severidade.

### Fase 1 — Infraestrutura (P0)
1. **CI hygiene** (`ci.yml:1-153`)
   - Remover bloco duplicado após `exit $status` (linhas 140-152) — código morto inalcançável.
   - Adicionar `pip cache` + `Godot binary cache` (além de templates).
   - `timeout-minutes: 15` por job, `concurrency` cancel-in-progress.
   - `actions/cache` para `~/.cache/pip` e `godot` binário.
2. **Export presets** (`export_presets.cfg:15-22`)
   - Remover duplicata `variant/thread_support=false` duplicado.
   - Adicionar `include_filter`/`exclude_filter` faltantes (já ok no Web, mas duplicata quebra diff).
3. **project.godot**
   - Alinhar `config/features` de 4.3 para 4.7.2 ou parametrizar via env; adicionar `config_version=5` check.
   - Criar `default_bus_layout.tres` com buses `Master / SFX / Music`.
4. **Higiene de repo**
   - Remover dirs vazios `audio/vo`, `shaders/` vazios ou adicionar `.gdignore`.
   - Adicionar `.gitattributes` para `*.wav binary`, `*.png binary`.

### Fase 2 — Performance (P0/P1)
1. **AudioManager boot jank** (`autoload/AudioManager.gd:40, _ready, _ambient_loop, _energy_loop`)
   - `_ambient_loop`: 352.800 frames × ~13 sin() ≈ 4.6M sin() em GDScript no `_ready`. Mover para thread ou cachear `AudioStreamWAV` gerado em `user://bgm_cache/` na primeira execução.
   - `_energy_loop`: 110k frames similar.
   - Alternativa imediata segura: lazy-load — só gerar quando `music_player` precisa tocar, e usar `ResourceLoader.load_threaded`.
   - Corrigir `SAMPLE_RATE` 22050 vs assets 44100 → usar 44100 para evitar resampling.
2. **Fades frame-rate dependent** (`AudioManager.gd:_process`)
   - `move_toward(..., 1.5)` ignora delta → trocar por `move_toward(..., 1.5*delta*60)` ou `lerpf` com delta.
3. **GameState/SaveManager _process**
   - `GameState._process` checa `hired_staff.size()<=1` todo frame; mover para timer 5s já existe mas accumulator ainda corre todo frame — ok, mas adicionar early-out se `eco_mode`.
   - `SaveManager._process` já usa `RemoteConfig autosave_seconds` — garantir `PROCESS_MODE_ALWAYS` mantido.
4. **PetShopCanvas**
   - Garantir `queue_redraw()` só quando necessário, não todo `_process`.
   - Pool de `Bubble`/`Fur` — evitar `add_child`/`queue_free` por tick.

### Fase 3 — QA (P0)
1. **Testes Python**
   - Corrigir `_loc_table` em `tests/test_data_and_economy.py:776` — usar `csv` module para lidar com multiline quoted field `DAILY_AUTO_BODY`.
   - Atualizar `test_all_buttons_use_universal_interaction_feedback` — procurar `InteractionFX.bind_button(` genérico, não literal `button`.
   - Corrigir `test_offline_vault...` — `offline_rate` default mudou 0.15→0.18, atualizar teste ou documentar como breaking change intencional.
   - Corrigir `test_every_sfx_played_is_cached` — cache contém `''` por bug de parse? Verificar `play_progress` com `sfx` vazio.
2. **CI gates**
   - Adicionar `pip cache`, `Godot binary cache`, `timeout`.
   - Rodar `validate_project.py` já existe, mas adicionar `verify_pet_animations` com threshold de alpha.
   - Adicionar step `python tools/gen_bgm.py --check` já existe.
3. **Godot domain tests**
   - Manter `domain_tests.tscn` e `smoke_interact.gd` com `SCRIPT ERROR` fail — já implementado, garantir não regressa.

### Fase 4 — Áudio / Sound Design (P0/P1)
1. **Dead code** (`AudioManager.gd:36-40`)
   - `BGM_DIR`, `BGM_BY_TIER`, `_load_bgm`, `BGM_GAIN` não usados. Remover ou religar.
   - Se manter procedural, remover `audio/bgm/*.wav` 5.1MB do repo ou mover para `docs/` como referência, ou fazer `gen_bgm.py` gerar sob demanda.
2. **Tier → BGM**
   - `play_bgm_for_tier(_tier)` ignora tier → sempre `ambient_relax`. Decisão: manter relax como padrão (pedido usuário) mas logar tier para futura troca, ou implementar crossfade real com `BGM_BY_TIER`.
3. **Buses**
   - Criar `audio/bus_layout.tres` com `Master`, `SFX`, `Music`. `AudioManager` voices → `SFX`, music/energy → `Music`.
   - `apply_volumes()` deve setar `AudioServer.set_bus_volume_db` além de player volume.
4. **SAMPLE_RATE**
   - Mudar `SAMPLE_RATE` para 44100 para casar com `gen_sfx.py` e `gen_bgm.py`.
5. **Performance síntese**
   - Cachear loops em `AudioStreamWAV` em disco (`user://`) após primeira geração, ou pré-gerar via `tools/gen_bgm.py` e carregar.

### Fase 5 — Monetização / Negócio / Jurídico (P0 crítico)
1. **AdsPolicy wiring** (`core/ads/AdsPolicy.gd`, `autoload/AdsManager.gd`)
   - `session_count`, `session_seconds`, `purchased_recently`, `last_ad_was_rewarded`, `rewarded_today` nunca atualizados.
   - Implementar: `AdsManager._process` incrementa `session_seconds`; `session_count` incrementa em `_ready` via `SaveManager` ou `GameState`; `record_rewarded()` chamado no callback de reward; `rewarded_today` reset diário via `Time.get_date_string_from_system()`.
   - `last_ad_was_rewarded` deve ser reset após interstitial ou após cooldown.
   - `purchased_recently` setado quando `IAPManager` concede `no_ads` ou qualquer compra nas últimas 24h.
2. **IAP entitlements persistência** (`autoload/IAPManager.gd`, `autoload/GameState.gd`, `autoload/SaveManager.gd`)
   - `entitlements` dict em memória → persistir em `GameState` (`purchased_entitlements: Dictionary`) e serializar em `to_dictionary()`.
   - `PurchaseLedger` também persistir em `GameState` ou arquivo separado `user://ledger.json` com `to_dictionary()`.
   - `has_entitlement` deve ler de `GameState` além de memória.
   - `purchase()` quando `provider_ready==false` **não** deve conceder mock em release — apenas se `OS.is_debug_build()` ou flag `MOCK_IAP=true`. Remover grant automático.
   - Ledger `tx` id com timestamp colide — usar `UUID` ou `Time.get_ticks_usec()` + sku, e garantir idempotência real.
3. **no_ads gating**
   - `AdsManager.is_interstitial_allowed()` e `is_rewarded_available()` devem retornar false se `IAPManager.has_entitlement(&"no_ads")`.
4. **Analytics** (`autoload/Analytics.gd`)
   - `flush_offline()` abre `WRITE` (trunca) e escreve buffer, mas não limpa buffer → duplicatas no próximo flush. Corrigir: após escrever com sucesso, `buffer.clear()` ou manter fila e escrever atomicamente via temp file.
   - Buffer `MAX_BUFFER 500` com `pop_front()` perde eventos antigos — ok, mas documentar.
   - `consent_given()` default false — garantir que `buffer` é descartado quando consent revogado (já remove arquivo, mas buffer permanece em memória).
   - Adicionar `flush_offline()` em `_notification(APPLICATION_PAUSED)`.
5. **Jurídico**
   - `PRIVACY_POLICY_DRAFT.md` → criar `PRIVACY_POLICY.md` final com placeholders claros: controller, email, retenção, subprocessadores, bases legais LGPD/GDPR, idade, Data Safety.
   - Criar `TERMS_OF_SERVICE.md` stub com EULA padrão, compras, reembolso, conduta.
   - Criar `docs/DATA_SAFETY.md` mapeando permissões, coleta, criptografia, deleção.
   - Garantir que `Analytics` só persiste se consent.

### Fase 6 — Validação final
- Rodar `python -m unittest discover -s tests -v` — meta 0 falhas.
- Rodar `python tools/validate_project.py` — 0 erros.
- Rodar `gdlint $(git ls-files '*.gd')` — 0.
- Godot headless import + smoke 120 frames + domain_tests + smoke_interact — sem `SCRIPT ERROR`.
- Medir boot: `time godot --headless --quit-after 10` antes/depois.
- Gerar artefatos: `audio/sfx/*.wav` sync, `audio/bgm` opcional.

## Riscos e mitigação
- **Quebra de save:** qualquer mudança em `GameState.to_dictionary()` exige bump `SAVE_VERSION` + migração. Mitigação: manter compat, adicionar campos opcionais com default.
- **Áudio regressão:** mudar SAMPLE_RATE pode alterar pitch. Mitigação: testes `SoundDesignTests` + `gen_sfx --check`.
- **Monetização falsa:** remover mock pode quebrar dev flow. Mitigação: manter mock apenas em debug com flag.

## Entregáveis
1. `docs/AUDITORIA_INFRAESTRUTURA_AUDIO_NEGOCIO.md` — achados com severidade e `file:line`.
2. Este plano.
3. Código fixado (CI, AudioManager, AdsPolicy, IAPManager, Analytics, bus_layout).
4. Testes verdes.

## Cronograma estimado (dev solo)
- Fase 0: 1h
- Fase 1: 2h
- Fase 2: 3h
- Fase 3: 2h
- Fase 4: 3h
- Fase 5: 4h
- Fase 6: 1h
Total ~16h.
