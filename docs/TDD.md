# Technical Design Document

## Objetivos
Godot 4.3+, portrait 1080×1920, offline-first, estado determinístico e dados versionados. Mid-range 60 fps; low 30 fps. Não acoplar gameplay a SDK Android.

## Camadas

1. **Presentation:** `scenes/`, views e UI. Escuta EventBus; não escreve arquivos.
2. **Domain:** `core/gameplay`, economy/progression. Máquinas de estado e fórmulas testáveis.
3. **State:** GameState autoritativo e serializável.
4. **Infrastructure:** save, analytics, tempo, áudio e adapters futuros de SDK.
5. **Data:** JSON versionado; remote config sobrepõe allowlist de defaults.

Dependência aponta para baixo; SDKs implementam interfaces/adapters e nunca são chamados diretamente por UI.

## Autoloads

| Nome | Responsabilidade | Lê/escreve | Emite/consome |
|---|---|---|---|
| EventBus | contrato de sinais | nada | todos os eventos de domínio |
| RemoteConfig | defaults + allowlist | config | futuro config_updated |
| Economy | funções puras | RemoteConfig | nenhum |
| GameState | estado de progresso | payload save | currency/combo/review/upgrade |
| SaveManager | integridade, backup, migração | `user://save*` | save_completed |
| AudioManager | cache e playback | settings | ações explícitas |
| Analytics | fila offline | JSONL user | taxonomia |
| TimeManager | elapsed seguro | clock | churn signal |
| HapticsManager | vibração opt-in | settings | ações explícitas |

## Scene graph atual

```text
Main (Control, Main.gd)
├── PetShopCanvas (Control, procedural world)
├── TopBar (HBox: coins/review/combo/clip marker)
├── OrderCard
├── BottomPanel
│   └── VBox
│       ├── Instruction
│       ├── ProgressRow (ProgressBar + timer)
│       ├── PrimaryAction
│       └── UpgradeAction
├── ResultPanel
└── ToastLayer
```

Futuro: `MainShell` troca Home/PetShop/Collections por SceneRouter; PetShop contém World, Stations, Customers, VFXPool e HUD. Estações recebem ServiceDefinition Resource/JSON e instanciam controlador de minijogo. Cenas pesadas são `ResourceLoader.load_threaded_request`.

## Serviço de banho
`BathService` é RefCounted sem frame allocation intencional. Estados WAITING/ACTIVE/COMPLETE/FAILED. `rub()` integra distância de ponteiro com cap por evento para impedir teleporte; `tick(delta)` controla deadline; `finish()` classifica contra RemoteConfig. UI apenas projeta estado.

## Save
Envelope JSON → SHA-256(payload+key) → XOR → Base64. Escrita temporária, rotação de 3 backups, rename. Isto é ofuscação e integridade acidental, **não criptografia contra atacante**. Dados pagos e rankings exigem autoridade server-side. Migrações são incrementais e nunca removem chave sem fase de compatibilidade. Autosave 15 s, pausa e close.

## Offline/clock
Tempo de parede só no retorno; rollback rende zero e breadcrumb. Delta positivo clamped a 48 h antes do cap econômico. Futuro servidor fornece trusted offset quando online. Reward deve possuir transaction id persistido antes de exibição para idempotência.

## Analytics
`Analytics.track` aceita nome estável e parâmetros sem PII, mantém 500 eventos e grava lote local. Adapter Firebase futuro mapeia consentimento e limites de parâmetros. Eventos críticos são persistidos antes de chamada SDK. Debug builds habilitam inspector, release não loga payload sensível.

## Ads/IAP/Remote SDK
Interfaces planejadas: `AdsProvider`, `BillingProvider`, `AnalyticsProvider`, `CrashProvider`, `ConfigProvider`, `ShareProvider`. Cada uma tem Fake/NoOp e Android implementation. AdsManager aplica caps localmente **antes** do provider. Billing usa preço da Store, acknowledge, restore, pending purchase e validação backend. Remote payload é assinado/versionado para economia sensível.

## Performance
Pet/VFX/floating number pools têm capacidade e degradação; atlas por estabelecimento; ETC2 fallback/ASTC; no `_process` criando dicionários no gameplay final. Arte procedural atual gera pontos por frame e será cacheada/substituída no VS após profile. Budgets capturados por profiler físico: draw calls <100, memória <300 MB, p95 frame <16,7 ms mid.

## Segurança e privacidade
Sem secrets no projeto/export preset. Keystore via ambiente/CI. Consent state precede SDK ad/analytics quando aplicável. Advertising ID só com necessidade declarada. Save XOR não é divulgado como proteção forte. Logs não contêm PII nem receipt completo.

## Test strategy
- Unit/domain: fórmula, BathService boundaries, migração, idempotência.
- Integration: save/load/corrupt backup, pause/resume, adapter fake.
- Scene smoke: instantiate Main headless, parse JSON, sinais sem órfãos.
- Device: API 24/low, current/mid, current/high; offline/slow/background/clock.
- Release: AAB install via internal track, billing test, test ads, consent, ANR/crash.

## Build
Dev usa renderer GL compatibility. Android min 24/target 36 no preset; target deve acompanhar exigência vigente no release. Export template e plugins devem corresponder exatamente à minor do Godot. Package é placeholder bloqueante. CI futura roda `godot --headless --path . --editor --quit`, testes, export debug e artifact size.
