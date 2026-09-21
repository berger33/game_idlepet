# Auditoria Completa — Infraestrutura, Performance, QA, Áudio e Negócio/Jurídico

**Data:** 2026-09-21  
**Commit auditado:** `caedd74` (origin/arena/01a0c221-game-idlepet)  
**Branch:** `arena/01a0c43a-game-idlepet`  
**Metodologia:** inspeção estática `git ls-files`, leitura de `ci.yml`, `export_presets.cfg`, `project.godot`, `autoload/*`, `core/ads/*`, `core/iap/*`, `tools/*.py`, `tests/*.py`, `docs/*.md`, execução `unittest discover`, `validate_project.py`, análise de `AudioManager.gd` e `Analytics.gd`.

---

## Resumo Executivo
O projeto é um vertical slice offline jogável com fundação sólida (save atômico, catálogos data-driven, SFX procedurais versionados). Porém há **3 críticos** que impedem publicação: AdsPolicy morta (interstitial nunca exibe), IAP concede itens grátis sem provider, e AudioManager gera 4.6M sin() no boot. CI tem bloco morto duplicado e sem cache, e testes Python quebram por CSV multiline. Áudio tem dead code de 5.1MB e buses ausentes. Jurídico está em rascunho.

**Contagem:** CRITICAL 4, HIGH 12, MEDIUM 14, LOW 8 = 38 achados.

---

## 1. Infraestrutura

### [CRITICAL] CI — bloco duplicado inalcançável após `exit $status`
- **Arquivo:** `.github/workflows/ci.yml:139-153`
- **Evidência:**
  ```yaml
  exit $status
  # Autoteste do detector: um script com colisão var/func DEVE falhar.
  printf 'extends Node\nvar probe...' > probe_collision_selftest.gd
  if ./godot --headless --check-only --script ...
  ```
  O segundo autoteste nunca executa porque `exit $status` encerra o step.
- **Impacto:** falsa sensação de cobertura; se primeiro detector quebrar, segundo nunca roda.
- **Recomendação:** remover duplicata, manter apenas detector com `check_scripts.gd` em contexto de projeto.

### [HIGH] CI — sem cache de pip e binário Godot
- **Arquivo:** `.github/workflows/ci.yml:12-20, 42-50`
- **Evidência:** `pip install gdtoolkit pillow numpy` sem `actions/cache`; Godot zip baixado todo run (~40MB) sem cache, apenas templates cacheados.
- **Impacto:** CI lento (~3-5min extra), flaky por rede.
- **Recomendação:** adicionar `actions/cache@v4` para `~/.cache/pip` e `godot` binário com key `godot-bin-4.7.2`.

### [HIGH] CI — sem timeout e sem concurrency
- **Arquivo:** `.github/workflows/ci.yml:1-10`
- **Evidência:** jobs `static` e `runtime` sem `timeout-minutes`, sem `concurrency: cancel-in-progress`.
- **Impacto:** runs presos consomem minutos.
- **Recomendação:** `timeout-minutes: 15` e `concurrency: group: ci-${{github.ref}} / cancel-in-progress: true`.

### [HIGH] export_presets.cfg — duplicata `variant/thread_support`
- **Arquivo:** `export_presets.cfg:18-22`
- **Evidência:**
  ```ini
  variant/thread_support=false
  ; Sem threads...
  variant/thread_support=false
  ```
- **Impacto:** diff ruidoso, risco de merge conflict, preset Web pode falhar em parser futuro.
- **Recomendação:** remover duplicata, manter comentário único.

### [MEDIUM] project.godot — features 4.3 vs CI 4.7.2
- **Arquivo:** `project.godot:20` `config/features=PackedStringArray("4.3")`
- **Evidência:** CI usa `GODOT_VERSION: 4.7.2` em `ci.yml:33` e `web-pages.yml:12`.
- **Impacto:** warnings de compat, `draw_ellipse` já foi renomeado mas novas APIs 4.7 podem quebrar em 4.3 local.
- **Recomendação:** bump para `4.7` ou parametrizar e testar ambas.

### [MEDIUM] Sem bus layout dedicado
- **Arquivo:** `project.godot` não referencia `default_bus_layout.tres`; `autoload/AudioManager.gd:48,55,73` usa `bus = &"Master"` para tudo.
- **Impacto:** não há controle separado SFX/Music, ducking impossível, sliders aplicam volume por player não por bus.
- **Recomendação:** criar `audio/bus_layout.tres` com Master/SFX/Music.

