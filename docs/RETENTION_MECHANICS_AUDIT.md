# RETENTION_MECHANICS_AUDIT — mecânicas e gatilhos de retenção

Auditoria dedicada (código aberto, linha a linha) dos gatilhos de retenção do jogo,
lida pelo modelo do Hook (gatilho → ação → recompensa variável → investimento) e por
horizonte (D1/D7/D30). Complementa `docs/EXPERIENCE_ROADMAP.md` (visão de experiência)
e `docs/ROADMAP.md` (gates). Todas as afirmações citam arquivo/linha.

## 1. Inventário do que EXISTE (verificado)

### Recompensa variável dentro da sessão (o “fun” de agora)
- Qualidade Perfect/Good/Fail paga 1.5/1.15/0 (`data/economy_curves.json` → `quality`).
- Gorjeta com rolagem aleatória + bônus de reputação
  (`Main.gd:312` `Economy.tip_multiplier(randf())`); cliente VIP com chance que sobe
  por tier do bairro até 35% (`Economy.vip_chance`, `Main.gd:475`).
- **Combo**: +1 por perfect, zera em qualquer Good/Fail (`GameState.gd:632`);
  +2,5% por stack com teto ×20 (`economy_curves.combo`); pill no HUD
  (`Main.gd:757`) e tela “RITMO PERFEITO ×N” (`Main.gd:376-378`); `best_combo` salvo.
- **Eventos 7/7 com efeito real**: dia temático 2×, sábado perfect +50%, domingo
  +25% (`LiveOps.multiplier_for/bonus_for_quality`), aplicados na renda
  (`Main.gd:330-331`), visíveis no painel (`MetaPanel.gd:468`), com kill switch e
  dosador remoto (`RemoteConfig.events_enabled/event_boost_scale`).

### D1 — o “volta amanhã”
- **Streak de 7 dias**: 25×dia moedas; dia 7 = pet `mel_golden`; freezes nos dias
  3/5/7; freeze protege gap ≤ 60h (`GameState.gd:480-495`); anti-cheat de relógio
  emite `churn_risk_signal` (`GameState.gd:476`, `TimeManager.gd:11`).
- **Cofre offline**: taxa 0.5, cap 2h → 24h via upgrade `offline_cap`
  (`economy_curves.defaults`); toast de coleta ao voltar (`Main.gd:709-716`).
- **Bônus de retorno** (ausência ≥ 48h): 200 + 25×min(nível,20) moedas + 1 freeze
  (`GameState.check_return_bonus`, toast em `SessionFeedback.show_comeback`).
- **Missões**: 6 diárias + 7 semanais com pesos e `min_tier`
  (`data/daily_missions.json`, `data/weekly_missions.json`), claim no painel.
- **Tutorial** de 3 passos com skip (`TutorialOverlay.gd`, `Main.gd:575+`),
  trackeado (`tutorial_complete/skipped`).

### D7–D30 — hábito e metas longas
- **Passe de 28 dias**: 1 dia destrava por dia ativo (`GameState.gd:579-584`),
  recompensas em `data/pass.json` (brasas no dia 7), claim no painel
  (`MetaPanel.gd:157-163`).
- **Carreira**: 61,85h ativas até o nível 120, établissements por tier com
  engagement gates (`data/career_track.json`).
- **Coleção/investimento**: 50 pets, cosméticos por brasas, **buddy** (pet
  favorito entra na fila com 40% de prioridade, `Main.gd:463-466`), **afeto** 0–50
  multiplica renda do pet em até +25% (`Main.gd:308-332`), staff com passivos
  (`GameState.staff_bonus`), **prestígio** no nível 15 gera `franchise_tokens`
  (`GameState.gd:240-257`).
- **Monetização honesta**: rewarded ads por brasas com cap diário 8 e cooldown 180s
  (`MetaPanel.gd:435`, `RemoteConfig`), fachada avisa indisponível sem adapter.
- **Analytics** ~35 eventos cobrindo o funil inteiro (`first_open`, `service_start`,
  `combo_reached`, `pass_claim`, `streak_freeze_used`, `churn_risk_signal`…).

## 2. Gaps VERIFICADOS no código (o que promete mas não entrega)

1. **Opt-in de push morto.** `NotificationManager.permission_granted` nasce `false`
   e nenhum settings/UI jamais o seta `true` (grep em `MetaPanel.gd`/`GameState.gd`
   não acha writer). Os dois lembretes prontos — “cofre cheio” (2h) e “sentiu sua
   falta” (8h), com deep link `--section=` funcional — **nunca são agendados**.
   É o gatilho externo mais barato do jogo parado na prateleira.
