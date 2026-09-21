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

- [x] **Recompensas escaladas à renda** (`core/progression/Rewards.gd`): `Economy.scaled_reward(seconds)` (segundos de
  renda atual, com piso) aplicado a missões diárias/semanais, passe, streak,
  conquistas, level-up e baú semanal.
- [x] **Sinks que acompanham a curva** (`Rewards.cosmetic_price/hire_price`): cosméticos (moedas) e staff precificados por
  múltiplo da renda atual / tier.
- [x] **Bug tokens de prestígio em dobro** (`prestige_tokens_collected`, save v11): `prestige_tokens_available = tokens(total) −
  prestige_level` mas `perform_prestige` faz `prestige_level += 1` com `gain = 3`
  (`GameState.gd:253-266`). Guardar `prestige_tokens_collected`.
- [x] **Prestígio racional** (25% estação/ferramentas, nível 10, caixa escalada, preview): herança de estação (% do nível anterior) + preview
  "você volta a este ponto em X min".
- [~] Cadência de upgrades: mural por capítulo (§3); estação por marco ainda só via ferramentas.

## 2. Idle / retorno

- [x] **Cofre offline relevante** (renda ativa × 15% + equipe; `offline_rate`): base = 50% da renda ativa recente
  (`recent_income_rate` persistido), cap 2h→8h por progressão, dobrar via
  rewarded/brasa.
- [x] **Automação como progressão** (`staff.json` `automation`, renda passiva + cofre): Bia atende sozinha a cada N s (gerente por sala,
  upgrades de velocidade).
- [x] **Cartão "Enquanto você estava fora"** (`SessionFeedback.show_offline_card` + dobro por brasa/vídeo) (moedas, pets que visitaram, streak,
  evento de hoje) no lugar do toast.

## 3. Feedback, momentos e juice

- [x] **Telas de revelação** (`EventBus.reveal_requested` → `RevealCard`) (2–3 s) para novo pet, novo capítulo, level-up com
  desbloqueio, conquista, presente sazonal — hoje tudo é toast.
- [~] **Transformação visual por marco**: mural + luz por tier (`ChapterArt.gd`); estação evoluindo a cada 10 níveis fica para a arte: paleta/mobília por tier de estabelecimento;
  estação evoluindo a cada 10 níveis.
- [x] **Música real** (`tools/gen_bgm.py`: 3 trilhas por fase, 96 BPM, crossfade): BGM é loop procedural de 8 s (`AudioManager._ambient_loop`);
  `audio/bgm` vazio. Faixas por fase/tier.
- [x] **Meta visível no HUD** (`Goals.hud_line`): "próximo: Nina (Nv.20) • Sala de Secagem (Nv.5)".
- [x] Buddy 40% → 25% subindo com afeto.

## 4. Onboarding e primeira sessão

- [x] Mini-tutorial por gesto novo (`TutorialFlow.teach_service`, spotlight + dica, 1× por serviço).
- [x] Localizar as ~30 strings pt cravadas (`Main.gd`, `GameState.gd`,
  `TutorialFlow.gd`, `MetaPanel.gd`).
- [ ] Nomear o pet shop / o buddy (pendente: precisa de campo de texto no painel).

## 5. Retenção D1–D30

- [x] **Diárias do catálogo** (`Missions.gd`, sorteio por data, metas escaladas, épica) (`daily_missions.json`: 3 sorteadas + épica, metas
  escaladas ao nível) — hoje 3 fixas triviais.
- [x] **Descoberta de pets pela fila** (`Discovery.gd`, visitante 3×, save v12): visitante misterioso antes do destravar.
- [~] Teto cosmético 11 → 23 (banheiras por dado + 4 paredes procedurais); acessórios novos e rotativo semanal dependem de arte.
- [x] Cliente que vai embora não soma reputação (`_client_left` → `register_review(3)`).

## 6. Social e viralização

- [x] **Share 9:16 com marca** (`ShareManager`: SubViewport, galeria/`navigator.share`, legenda no clipboard): só o pet (antes/depois), nome/raça/estrelas, logo,
  legenda; salvar na galeria/share sheet (`OS.share`/plugin) em vez de `user://`.
- [x] **Build Web publicável** (preset sem threads + `.github/workflows/web-pages.yml`) (preset existe) como canal viral.
- [ ] Ranking assíncrono / visita a amigos / código de convite — exige backend (bloqueador externo).
- [ ] Card compartilhável de conquista (reusar `ShareManager._render_card`; pendente).

## 7. Monetização

- [~] Rewarded: placements prontos (dobrar cofre, +1 brasa) sobre o `AdsManager`; o SDK AdMob é bloqueador externo.
- [ ] IAP: sem anúncios, pacote iniciante, passe premium — exige Play Billing (bloqueador externo).

## 8. LiveOps e cadência

- [~] Carnaval/Natal com cosmético (`wall_carnaval`/`wall_natal`); pets sazonais dependem de arte.
- [x] Meta do dia no evento semanal (`LiveOps.event_goal_*`, `GameState.claim_event_goal`).
- [ ] `events.json`/preços via `RemoteConfig` (só floats hoje; pendente).

## 9. UX, acessibilidade, localização

- [~] Modo daltônico e assistência motora entregues (Ajustes); tamanho de fonte e mão esquerda pendentes. Faixa do Perfect agora desenha a janela REAL.
- [ ] Nomes de pets/staff/conquistas/cosméticos/pesquisa localizados (catálogos pt-only).
- [~] Back button Android fecha painéis (`Main._notification`); safe-area/notch pendente.

## 10. Técnico e plataforma

- [~] Ícone/splash gerados e configurados; preset Android segue no template por decisão documentada (GODOT_4_7_COMPATIBILITY.md); keystore é passo de release.
- [x] Export/import de save por código assinado (`SaveManager.export_code/import_code`, Ajustes).
- [~] Consentimento em Ajustes (nada persiste sem opt-in); adapter Firebase é bloqueador externo.
- [x] Testes de domínio no Godot na CI (prestígio, pesquisa, migração v8→atual, descoberta, agenda, recompensas).

## Ordem de execução (impacto ÷ esforço)

1. §1 recompensas/sinks escalados + §2 cofre relevante + bug dos tokens.
2. §3 telas de revelação + meta no HUD.
3. §6 share 9:16 com marca + build Web.
4. §5 diárias do catálogo + descoberta de pets pela fila.
5. §3 tier visual + música.
6. Restante por seção.

## Registro de execução

| Etapa | Commit | Conteúdo |
|---|---|---|
| 1 | `72736a4` | Recompensas/sinks escalados, cofre relevante, automação, prestígio com herança, bug dos tokens, diárias do catálogo, save v11 |
| 2 | `5dec890`/`6eb12e1` | Cartões de revelação, meta no HUD, buddy |
| 3 | `79dac86` | Share 9:16 com marca + galeria/navigator.share, workflow Web Pages |
| 4 | `1002859` | Visitante misterioso (save v12), cosméticos 11→23, meta do dia |
| 5 | `1225f43` | Mural por capítulo, trilhas de fundo por fase |
| 6 | (este) | Gesto ensinado, localização, acessibilidade, transferência de save, consentimento, back button, ícone/splash, testes de domínio na CI |

### Bloqueadores externos (não fabricáveis no repositório)
SDKs (AdMob, Play Billing, Firebase), backend social (ranking/amigos), keystore e
validação em aparelho, arte nova (acessórios, pets sazonais, estação por marco),
áudio licenciado (as trilhas atuais são sintetizadas — substituíveis 1:1 pelo
`gen_bgm.py --check`).