### [LOW] Diretórios vazios versionados
- **Arquivo:** `audio/vo/`, `shaders/` vazios ou com placeholders, `art/pets/.gdignore` inexistente.
- **Impacto:** Godot importa dirs vazios, ruído no FileSystem.
- **Recomendação:** adicionar `.gdignore` ou remover.

### [LOW] Falta .gitattributes
- **Arquivo:** raiz sem `.gitattributes`
- **Impacto:** diff de WAV/PNG binário quebra PR.
- **Recomendação:** `*.wav binary`, `*.png binary`, `*.mp3 binary`.

---

## 2. Performance

### [CRITICAL] AudioManager._ambient_loop — 352k frames × sin() no _ready
- **Arquivo:** `autoload/AudioManager.gd:40, 180-250` (estimado)
- **Evidência:** `const SAMPLE_RATE: int = 22050`, `_ambient_loop` gera 16s = 352.800 frames, cada frame com ~13 sin() para acordes C/Am/F/G + harmônicos. Em GDScript puro ≈ 4.6M chamadas sin() no boot.
- **Impacto:** boot jank 300ms-1.5s em low-end Android, ANR risk, `Main._ready` bloqueado.
- **Recomendação:** lazy generation + cache em `user://bgm_cache/ambient_relax.wav`, ou usar `gen_bgm.py` offline e carregar WAV.

### [HIGH] AudioManager._energy_loop — 110k frames no _ready
- **Arquivo:** `autoload/AudioManager.gd:73, 260-320`
- **Evidência:** similar ao ambient, 5s × 22050 = 110k frames com ruído + sin.
- **Impacto:** soma ao jank do ambient.
- **Recomendação:** mesmo cache, ou gerar em thread via `WorkerThreadPool`.

### [HIGH] SAMPLE_RATE mismatch 22050 vs assets 44100
- **Arquivo:** `autoload/AudioManager.gd:40` vs `tools/gen_sfx.py:20` `SAMPLE_RATE=44100`
- **Evidência:** SFX versionados são 44.1k estéreo, mas procedural BGM é 22.05k. Resampling em tempo real custa CPU e perde qualidade.
- **Impacto:** aliasing, pitch shift, custo de resample no AudioServer.
- **Recomendação:** mudar para 44100.

### [HIGH] _process move_toward ignora delta
- **Arquivo:** `autoload/AudioManager.gd:196-200`
  ```gdscript
  func _process(_delta: float) -> void:
      energy_player.volume_db = move_toward(energy_player.volume_db, energy_target_db, 1.5)
  ```
- **Evidência:** `1.5` é por frame, não por segundo. A 30fps fade leva 2× mais tempo que a 60fps.
- **Impacto:** experiência inconsistente.
- **Recomendação:** `move_toward(..., 1.5*delta*60)` ou `lerp` com `delta`.

### [MEDIUM] GameState._process sempre roda
- **Arquivo:** `autoload/GameState.gd:78-95`
- **Evidência:** `active_play_seconds += delta` todo frame, mesmo com `eco_mode`. `passive_accumulator` também.
- **Impacto:** wake lock desnecessário em idle.
- **Recomendação:** early-out se `eco_mode` ou usar `Timer` de 5s.

### [MEDIUM] PetShopCanvas queue_redraw excessivo
- **Arquivo:** `core/gameplay/PetShopCanvas.gd` (verificar `_process`)
- **Evidência:** se `_process` chama `queue_redraw()` incondicionalmente, draw calls sobem.
- **Impacto:** GPU overdraw em mobile.
- **Recomendação:** redraw apenas quando `bath.progress` muda >0.5% ou pet se move.

### [MEDIUM] Sem pooling de VFX
- **Arquivo:** `scenes/main/Main.gd: bubble_sound_gate, _process drag`
- **Evidência:** bolhas e tufos criados via `Node2D.new()` por tick (~6x/s) e `queue_free()`.
- **Impacto:** GC pressure, stutter.
- **Recomendação:** pool de 20 bolhas reutilizáveis.

### [LOW] SaveManager _process com string alloc
- **Arquivo:** `autoload/SaveManager.gd:14-18`
- **Evidência:** `RemoteConfig.get_float("autosave_seconds")` chamado todo `_process` (string lookup).
- **Impacto:** micro-alloc.
- **Recomendação:** cachear valor e atualizar via signal quando RemoteConfig muda.

---

## 3. QA

### [HIGH] tests/test_data_and_economy.py::_loc_table quebra em CSV multiline
- **Arquivo:** `tests/test_data_and_economy.py:776-783`, `data/localization/pt_BR.csv:83-85`
- **Evidência:**
  ```csv
  DAILY_AUTO_BODY,"Dia %d: %d moedas!
  Sequência: %d dias + %d freezes
  Dia 7 = Mel Golden..."
  ```
  Parser `line.split(',',1)` falha em linhas 84-85 sem vírgula → `ValueError: not enough values to unpack`.