2. **`franchise_tokens` sem sink.** Só entra no prestige (`GameState.gd:244`);
   nada no código os consome. Promessa de endgame com moeda órfã.
3. **Só 10 conquistas** para uma carreira de ~60h — a curva de “só mais uma”
   acaba cedo demais. Ironia boa: as métricas semanais (`services, perfect,
   combo_max, tips, style, vip, spend` — `GameState.gd:47/366/533`) já contam tudo
   que uma leva nova de conquistas precisaria.
4. **Investimento invisível na cena.** Afeto aparece só num toast
   (`Main.gd:234`); buddy não tem marcador na fila/coleção; o jogador não *vê* o
   que construiu emocionalmente — e investimento invisível não segura D7.
5. **Fim de sessão sem gancho.** Nada mostra o “amanhã” (evento temático do dia
   seguinte, streak N/7) ao fechar; o evento só é visto se o jogador abrir o painel.
6. **Combo tudo-ou-nada.** Um único Good zera a pilha (`GameState.gd:632`). Para
   público casual isso pune o flow; o teto de ×20 já protege a economia para
   permitir uma folga.

## 3. Melhorias priorizadas por horizonte

### D1 (esta semana — infraestrutura já existe)
- **Toggle de notificações no settings** que seta `permission_granted` e chama
  `schedule_return_reminders` — 20 linhas fechando o gap 1.
- **Cartão “até amanhã”** ao fechar/ocioso: evento de amanhã
  (`LiveOps` dia+1) + streak atual — transforma gatilho interno em compromisso visível.
- **Corações de afeto na cena** (3 marcos: 10/25/50) — investimento visível.

### D7
- **Conquistas 10 → 30** usando as métricas já trackeadas (combo_max 10/20/50,
  tips 50/200, vip 5/20, spend, style) com rewards escalonados em brasas.
- **Folga do combo**: 1 Good não zera (fail zera); preserva o teto ×20.
- **Badge de buddy** na fila + saudação nominal (sinergia com afeto).

### D30
- **Sink de franchise_tokens**: cosméticos exclusivos de prestígio e/ou vitrine de
  “franquia” com multiplicador passivo pequeno — fecha a promessa do prestige.
- **Baú de fim de semana**: completar as 7 semanais = baú com cosmético rotativo.
- **Polaroids/álbum** (investimento + share orgânico; detalhe no EXPERIENCE_ROADMAP).

## 4. Executado nesta fase (commit de retenção)

- **Gap 1 fechado:** toggle “Lembretes de retorno” em Ajustes arma o
  `NotificationManager` (persiste em `settings["notifications"]`, sincroniza no boot
  do Main antes de `schedule_return_reminders`).
- **Gap 2 fechado:** sink de prestígio na Loja — 1 `franchise_token` → 5 brasas
  (`GameState.convert_franchise_token`).
- **Gap 3 fechado:** conquistas 10 → 30 (`data/achievements.json` +
  `_check_achievements`), cobrindo combo 50, serviços 100/500/1000, coleção
  15/30/50, staff, estação 25/50, prestígio, offline 8h, streak 7 (novo
  `best_streak` persistido), nível 25, afeto 50 (`friend_50`).
- **Gap 4 fechado:** 3 corações de afeto (10/25/50) desenhados na cena sobre o pet
  (`PetShopCanvas._draw_affection_hearts`), atualizados no carinho e na seleção;
  buddy marcado na fila com tag localizada.
- **Gap 5 fechado:** pill do evento do dia visível na cena (nav) + linha “Amanhã”
  no painel de missões (`LiveOps.event_name_for`).
- **Gap 6 fechado:** folga de combo — o primeiro Good de uma sequência não zera
  (fail zera); `combo_grace_used` por sessão, de propósito não persistido.
- **Baú semanal:** claimar as 7 semanais paga bônus único por semana
  (`GameState.check_weekly_chest`).
- Saudação nominal do buddy no boot da sessão.

Restam (próxima fase, deliberadamente): polaroids/álbum completo e cosméticos
exclusivos de prestígio além do conversor.

## 5. O que NÃO mexer (está certo e protege o jogador)

- Sem energia/stamina: sessões ilimitadas são a identidade do jogo.
- Eventos com kill switch + `boost_scale` remoto: dosagem sem hotfix.
- Rewarded com cap diário/cooldown e aviso honesto sem adapter.
- Streak com freeze e janela de 60h: pune abandono longo, perdoa a vida real.
- Prestígio preserva pets/cosméticos/conquistas (`GameState.gd:239`): reset nunca
  apaga investimento emocional.
