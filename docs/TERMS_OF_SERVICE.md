# Termos de Serviço — PetShop Tycoon

**Data efetiva:** 2026-09-21  
**Empresa:** [PREENCHER]

## 1. Aceitação
Ao instalar ou jogar PetShop Tycoon, você concorda com estes Termos e com a Política de Privacidade.

## 2. Licença de uso
Licença não exclusiva, intransferível, revogável para uso pessoal e não comercial. Você não pode copiar, modificar, distribuir, fazer engenharia reversa ou usar o jogo para fins comerciais sem autorização.

## 3. Conteúdo e propriedade intelectual
Todo conteúdo (arte, áudio, código, marcas) pertence à empresa ou licenciadores. Pets, nomes e histórias são fictícios.

## 4. Moeda virtual e compras
- Moedas (`coins`) e Brasas (`embers`) são moedas virtuais sem valor real, não transferíveis, não reembolsáveis exceto quando exigido por lei ou pela loja.
- Compras via Google Play Billing: SKUs `starter_pack`, `no_ads`, `brasa_small/medium/large`, `bath_pass`, `cosmetic_pack`. Preços localizados, impostos conforme loja.
- `no_ads` é entitlement não consumível e restaurável. Consumíveis exigem validação de recibo no backend antes de grant comercial em produção (ver `docs/SDK_INTEGRATIONS.md`).
- Mock de IAP só existe em builds debug (`OS.is_debug_build()`). Em release, `provider_ready==false` retorna loja indisponível, sem grant.

## 5. Anúncios
Rewarded é opt-in e concede recompensa uma vez após callback verificado com UUID persistido. Interstitial respeita política local: primeiras 3 sessões bloqueadas, mínimo 20 min, cooldown ≥3 min, cap ≤8 rewarded/dia (`core/ads/AdsPolicy.gd`). `no_ads` bloqueia interstitial.

## 6. Conduta do usuário
Proibido: trapaça, exploração de bugs, automação, modificação de saves (hash SHA-256 valida integridade), conteúdo ofensivo em nome da loja.

## 7. Save e transferência
Save local atômico com backups. Transferência entre aparelhos via código Base64 assinado (`export_code`/`import_code` em `SaveManager.gd`). Sem cloud save oficial nesta versão.

## 8. Atualizações e disponibilidade
Podemos atualizar, suspender ou encerrar o jogo a qualquer momento. Recursos online (Remote Config, eventos semanais) podem mudar sem aviso, mas respeitando faixas validadas.

## 9. Isenção e limitação
Jogo fornecido "como está", sem garantias. Em nenhuma hipótese seremos responsáveis por danos indiretos, perda de progresso por falha de dispositivo, ou interrupções de serviços de terceiros (Google Play, AdMob, Firebase).

## 10. Reembolso
Reembolsos seguem política da Google Play. Para problemas, contate [PREENCHER email] e/ou suporte da loja.

## 11. Lei aplicável e foro
[PREENCHER: legislação, ex: Brasil, foro da comarca de ...]

## 12. Contato
[PREENCHER: email, endereço]
