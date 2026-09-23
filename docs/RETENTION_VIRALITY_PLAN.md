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
- [x] Cadência de upgrades: mural por capítulo (`ChapterArt.gd`) + estação evoluindo a cada 10 níveis (`StationArt._draw_station_evolution`).

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
- [x] **Transformação visual por marco**: mural + luz por tier (`ChapterArt.gd`); estação evoluindo a cada 10 níveis (`StationArt._draw_station_evolution`: toalha/patinho/planta/brilho/coroa por marco).
- [x] **Música relaxante restaurada** (pedido do usuário 2026-09-21): `AudioManager._ambient_loop()` 16 s, C/Am/F/G com crossfade 0,4 s, baixo suave oitava abaixo, melodia esparsa — muito mais relaxante que as 3 trilhas de `gen_bgm.py` (quintal/clínica/império) que continuam em `audio/bgm/` como alternativa. Ganho 0,22, tier não troca música.
- [x] **Meta visível no HUD** (`Goals.hud_line`): "próximo: Nina (Nv.20) • Sala de Secagem (Nv.5)".
- [x] Buddy 40% → 25% subindo com afeto.

## 4. Onboarding e primeira sessão

- [x] Mini-tutorial por gesto novo (`TutorialFlow.teach_service`, spotlight + dica, 1× por serviço).
- [x] Localizar as ~30 strings pt cravadas (`Main.gd`, `GameState.gd`,
  `TutorialFlow.gd`, `MetaPanel.gd`).
- [x] Nomear o pet shop (Ajustes → placa da sala e cartão de share); buddy já é escolhido na coleção.

## 5. Retenção D1–D30

- [x] **Diárias do catálogo** (`Missions.gd`, sorteio por data, metas escaladas, épica) (`daily_missions.json`: 3 sorteadas + épica, metas
  escaladas ao nível) — hoje 3 fixas triviais.
- [x] **Descoberta de pets pela fila** (`Discovery.gd`, visitante 3×, save v12): visitante misterioso antes do destravar.
- [x] Teto cosmético 11 → 23 (banheiras por dado + 4 paredes procedurais); rotativo semanal (`ContentDB.weekly_featured_cosmetic` + `MetaPanel._build_shop` destaque).
- [x] Cliente que vai embora não soma reputação (`_client_left` → sem `register_review`).

## 6. Social e viralização

- [x] **Share 9:16 com marca** (`ShareManager`: SubViewport, galeria/`navigator.share`, legenda no clipboard): só o pet (antes/depois), nome/raça/estrelas, logo,
  legenda; salvar na galeria/share sheet (`OS.share`/plugin) em vez de `user://`.
- [x] **Build Web publicável** (preset sem threads + `.github/workflows/web-pages.yml`) (preset existe) como canal viral.
- [x] **Card compartilhável de conquista** (`ShareManager.share_achievement` + `MetaPanel._build_collection` botão compartilhar).
- [ ] Ranking assíncrono / visita a amigos / código de convite — exige backend (bloqueador externo).

## 7. Monetização

- [x] Rewarded: placements prontos (dobrar cofre, +1 brasa) sobre o `AdsManager`; o SDK AdMob é bloqueador externo mas placements e fallback estão prontos.
- [ ] IAP: sem anúncios, pacote iniciante, passe premium — exige Play Billing (bloqueador externo).

## 8. LiveOps e cadência

- [x] Carnaval/Natal com cosmético (`wall_carnaval`/`wall_natal`); rotativo semanal via `events.json` + `RemoteConfig`.
- [x] Meta do dia no evento semanal (`LiveOps.event_goal_*`, `GameState.claim_event_goal`).
- [x] `events.json`/preços via `RemoteConfig` (`ContentDB.weekly_featured_cosmetic` + `Rewards.cosmetic_price` com `RemoteConfig` scales; `events.json` fonte da verdade semanal).

## 9. UX, acessibilidade, localização

- [x] Modo daltônico e assistência motora entregues (Ajustes); tamanho de fonte (`SalonTuning.font_scale` + botões em Ajustes) e mão esquerda (`left_handed` + `PetShopCanvas._tool_position` + `StationArt.draw_shelf_unit` espelhada) concluídos. Faixa do Perfect desenha a janela REAL.
- [x] Nomes de pets/staff/conquistas/cosméticos/pesquisa localizados (`ContentDB.pet_name/staff_name/achievement_name/cosmetic_name/research_name` + `data/localization/*.csv`).
- [x] Back button Android fecha painéis (`Main._notification`); safe-area/notch (`SalonTuning.safe_area_top` + `Main._build_interface` offset).

## 10. Técnico e plataforma

- [x] Ícone/splash gerados e configurados (`art/ui/icon.png` 9.1K + `art/ui/splash.png` 24K, `export_presets.cfg` `config/icon` + `boot_splash/image`); preset Android segue no template por decisão documentada (GODOT_4_7_COMPATIBILITY.md); keystore é passo de release (bloqueador externo).
- [x] Export/import de save por código assinado (`SaveManager.export_code/import_code`, Ajustes).
- [x] Consentimento em Ajustes (`Analytics.consent_given()` lê `settings.analytics_consent`; `flush_offline()` apaga `user://analytics_queue.jsonl` sem opt-in; nada persiste); adapter Firebase é bloqueador externo mas fachada com opt-in está pronta.
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
| 6 | (este ciclo) | Gesto ensinado, localização completa (pet/staff/ach/cos/research), acessibilidade (fonte/mão esquerda), safe-area, evolução visual da estação a cada 10 níveis, share de conquista, rotativo semanal, transferência de save, consentimento, back button, ícone/splash, testes de domínio na CI |
| 7 | `b393f0d`/`bdac9c9` | Lint 0 erros, Main.gd <1100 linhas via SalonTuning helpers, MetaPanel share path fix, StationArt evolução visual + left-handed, font_scale/safe-area em SalonTuning |
| 8 | `7e79fb3` | Audio: restaura BGM relaxante original (16 s, C/Am/F/G crossfade, baixo suave) — pedido do usuário, gen_bgm.py mantido como alternativa |

### Bloqueadores externos (não fabricáveis no repositório)
SDKs (AdMob, Play Billing, Firebase), backend social (ranking/amigos), keystore e
validação em aparelho, arte nova (acessórios adicionais, pets sazonais além dos 2 já
presentes), áudio licenciado (as trilhas atuais são sintetizadas — substituíveis 1:1 pelo
`gen_bgm.py --check`).