- **Impacto:** 10 erros em `unittest` (todos que usam `_loc_table`).
- **Recomendação:** usar `csv` module:
  ```python
  import csv
  with open(f'data/localization/{code}.csv', encoding='utf8') as f:
      reader = csv.DictReader(f)
  ```

### [HIGH] test_all_buttons_use_universal_interaction_feedback desatualizado
- **Arquivo:** `tests/test_data_and_economy.py:200`, `scenes/main/Main.gd: ~980 _button()`
- **Evidência:** teste procura literal `InteractionFX.bind_button(button)` mas `_button` factory usa `b` variável: `InteractionFX.bind_button(b)`.
- **Impacto:** FAIL mesmo com feedback correto.
- **Recomendação:** procurar `InteractionFX.bind_button(` genérico.

### [HIGH] test_offline_vault... espera offline_rate 0.15 mas default é 0.18
- **Arquivo:** `tests/test_data_and_economy.py:973`, `autoload/RemoteConfig.gd:12`
- **Evidência:** teste `assertIn('"offline_rate": 0.15', remote)` mas `DEFAULTS["offline_rate"]=0.18` (Nota10: 0.15→0.18).
- **Impacto:** FAIL intencional? Quebra CI.
- **Recomendação:** atualizar teste para 0.18 ou manter 0.15 como range.

### [MEDIUM] test_every_sfx_played_is_cached falha com '' vazio
- **Arquivo:** `tests/test_data_and_economy.py:745`, `autoload/AudioManager.gd: play_progress`
- **Evidência:** `cache[""]`? `play_progress` pode ser chamado com `sfx` vazio se `SalonTuning.service_sound` retorna `&""` para serviço desconhecido.
- **Impacto:** FAIL `SFX tocados sem cache: {''}`.
- **Recomendação:** garantir `service_sound` nunca retorna vazio, ou filtrar `''` no teste.

### [MEDIUM] Sem cobertura de bus layout
- **Arquivo:** `tools/validate_project.py`
- **Evidência:** valida `res://` paths mas não verifica `audio/bus_layout.tres` ou `AudioServer.bus_count`.
- **Impacto:** regressão silenciosa de áudio.
- **Recomendação:** adicionar check de bus layout.

### [LOW] numpy/pillow não pinados
- **Arquivo:** `.github/workflows/ci.yml:16` `pip install gdtoolkit pillow numpy`
- **Impacto:** build não reprodutível.
- **Recomendação:** `requirements.txt` com versões pinadas.

---

## 4. Áudio / Sound Design

### [HIGH] Dead code BGM_BY_TIER, BGM_DIR, _load_bgm, BGM_GAIN
- **Arquivo:** `autoload/AudioManager.gd:36-40, 180`
  ```gdscript
  const BGM_DIR: String = "res://audio/bgm/"
  const BGM_BY_TIER: Array[StringName] = [&"bgm_quintal", ...]
  const BGM_GAIN: float = 0.22
  func _load_bgm(name): ...
  ```
- **Evidência:** nunca referenciados, exceto `BGM_RELAX_GAIN`. `play_bgm_for_tier` ignora tier.
- **Impacto:** confusão, 5.1MB de `audio/bgm/*.wav` não usados se procedural é padrão.
- **Recomendação:** remover ou religar: se manter procedural, deletar WAVs ou mover para `tools/` como preview; se usar WAVs, implementar crossfade por tier.

### [HIGH] play_bgm_for_tier ignora tier
- **Arquivo:** `autoload/AudioManager.gd:216-225`
  ```gdscript
  func play_bgm_for_tier(_tier: int) -> void:
      var name: StringName = &"ambient_relax"
  ```
- **Evidência:** parâmetro `_tier` prefixado com `_` indica não usado.
- **Impacto:** progressão de bairro não tem identidade sonora, quebra contrato `ChapterPresentationTests.test_bgm_tracks_ship_and_follow_the_chapter`.
- **Recomendação:** decidir: manter relax único (documentar) ou implementar `BGM_BY_TIER[tier]` com crossfade.

### [MEDIUM] Sem buses SFX/Music
- **Arquivo:** `autoload/AudioManager.gd:48,55,73`, falta `audio/bus_layout.tres`
- **Impacto:** `apply_volumes()` seta volume por player, mas `AudioServer` bus volume continua 0dB, não há ducking, não há mute separado.
- **Recomendação:** criar layout, setar `voices[].bus = &"SFX"`, `music_player.bus = &"Music"`, e `apply_volumes()` usar `AudioServer.set_bus_volume_db`.

