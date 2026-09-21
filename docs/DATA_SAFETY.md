# Data Safety & App Privacy — Mapeamento

**App:** PetShop Tycoon — Do Banho à Rede  
**Versão auditada:** SAVE v13, Godot 4.7.2  
**Data:** 2026-09-21

## Play Data Safety (preencher no Console)

### Coleta
- **Não coleta por padrão (offline):** nome, e-mail, localização precisa, contatos, fotos, microfone.
- **Coleta opcional com consentimento:**
  - **Analytics (com opt-in):** ID de instalação, eventos de uso (`service_completed`, `level_up`), duração de sessão, versão do app, país. Finalidade: analytics, diagnóstico. Criptografado em trânsito, não compartilhado com terceiros além de Firebase (quando integrado).
  - **Crashlytics (com opt-in):** breadcrumbs sem PII, stack traces. Finalidade: diagnóstico.
  - **Compras:** SKU, token de compra, entitlements. Finalidade: compras, prevenção de fraude. Compartilhado com Google Play Billing.
  - **Anúncios (quando provider instalado):** ID de publicidade (quando disponível), interações com rewarded/interstitial, `rewarded_today`. Finalidade: anúncios. Compartilhado com AdMob.

### Compartilhamento
- Google Play Billing (compras)
- AdMob (anúncios, se integrado)
- Firebase Analytics/Crashlytics/Remote Config (se integrado)

### Segurança
- Dados em trânsito criptografados (HTTPS quando houver backend)
- Save local com XOR+Base64+SHA-256 + 3 backups
- Analytics com escrita atômica via temp file + rename
- Sem credenciais no repo (ver `tools/validate_project.py` hygiene)

### Deleção
- Usuário pode limpar dados do app / desinstalar para remover save local, fila analytics e ledger local.
- Compras não consumíveis permanecem na loja para restauração.
- Solicitação de exclusão de dados vinculados (quando houver backend) via [PREENCHER email].

### Permissões
- `INTERNET` (quando Remote Config/Firebase/AdMob habilitados) — opcional, jogo funciona offline.
- `VIBRATE` (haptics opt-in)
- `POST_NOTIFICATIONS` (notificações locais opt-in)
- Sem `READ_MEDIA_IMAGES`, `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`.

## App Store Privacy Labels (quando iOS)

- **Data Not Linked to You:** Usage Data (com consentimento), Purchases, Diagnostics.
- **Data Not Collected:** Contact Info, Location precisa, etc.
- Privacy manifest deve listar `NSPrivacyAccessedAPICategory` conforme SDKs efetivamente embarcados.

## Evidências no código
- `autoload/Analytics.gd`: `consent_given()` checa `GameState.settings.analytics_consent`, `flush_offline()` atômico, `buffer.clear()` após sucesso, early-return em `track()` sem consent.
- `autoload/GameState.gd`: `purchased_entitlements`, `purchase_ledger`, `ads_policy` persistidos, SAVE v13.
- `autoload/IAPManager.gd`: mock apenas em `OS.is_debug_build()`, entitlements persistidos, ledger com ID único `ticks_usec + random`.
- `core/ads/AdsPolicy.gd`: session tracking, reset diário, `purchased_recently` expira 24h.
- `autoload/AdsManager.gd`: `no_ads` gatia interstitial, `_process` incrementa `session_seconds`.

## Checklist antes de publicar
- [ ] Preencher entidade, email DPO, URL privacidade
- [ ] Confirmar SDKs efetivamente embarcados e versões
- [ ] Preencher Data Safety no Play Console com este mapeamento
- [ ] Testar consent flow: sem consent → sem arquivo `analytics_queue.jsonl`, com consent → fila drena
- [ ] Testar no_ads: compra → interstitial bloqueado após restart
- [ ] Testar ledger: reinstall → restore de no_ads via Billing
