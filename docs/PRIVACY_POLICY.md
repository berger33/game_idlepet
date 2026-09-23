# Política de Privacidade — PetShop Tycoon

**Data efetiva:** 2026-09-21  
**Controlador:** [PREENCHER: Razão social / Nome fantasia, CNPJ, endereço]  
**Contato privacidade:** [PREENCHER: email DPO, ex: privacidade@empresa.com]  
**URL pública:** [PREENCHER: https://empresa.com/privacy]

> Este documento é a versão final baseada no rascunho `PRIVACY_POLICY_DRAFT.md`. Antes de publicar na Play Store, preencher os campos [PREENCHER] e obter revisão jurídica. Não é aconselhamento jurídico.

## Resumo
PetShop Tycoon funciona offline por padrão. Não coletamos nome, e-mail, contatos, fotos, microfone ou localização precisa. Quando o usuário opta por analytics, anúncios ou compras, processamos apenas identificadores técnicos e eventos de uso para operar o jogo, restaurar compras, prevenir fraude e medir recursos.

## Dados que podemos processar
- **Identificadores técnicos:** ID de instalação, ID de dispositivo (quando fornecido pelo SO/loja), versão do app, idioma, país/região.
- **Uso do app:** eventos como `service_completed`, `level_up`, `offline_reward`, duração de sessão, erros de crash (sem PII).
- **Compras:** SKU, estado da transação, token de compra (validado no backend quando houver), entitlements (`no_ads`, `bath_pass`).
- **Anúncios:** interações com rewarded/interstitial, `rewarded_today`, cooldown, apenas se provider instalado.
- **Mídia local:** clipes MP4 de share são salvos no aparelho pelo usuário; não enviamos sem ação explícita de compartilhar.

**Não coletamos:** nome, e-mail, telefone, endereço, contatos, fotos (exceto arquivo de share criado localmente), microfone, localização precisa.

## Finalidades e bases legais (LGPD/GDPR)
- Operar o jogo e salvar progresso local: execução de contrato / legítimo interesse.
- Restaurar compras e prevenir fraude: execução de contrato / legítimo interesse.
- Analytics e Crashlytics (apenas com consentimento em Ajustes): consentimento.
- Anúncios (apenas com provider e quando permitido): consentimento / legítimo interesse conforme lei local e TCF se aplicável.
- Notificações locais: consentimento (opt-in).

## Consentimento
Em Ajustes há toggles para `analytics_consent`, `haptics`, `notifications`. Sem opt-in de analytics, nada é persistido em `user://analytics_queue.jsonl` nem enviado; o buffer em memória é descartado (`autoload/Analytics.gd: consent_given()`). O usuário pode revogar a qualquer momento; o arquivo de fila é removido e buffer limpo.

## Compartilhamento e subprocessadores
- **Google Play Billing:** processamento de compras, conforme termos do Google.
- **Google AdMob (quando integrado):** exibição de rewarded/interstitial, IDs de teste em debug, IDs reais via recurso local não versionado.
- **Firebase (quando integrado):** Analytics adapter drena fila após consentimento, Crashlytics registra breadcrumbs sem PII, Remote Config valida allowlist/tipo/faixa.
- Lista completa, finalidades, retenção e links de DPA devem ser atualizados com as versões efetivamente embarcadas antes do release.

Nenhum SDK binário ou `google-services.json` é versionado neste repositório (ver `docs/SDK_INTEGRATIONS.md`).

## Retenção
- Save local `user://save.dat` + 3 backups: até o usuário limpar dados/desinstalar.
- Fila analytics `user://analytics_queue.jsonl`: até envio bem-sucedido ou revogação de consentimento; escrita atômica via temp file.
- Ledger de compras `GameState.purchase_ledger`: até desinstalação; compras não consumíveis são restauráveis via Play Billing.
- Logs de crash: conforme política do Firebase Crashlytics (quando habilitado).

## Direitos do titular (LGPD/GDPR)
Acesso, correção, exclusão de dados vinculados quando houver backend, oposição, portabilidade e revogação de consentimento. Canal: [PREENCHER email] com SLA [PREENCHER: 15 dias]. Dados locais podem ser removidos ao limpar dados do app/desinstalar, exceto compras mantidas pela loja.

## Idade e crianças
Classificação etária [PREENCHER: ex: Livre / 10+]. Não direcionado a menores de 13 anos sem consentimento verificável dos pais quando exigido. Anúncios personalizados desabilitados para público infantil quando aplicável.

## Transferências internacionais
[PREENCHER: países, mecanismos de transferência, SCCs se houver]

## Segurança
Save com XOR+Base64+SHA-256, backups, validação de hash, migração versionada (`autoload/SaveManager.gd`). Analytics com escrita atômica. Sem credenciais no repo.

## Data Safety (Play) e Privacy Labels (App Store)
Ver `docs/DATA_SAFETY.md` para mapeamento de coleta, criptografia, deleção e permissões.

## Alterações
Notificaremos via notas de atualização e atualização da data efetiva.

## Contato
[PREENCHER: entidade, endereço, email DPO]
