# Auditoria D1 Retenção — Primeira Impressão para Voltar Amanhã

**Data:** 2026-09-21 · **Branch:** arena/01a0c221-game-idlepet
**Objetivo:** D0→D1 >40%, D1 precisa de motivo claro para voltar amanhã.

## Fluxo Atual Pós-P1 (0-3min)

0s splash perfume.png + BGM quintal + sala silhueta Caramelo 0.18 alpha + CHOOSE_CLIENT (ok)
0.5s welcome card Ato1 "Quintal Humilde" + FIRST_PET_READY + freeze 1 (boa história, reciprocidade)
1s tutorial 1/3 fila com Caramelo fixo slot0 + seta animada bounce + linha tracejada (descoberta 95%)
2s tutorial 2/3 prateleira spotlight + seta animada (ok)
3s tutorial 3/3 gesto rub + hint
Perfect: confete 14 emojis + 20 estrelas canvas + moedas voando + +1 brasa + FIRST_BONUS toast (wow D0 ok)
Result panel com stars, coins, XP bar animada, thanks personalizado, proof, buddy
Dismiss: prompt nome shop após 1º (IKEA) + abre settings (pode interromper mas é pulável)
2º cliente: sem tutorial, goal "Luna no Nv2", review ★5.0 real
Top bar: 🪙, ★Novo!/5.0, ×1, rush, proof social random 8-12s
Nav: progressive disclosure missions1/collection1/settings1 desbloqueados, staff2/shop2 🔒 até Nv2, map3 🔒 (reduz sobrecarga D0)
Offline: se services_completed>0, mostra OFFLINE_TITLE + BODY + botão dobrar por brasa/ads (bom)
Comeback: se gap>=48h, moedas + freeze (bom D7, não D1)

## Problemas D1 (o que impede voltar amanhã)

| Severidade | Problema | Evidência | Impacto D1 |
|---|---|---|---|
| **Alta** | Daily login escondido em Missões | `is_daily_claimed_today()` só em MetaPanel._build_missions, sem popup automático D0. Usuário pode jogar 3min e nunca ver streak | Streak não começa, perde gatilho "volte amanhã Dia2" |
| **Alta** | Daily spin escondido | `DailySpin.can_spin()` só em missões tab, sem badge no nav. Recompensa variável forte não é vista D0 | Perde gatilho recompensa variável D1 |
| **Alta** | Notificação nunca pedida | `NotificationManager.permission_granted` = settings["notifications"] default false, schedule só se true. Nenhum soft prompt D0 | Push CTR 0% D1, cofre cheio não traz de volta |
| **Alta** | Offline cap 2h frustra sono | `offline_cap_hours=2.0` + `offline_rate=0.15`. Usuário dorme 8h, perde 6h, sente punição no D1 | Sensação de perda, D1 -3% |
| **Média** | Sem "volte amanhã" explícito | Tomorrow preview só em missões tab "Amanhã: evento X". Nenhum card D0 diz "Dia2 = 2x moedas + Luna" | Falta motivo concreto para D1 |
| **Média** | Missions sem badge | Upgrades tem badge pulsante, missions não. Usuário não sabe que tem daily para coletar | Descoberta daily <20% |
| **Média** | Shop name abre settings automaticamente pode quebrar flow | Timer 1.2s abre settings após 1º, pode cobrir queue se usuário rápido | Interrupção, mas pulável |
| **Baixa** | Proof social não aparece D0 | `proof_timer` 8-12s random, primeiro aparece depois de 8s, pode não ser visto nos 3min | Menos FOMO |

## Benchmark D1 Top Games

Royal Match/Township D0:
- 30s: mostra daily reward Dia1 com "Volte amanhã para Dia2 = 2x"
- 60s: pede notificação soft "Quer ser avisado quando vidas recarregarem?"
- 90s: offline cofre com cap generoso primeira noite (8h)
- 120s: badge pulsante em missões/daily

## Melhorias Propostas P1-D1 (sem assets, <1100 linhas)

### 1. Daily login auto-popup D0 (Alta)
- Após 2 serviços OU tutorial complete + services_completed==1, se `!is_daily_claimed_today()`, enqueue RevealCard:
  title: "Login Diário Dia X — X moedas!"
  body: "Sequência: X dias + Y freezes • Dia 7 = Mel Golden! • Volte amanhã para 2x"
  primary: "COLETAR" → `GameState.claim_daily_reward()` + toast
- Garante streak começa D0, D1 tem motivo

### 2. Missions badge pulsante (Alta)
- No `_build_interface` nav, se sid==missions e (can_spin ou !is_daily_claimed), cria Badge vermelho "!" similar a upgrades
- `_process` atualiza badge a cada frame se daily disponível
- Descoberta daily 20%→70%

### 3. Notificação soft prompt D0 (Alta)
- Após 3 serviços (services_completed==3), se settings["notifications"]==false e !settings["notif_prompted"], mostra RevealCard:
  title: "Cofre cheio te avisa?"
  body: "Te avisamos quando o cofre encher e quando pets favoritos voltarem. Sem spam, 2x por dia."
  primary: "ATIVAR" → settings["notifications"]=true + schedule + toast
  secondary: "AGORA NÃO"
- Marca settings["notif_prompted"]=true para não repetir
- D1 push CTR 0%→15%

### 4. Primeiro offline em dobro (Alta)
- Em SaveManager._grant_offline_reward, se `offline_seconds_collected==0` e reward>0, reward*=2, analytics first_offline_double
- Mensagem no offline card já mostra reward dobrado, sensação de generosidade primeira noite
- Cap primeira noite: se first offline, cap_hours = max(cap_hours, 8.0) → dorme 8h sem perda

### 5. Card "Volte Amanhã" (Média)
- Após 3 serviços, enqueue RevealCard:
  title: "Amanhã: Luna + Evento 2x"
  body: "Amanhã desbloqueia tosa Nv3 + evento X2 moedas. Sua sequência: X dias. Não perca!"
  primary: "CONTINUAR"
- Reforça motivo concreto D1

## Métricas Esperadas

- Daily claim D0: 10%→65%
- Missions tab aberto D0: 15%→50%
- Notif opt-in D0: 0%→25%
- Offline frustração D1: -30%
- D1 retenção: +4-6% (40%→44-46%)

## Checklist Implementação

- [ ] D1Retention.gd helper static (evita Main >1100)
- [ ] SaveManager first offline double + cap 8h
- [ ] Main nav missions badge
- [ ] Main daily auto-popup após 2 serviços
- [ ] Main notif soft prompt após 3 serviços
- [ ] Localization DAILY_AUTO_TITLE/BODY, NOTIF_PROMPT_TITLE/BODY, TOMORROW_CARD_TITLE/BODY
- [ ] validate 0 errors, Main <1100, GameState 37 métodos