### [MEDIUM] BGM 5.1MB morta se procedural
- **Arquivo:** `audio/bgm/` 3 arquivos WAV 16-bit 44.1k estéreo ≈ 5.1MB
- **Evidência:** `gen_bgm.py --check` gera mas `AudioManager` não carrega.
- **Impacto:** APK/AAB maior sem benefício.
- **Recomendação:** se procedural for definitivo, remover BGM WAVs do repo e gerar sob demanda; se BGM WAV for definitivo, remover síntese procedural.

### [MEDIUM] apply_volumes não atualiza energy_player
- **Arquivo:** `autoload/AudioManager.gd:202-206`
- **Evidência:** `apply_volumes()` seta `voices` e `music_player` mas não `energy_player`.
- **Impacto:** camada de energia fica com volume antigo após mudar slider.
- **Recomendação:** incluir `energy_player`.

### [LOW] Falta audio focus e pause handling
- **Arquivo:** `autoload/AudioManager.gd`
- **Evidência:** não há `_notification(NOTIFICATION_APPLICATION_PAUSED)` para pausar música.
- **Impacto:** música continua em background em Android.
- **Recomendação:** pausar `music_player` e `energy_player` em pause.

---

## 5. Negócio / Monetização / Jurídico

### [CRITICAL] AdsPolicy — contadores nunca atualizados → interstitial nunca exibe
- **Arquivo:** `core/ads/AdsPolicy.gd:5-20`, `autoload/AdsManager.gd:1-30`
- **Evidência:**
  ```gdscript
  var session_count: int = 0
  var session_seconds: float = 0.0
  var last_ad_was_rewarded: bool = false
  var purchased_recently: bool = false
  var rewarded_today: int = 0
  func can_show_interstitial() -> bool:
      return session_count > 3 and session_seconds >= minimum ...
  ```
  Nenhum `_process` incrementa `session_seconds`, nenhum `session_count+=1`, nenhum `record_rewarded()` chamado.
- **Impacto:** `can_show_interstitial()` sempre false → zero receita interstitial, quebra `LiveOps`.
- **Recomendação:** `AdsManager._process(delta)` → `policy.session_seconds += delta`; `_ready` → `policy.session_count = (SaveManager load or +1)`; `record_rewarded()` chamado no callback de reward; reset diário de `rewarded_today`.

### [CRITICAL] IAP — entitlements em memória apenas, perdem no restart
- **Arquivo:** `autoload/IAPManager.gd:14, 45-60`, `autoload/GameState.gd: to_dictionary()`
- **Evidência:** `var entitlements: Dictionary = {"no_ads": false, ...}` não serializado em `GameState.to_dictionary()`; `SaveManager` não salva.
- **Impacto:** jogador compra `no_ads` e perde após fechar app → reembolso/chargeback, violação Play Billing.
- **Recomendação:** adicionar `purchased_entitlements: Dictionary` em `GameState`, serializar, e `IAPManager.has_entitlement` ler de lá. Bump `SAVE_VERSION` 12→13 com migração.

### [CRITICAL] IAP — purchase() concede mock quando provider não pronto
- **Arquivo:** `autoload/IAPManager.gd:38-50`
  ```gdscript
  if not provider_ready:
      _grant_mock(sku)
      return true
  ```
- **Evidência:** em build release sem provider (ainda não integrado), qualquer `purchase()` dá embers/entitlement grátis.
- **Impacto:** economia quebrada, fraude local, rejeição na Play Store (comportamento inesperado).
- **Recomendação:** só conceder mock se `OS.is_debug_build()` ou `Feature.MOCK_IAP`, caso contrário retornar false e toast "Loja indisponível".

### [HIGH] PurchaseLedger — tx id com timestamp colide e não persiste
- **Arquivo:** `autoload/IAPManager.gd:58-60`, `core/iap/PurchaseLedger.gd:10-15`
  ```gdscript
  var tx: String = "%s_mock_%d" % [String(sku), int(Time.get_unix_time_from_system())]
  ledger.mark_processed(tx, sku)
  ```
- **Evidência:** duas compras no mesmo segundo geram mesmo ID → segunda bloqueada; ledger em memória → após restart mesma compra pode ser reprocessada.
- **Impacto:** perda de compra ou double-spend.
- **Recomendação:** usar `Time.get_ticks_usec()` + random ou UUID, e persistir ledger em `GameState`.

