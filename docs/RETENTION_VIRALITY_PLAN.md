# RETENTION_VIRALITY_PLAN — validação de jogabilidade/viralização e plano de execução

Auditoria de 2026-09-21 (código + simulação com os parâmetros reais de
`RemoteConfig`/`GameState`). Este arquivo é o **plano de trabalho versionado**: cada
item marca estado (`[ ]` pendente, `[x]` feito, `[~]` parcial) e o arquivo/linha de
referência, para que a implementação sobreviva a qualquer interrupção de sessão.

## 0. Veredito

- Sessão minuto a minuto: acima da média do gênero (5 gestos com identidade,
  temperamento/espécie, combo com folga, pico, VIP, upsell, maestria, carinho, buddy,
  50 pets com 10 reações). Segura D0/D1.
- Retenção D7+ e "base": ainda não. Quatro problemas estruturais medidos:

| Sintoma | Evidência |
|---|---|
| Camada de recompensas morre em ~1h | Diária 75, semanal 400–600, passe 21.400/28d, level-up `20+5×nível`, streak d7 175, conquistas 25–500 — vs. 1 atendimento ≈ **840 aos 30 min, 2.000 em 1h, 12.000 em 5h, 38.000 em 20h** (sim. compra gulosa). |
| Progresso sem retorno visual | Estação (120 níveis) muda só `"ESTAÇÃO Nv.%d"` (`PetShopCanvas.gd:457`); 10 capítulos mudam só o nome da placa (`:433`); fundos = 5 por serviço, 0 por tier. |
| "Idle" inexistente | Cofre = `0.015 × mult × 0.5` → ~1.050 moedas no cap de 2h quando 1 atendimento paga 2.045 (0,1%). Bia ≈ 1% da renda ativa. |
| Nada sai do aparelho | Share = PNG em `user://shares/` (privado no Android), tela inteira com HUD, sem marca (`ShareManager.gd:40`); notificações em memória (`NotificationManager.gd:24`); ads/IAP fachada; analytics JSONL local. |

## 1. Economia e progressão

- [ ] **Recompensas escaladas à renda**: `Economy.scaled_reward(seconds)` (segundos de
  renda atual, com piso) aplicado a missões diárias/semanais, passe, streak,
  conquistas, level-up e baú semanal.
- [ ] **Sinks que acompanham a curva**: cosméticos (moedas) e staff precificados por
  múltiplo da renda atual / tier.
- [ ] **Bug tokens de prestígio em dobro**: `prestige_tokens_available = tokens(total) −
  prestige_level` mas `perform_prestige` faz `prestige_level += 1` com `gain = 3`
  (`GameState.gd:253-266`). Guardar `prestige_tokens_collected`.
- [ ] **Prestígio racional**: herança de estação (% do nível anterior) + preview
  "você volta a este ponto em X min".
- [ ] Cadência de upgrades: marcos visuais (ver §3).

## 2. Idle / retorno

- [ ] **Cofre offline relevante**: base = 50% da renda ativa recente
  (`recent_income_rate` persistido), cap 2h→8h por progressão, dobrar via
  rewarded/brasa.
- [ ] **Automação como progressão**: Bia atende sozinha a cada N s (gerente por sala,
  upgrades de velocidade).
- [ ] **Cartão "Enquanto você estava fora"** (moedas, pets que visitaram, streak,
  evento de hoje) no lugar do toast.

## 3. Feedback, momentos e juice

- [ ] **Telas de revelação** (2–3 s) para novo pet, novo capítulo, level-up com
  desbloqueio, conquista, presente sazonal — hoje tudo é toast.
- [ ] **Transformação visual por marco**: paleta/mobília por tier de estabelecimento;
  estação evoluindo a cada 10 níveis.
- [ ] **Música real**: BGM é loop procedural de 8 s (`AudioManager._ambient_loop`);
  `audio/bgm` vazio. Faixas por fase/tier.
- [ ] **Meta visível no HUD**: "próximo: Nina (Nv.20) • Sala de Secagem (Nv.5)".
- [ ] Buddy 40% → 25% subindo com afeto.

## 4. Onboarding e primeira sessão

- [ ] Mini-tutorial fantasma de 1 tentativa para cada gesto novo (níveis 3/5/7/10).
- [ ] Localizar as ~30 strings pt cravadas (`Main.gd`, `GameState.gd`,
  `TutorialFlow.gd`, `MetaPanel.gd`).
- [ ] Nomear o pet shop / o buddy.

## 5. Retenção D1–D30

- [ ] **Diárias do catálogo** (`daily_missions.json`: 3 sorteadas + épica, metas
  escaladas ao nível) — hoje 3 fixas triviais.
- [ ] **Descoberta de pets pela fila**: visitante misterioso antes do destravar.
- [ ] Teto cosmético (11 itens) → 30+, rotativo semanal.
- [ ] Cliente que vai embora não soma reputação (`_client_left` → `register_review(3)`).

## 6. Social e viralização

- [ ] **Share 9:16 com marca**: só o pet (antes/depois), nome/raça/estrelas, logo,
  legenda; salvar na galeria/share sheet (`OS.share`/plugin) em vez de `user://`.
- [ ] **Build Web publicável** (preset existe) como canal viral.
- [ ] Ranking assíncrono / visita a amigos / código de convite (ROADMAP 1.3).
- [ ] Card compartilhável de conquista.

## 7. Monetização

- [ ] Rewarded real: dobrar cofre, +1 brasa, estender pico (`AdsPolicy` já limita).
- [ ] IAP: sem anúncios, pacote iniciante, passe premium (trilha premium em
  `pass.json`).

## 8. LiveOps e cadência

- [ ] Carnaval/Natal com cosmético (hoje `cosmetic: ""`) e pets sazonais com arte.
- [ ] Meta do dia no evento semanal ("30 banhos na Segunda → baú").
- [ ] `events.json`/preços via `RemoteConfig`.

## 9. UX, acessibilidade, localização

- [ ] Tamanho de fonte, modo daltônico (janela do gesto), mão esquerda, motor assistido.
- [ ] Nomes de pets/staff/conquistas/cosméticos/pesquisa localizados.
- [ ] Safe-area/notch e back button Android.

## 10. Técnico e plataforma

- [ ] Preset Android ativo, ícone/splash, keystore de debug documentada.
- [ ] Cloud save ou export/import de save.
- [ ] Adapter de analytics + consentimento + funil mínimo.
- [ ] Testes Godot de fluxo (atendimento completo, prestígio, migração real).

## Ordem de execução (impacto ÷ esforço)

1. §1 recompensas/sinks escalados + §2 cofre relevante + bug dos tokens.
2. §3 telas de revelação + meta no HUD.
3. §6 share 9:16 com marca + build Web.
4. §5 diárias do catálogo + descoberta de pets pela fila.
5. §3 tier visual + música.
6. Restante por seção.

## Registro de execução

(preenchido a cada etapa concluída, com commit)
