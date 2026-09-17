# Auditoria de Prontidão Completa — 17/09/2026

## Resumo honesto

O repositório agora contém um **jogo offline jogável em formato de early vertical slice**, não um produto mundial pronto para loja. “Completo” na especificação representa anos de conteúdo, integrações com contas externas, validação em aparelhos, operação e métricas reais. Esses itens não podem ser fabricados ou marcados como concluídos sem credenciais, identidade publicadora, arte/áudio licenciados, aparelhos e soft launch. A lista abaixo evita redução silenciosa.

## Implementado e jogável localmente

- [x] Projeto Godot portrait, cena inicial e arquitetura por camadas.
- [x] Banho por gesto, cronômetro, zona Perfect/Good/falhas.
- [x] Tosa higiênica alternada, gesto e VFX de pelos.
- [x] Três identidades iniciais de cliente/pet no ciclo.
- [x] Feedback visual, SFX procedural, haptics e partículas reduzíveis.
- [x] Moedas, combo, review, upgrade e recompensa por qualidade.
- [x] Funcionária Bia desbloqueável e produção idle online.
- [x] Coleção inicial de pets/equipe/conquistas.
- [x] Três missões diárias reclamáveis e login de sete dias.
- [x] Evento semanal local com multiplicador de banho/tosa.
- [x] Mapa de progressão e primeiro estabelecimento desbloqueável.
- [x] Menu de missões, coleção, mapa e acessibilidade/economia.
- [x] Save v3, migração sequencial v0→v3, autosave, integridade e três backups.
- [x] Cofre offline com cap e proteção contra rollback.
- [x] Analytics offline e taxonomia; Remote Config defaults.
- [x] Policies éticas de ads, catálogo/ledger IAP e adapters no-op seguros.
- [x] Catálogos de 10 pets, 6 funcionários, upgrades, eventos, pesquisas, conquistas, missões e cosméticos.
- [x] Simulador econômico e testes de schema, IDs e pacing.

## Faltas para Vertical Slice final

- [ ] Executar/importar no Godot 4.3+ e eliminar erros/warnings reais de parser.
- [ ] Cinco playtests observados e duas rodadas de tuning do gesto.
- [ ] Fila visual com 5–8 clientes, paciência e drag pet→estação.
- [ ] Groomer Bia animada na cena e seleção de funcionário.
- [ ] Tosa artística com trace real e before/after.
- [ ] Upgrade com transformação visual em marcos.
- [ ] Home-mundo e navegação completa com safe-area/back stack.
- [ ] Fontes Baloo/Nunito/Fredoka com licenças OFL empacotadas.
- [ ] Arte final em atlas, animações finais e VFX pooled.
- [ ] BGM e SFX final masterizados/licenciados.
- [ ] Tutorial por spotlight/gesto fantasma e modo motor assistido.
- [ ] Profile físico de frame, memória, draw calls, temperatura e loading.
- [ ] Captura MP4 9:16 em aparelho ou decisão formal de fallback.

## Faltas para MVP comercial

- [ ] Segundo estabelecimento completo e 50–80 turnos balanceados.
- [ ] Oito arquétipos de clientes com comportamento.
- [ ] 20+ upgrades funcionais/visuais, não somente catalogados.
- [ ] 30+ conquistas completas e idempotentes.
- [ ] Semanais, cofre com tela, evento semanal completo e prestígio.
- [ ] Decoração aplicada ao cenário, inventário e satisfação detalhada.
- [ ] Configurações completas: volumes separados, fonte, daltonismo, vibração.
- [ ] Localização aplicada à UI; QA pt-BR e fallback.
- [ ] Notificação Android real, opt-in e quiet hours.
- [ ] AdMob plugin compatível, IDs de teste e callbacks em aparelho.
- [ ] Google Play Billing, SKUs de test track, restore/pending/acknowledge.
- [ ] Backend de validação de compras consumíveis.
- [ ] Firebase Analytics/Crashlytics/Remote Config reais e consent flow.
- [ ] Política de privacidade juridicamente revisada e publicada.
- [ ] Data Safety/SDK inventory e classificação etária preenchidos.
- [ ] Cloud save/conflito ou decisão explícita de adiar.
- [ ] Testes Godot de save/service/progressão e smoke matrix Android.

## Faltas para proposta de longo prazo/1.0 plena

- [ ] Dez estabelecimentos, oito cidades e respectivas artes/músicas.
- [ ] 120 pets com animações exigidas e 60 NPCs com rigs/VO.
- [ ] Todos os dez serviços, incluindo diagnóstico e cirurgia.
- [ ] 40 pesquisas, 80 conquistas e 200 itens funcionais.
- [ ] Prestígio, franquias, rede, instituto e endgame.
- [ ] Passe de 30 níveis/28 dias e pipeline de temporadas.
- [ ] Eventos sazonais completos e calendário/kill switches.
- [ ] Oito cinematics clipáveis e compartilhamento validado.
- [ ] Ranking por cohorts com backend, autenticação e antifraude.
- [ ] Cinco BGMs finais, VO variations e soundscape por cidade.
- [ ] Assets Play Store: ícones A/B, feature graphic, 8 screenshots e vídeos.
- [ ] Package definitivo, keystore externa e AAB assinado.
- [ ] Internal/closed tests com 20+ testadores e relatório de aparelhos.
- [ ] Soft launch com amostra suficiente para D1/D7/D30 e crash-free.
- [ ] App Store signing, StoreKit, privacy manifest e revisão iOS.
- [ ] Operação: suporte, incidentes, rollback, dashboard, UA/ASO e calendário.

## Bloqueadores externos obrigatórios

1. Nome legal/publisher, package definitivo e contato de privacidade.
2. Play Console, Firebase e AdMob configurados pelo publisher.
3. SKUs/preços criados na test track e backend para receipt validation.
4. Keystore/upload key fora do Git.
5. Aparelhos reais Android API 24/current em níveis low/mid/high.
6. Orçamento/aprovação humana para produção de arte, áudio e revisão jurídica.
7. Usuários reais para validar diversão e KPIs; métricas não são testáveis por código.

## Critério de release

Não publicar enquanto qualquer item de segurança, billing, consentimento, assinatura, crash/ANR ou device QA estiver aberto. Não escalar os 120 pets antes do gate do Vertical Slice: isso evita produzir anos de conteúdo para um loop não validado e respeita a ordem original da especificação.