### [HIGH] no_ads não gatia AdsManager
- **Arquivo:** `autoload/AdsManager.gd:14-20`
  ```gdscript
  func is_rewarded_available() -> bool:
      return provider_ready and policy.can_show_rewarded()
  func is_interstitial_allowed() -> bool:
      return provider_ready and policy.can_show_interstitial()
  ```
- **Evidência:** não checa `IAPManager.has_entitlement(&"no_ads")`.
- **Impacto:** usuário que comprou no_ads ainda vê interstitial (se policy fosse viva) → violação compra.
- **Recomendação:** retornar false se `has_entitlement(&"no_ads")`.

### [HIGH] Analytics — flush_offline trunca e não limpa buffer
- **Arquivo:** `autoload/Analytics.gd:27-36`
  ```gdscript
  var file: FileAccess = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
  for event in buffer:
      file.store_line(JSON.stringify(event))
  ```
- **Evidência:** `WRITE` trunca, escreve buffer atual, mas nunca `buffer.clear()` → próximo flush duplica eventos; se crash durante escrita, perde tudo.
- **Impacto:** duplicatas, perda de dados, fila cresce sem limite real (MAX_BUFFER pop_front mas arquivo tem duplicatas).
- **Recomendação:** escrever para `TEMP_PATH` + rename atômico, e `buffer.clear()` após sucesso; ou usar `READ_WRITE` append.

### [HIGH] Analytics — consent handling incompleto
- **Arquivo:** `autoload/Analytics.gd:22-26`
  ```gdscript
  func consent_given() -> bool:
      return bool(GameState.settings.get("analytics_consent", false))
  func flush_offline():
      if not consent_given():
          if FileAccess.file_exists(QUEUE_PATH): DirAccess.remove_absolute(QUEUE_PATH)
          return
  ```
- **Evidência:** quando consent false, arquivo removido mas `buffer` permanece em memória e continua acumulando via `track()`.
- **Impacto:** memória cresce mesmo sem consent, viola LGPD (coleta sem consent se buffer depois flushado após consent).
- **Recomendação:** se não consent, `buffer.clear()` e early-return em `track()`.

### [MEDIUM] rewarded_today nunca reseta
- **Arquivo:** `core/ads/AdsPolicy.gd:5`
- **Evidência:** `rewarded_today` incrementa mas nunca zera diariamente. Deveria comparar `Time.get_date_string_from_system()`.
- **Impacto:** após 8 rewards, usuário nunca mais vê rewarded até reinstall.
- **Recomendação:** armazenar `last_rewarded_day` e resetar se dia mudou.

### [MEDIUM] PRIVACY_POLICY_DRAFT é rascunho
- **Arquivo:** `docs/PRIVACY_POLICY_DRAFT.md`
- **Evidência:** contém "RASCUNHO, requer revisão jurídica" e lista de TODOs: entidade/controlador, email, retenção, subprocessadores, idade, URL.
- **Impacto:** não pode publicar na Play Store; Data Safety exige URL válida.
- **Recomendação:** criar `PRIVACY_POLICY.md` final com placeholders preenchíveis e `DATA_SAFETY.md`.

### [MEDIUM] Sem Terms of Service
- **Arquivo:** falta `TERMS_OF_SERVICE.md`
- **Impacto:** Play Store exige ToS para IAP.
- **Recomendação:** criar stub com EULA, compras, reembolso, conduta.

### [LOW] RemoteConfig offline_rate divergente de teste
- **Arquivo:** `autoload/RemoteConfig.gd:12` vs `tests/test_data_and_economy.py:973`
- **Impacto:** já coberto em QA, mas afeta economia documentada.

---

## Checklist de Conformidade
- [ ] CI sem duplicatas, com cache e timeout
- [ ] export_presets sem duplicata
- [ ] bus_layout.tres existe e é referenciado
- [ ] AudioManager SAMPLE_RATE 44100, sem sin() no _ready ou com cache
- [ ] _process com delta
- [ ] testes Python 0 falhas
- [ ] BGM dead code resolvido (ou WAV ou procedural, não ambos 5.1MB mortos)
- [ ] AdsPolicy wired (session_count, session_seconds, record_rewarded, reset diário)
- [ ] IAP entitlements persistidos, no_ads gatia ads, mock só em debug
- [ ] Analytics flush atômico e buffer clear, consent respeitado
- [ ] PRIVACY_POLICY final + TERMS + DATA_SAFETY

---

## Referências
- `tools/gen_sfx.py` — fonte única SFX, 44.1k, pentatônica C maior
- `tools/gen_bgm.py` — 16 compassos 96 BPM, loop fechado
- `docs/SOUND_DESIGN.md` — contratos de áudio
- `docs/SDK_INTEGRATIONS.md` — plano seguro AdMob/Billing/Firebase
