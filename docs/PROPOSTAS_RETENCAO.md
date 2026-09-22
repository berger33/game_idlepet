# Próximas ideias de dinamismo & retenção — pós-Parquinho (2026-09-22)

> O **Parquinho** (fantasia 2) foi entregue como MVP jogável, localizado e com `validate 0E/0W`. Abaixo 3 mecânicas que reusam o que já existe (staff, offline, coleção, LiveOps) e fecham o ciclo **D1 → D7 → D30** sem novo pipeline de arte pesado.

---

## 1) Contratos de Passeio — “Van do Bairro” (variante afinada da *Expedição*)

**Pitch:** seus pets saem para um passeio pago no bairro (Centro 5 min, Vila Galvão 15 min, Bosque Maia 45 min). Você escolhe o trio, a van sai, volta sozinha com `+R$` e uma **Memória do Bairro** (postal colecionável). Nenhum novo gesto — só escolha.

- **Core:** botão `🚐 Contratos` no mapa (tier ≥2) → modal 3 opções (curto/médio/longo) → `Contratar equipe` (Bia/Seu Zé aceleram 20%). Van anima em `PetShopCanvas` (path simples). `OfflineSecondsCollected` já cobre o retorno offline; `Research.bonus("patience")` vira `contract_speed`.
- **Cooldown:** 3 contratos simultâneos max, `RemoteConfig.contract_cooldown = 900..3600`. Overlap intencional com parquinho (2 h): jogador volta a cada 30 min para recolher van + jogar parquinho.
- **Recompensa:** `R$ = bath_base_reward × (0.8/1.2/1.8)` + chance de `postal` (data/postcards.json, 12 itens) → completa álbum do bairro → 5 Brasas. Postal não é moeda — é *coleção visual* que alimenta share.
- **LiveOps:** `RemoteConfig.contract_event_boost` em 2× no fim de semana chuvoso (story: “passeio na chuva rende mais”).
- **Esforço:** M (2 arquivos: `ContractService.gd` + `ContractCanvas.gd`; reuse `world.celebrate`).
- **Risco:** baixo — não é gacha, não compete com fila.
- **Métrica:** sessões/dia +48h retenção (`return_bonus` correlaciona com van).

---

## 2) Álbum & Concurso Semanal de Fotos — “Capa da Revista Pets”

**Pitch:** toda foto `📸` perfeita no Parquinho salva no **Álbum** (grid 3×N). Todo sábado às 10h o bairro elege a melhor foto da semana — ganha troféu + cosmético exclusivo da estação.

- **Core:** `GameState.park_photos: Array[Dictionary]` `{pet_ids, activity, timestamp, score}` guardado no save. UI em `MetaPanel` aba `Álbum` (reuse `SalonPanels.build_grid`). Sábado: `LiveOps.current_event_name() == "Sábado do Combo"` já dobra pontos → `ConcursoService.rank()` ordena por `score` + `afeto`.
- **Recompensa:** top 1 = `troféu_capa.png` (reuse `crown_gold`) + `+R$ 200` + `+3 brasas` + postal dourado. Todos participantes ganham `+R$ 30`. Share auto gera antes/depois com moldura “CAPA”.
- **Social sem servidor:** ranking é local (não precisa backend); variante futura pode ler `RemoteConfig.weekly_featured_cosmetic` para dar o prêmio da comunidade.
- **Esforço:** S (1 arquivo `AlbumPanel.gd`, extensão do `ParkService` para salvar foto).
- **Métrica:** D7 retenção e `share` orgânico; expectativa +15% `perfect` no parquinho às sextas.

---

## 3) Aniversários & Festa do Bairro — calendário afetivo Guarulhos

**Pitch:** cada pet tem **aniversário de chegada** (ex: Caramelo chegou dia do seu primeiro banho). 3 dias antes: balão na fila; no dia: bolo no quintal, `2× afeto` e visitante regional exclusivo (ex: feira do Bosque Maia traz um “visitante capivara”).

- **Core:** `GameState.pet_adoption_dates: Dictionary pet_id→unix` preenchido em `register_review` da 1ª vez. `Research` já tem `seasonal` (carnaval, festa_junina, natal) — adiciona `bairro_week` (ex: “Semana do Bosque Maia” em maio) que dobra `park_reward`. `NotificationManager` agenda `🔔 Amanhã é aniversário do Bento!`
- **Recompensa:** bolo = `+5 afeto` instant + `1 freeze` + `postal de festa`. Sem paywall — é surpresa afetiva.
- **Esforço:** M (datas + 3 `RevealCard` + agenda de notificações).
- **Métrica:** D30 + reativação de churn ( `check_return_bonus` já faz 48h; aniversário faz 21–30d).

---

### Matriz esforço × impacto

| Ideia | Esforço | Impacto D1 | D7 | D30 | Reuso |
|---|---|---|---|---|---|
| **Contratos (Van)** | M | ★★ | ★★★ | ★★ | staff/offline/mapa |
| **Álbum/Concurso** | S | ★ | ★★★ | ★★★ | parquinho/coleção/share |
| **Aniversário** | M | ★ | ★★ | ★★★ | seasonal/notif/research |

> Recomendação de ordem **pós-Parquinho**: 2 → 1 → 3. **Álbum** fecha o loop do Parquinho sem nova arte (só moldura) e já cria conteúdo compartilhável para o Concurso; **Van** dá razão para voltar a cada 30 min; **Aniversário** é o gancho emocional de longo prazo que a pesquisa “Amigo dos Pets” hoje não entrega.

Tudo com `RemoteConfig`, `Loc.t` e `SAVE_VERSION 12` — nenhuma quebra de `validate`.
