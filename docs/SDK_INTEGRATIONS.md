# Integrações Android — Plano Seguro

Nenhum SDK binário ou credencial é versionado nesta fundação. Instalar versões compatíveis com a minor exata do Godot somente no milestone V0.5/0.6, após auditoria de licença, manutenção, data collection e release notes.

## AdMob
Provider encapsulado deve implementar load/show/callback; `AdsPolicy` aplica primeiro 3 sessões, mínimo 20 min, cooldown ≥3 min e cap ≤8 rewarded/dia, mesmo se Remote Config pedir menos restrição. Usar IDs oficiais de teste em debug; release IDs via recurso local excluído/remote config verificado. Reward tem UUID persistido e é concedido uma vez somente após callback de complete. Nunca clicar test ad manualmente repetidamente fora do fluxo permitido.

## Billing
SKUs: starter, no_ads, brasa_small/medium/large, bath_pass, cosmetic_pack. Consultar preço localizado; tratar pending, cancel, already-owned, restore e acknowledge. Consumíveis exigem backend/Play Developer API antes de grant comercial. `PurchaseLedger` é apenas dedupe local/fallback, não valida compra. No Ads é entitlement não consumível e restaurável.

## Firebase
Analytics adapter drena fila após consentimento; Crashlytics registra breadcrumbs categóricos sem PII; Remote Config valida allowlist/tipo/faixa e guarda last-known-good. `google-services.json` não deve ser tratado como segredo forte, mas usa arquivo específico do ambiente e não entra neste repo até configuração de CI/publisher.

## Notifications/Share
Local notification respeita opt-in, quiet hours e máximo 2/dia. MediaProjection pede consentimento do SO em cada sessão apropriada; sem microfone por padrão. Spike mede memória, frame time, temperatura, arquivo e cancelamento. Fallback é screenshot/share nativo; analytics `clip_exported` só depois do MP4 válido.

## Validação em aparelho
Build internal signed → Firebase DebugView → test rewarded callbacks → background/kill during ad → billing license testers → pending purchase → restore reinstall → consent reset → offline. Evidências e versões entram no relatório de release.
