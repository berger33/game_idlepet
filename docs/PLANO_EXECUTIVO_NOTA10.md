# Plano Executivo — Nota 10/10 em todas as métricas D0-D30
**Jogo:** Pet Shop Tycoon (game_idlepet)  
**Branch:** arena/01a0c221-game-idlepet  
**Data:** 2026-09-21  
**Autor:** Auditoria Retenção D0-D30 + Plano de Execução  
**Objetivo:** Elevar todas as notas de 5-8.5 para 10/10, implementando P0/P1/P2 completos.

---

## 1. Diagnóstico Resumido (base do plano)

### D0 (0-3min) — 8.5/10
- Tutorial 3 passos, Caramelo fixo, welcome card, empty queue CTA, first perfect +1 brasa, ghost translúcido (OFF default), splash progress bug (0.18s visível), QR pseudo não escaneável, shop name prompt, proof social 8-12s.

### D1 (volta) — 7/10
- Daily auto-popup via D1Retention, spin 6 prêmios, missions badge frágil, notif soft prompt após 3 serviços, offline cofre 0.15 rate cap 2h punitivo (bug maxf=elapsed, não dá 8h primeira noite), comeback 48h.

### D2-D7 — 7/10
- Services 1/3/5/7/10, pets 2/4/6/8, staff Bia 8 serviços sem celebração, combo chest 10 combo, upsell 35%, affection 50 touches, discovery visitor 3 visitas, weekly missions, pass 28 dias, event goal.

### D30 — 5/10
- 50 pets (6 memórias custom, 44 genéricas), 23 cosméticos, 6 staff automation 0.32, 30 achievements, 5 pesquisas (insuficiente), career 61.85h target, prestige sqrt(total/1M) bloqueado até Nv45 (22k no Nv15 vs 1M necessário), segunda sala só visual tier>=6, offline cap 2h = 18min para 8h sono.

---

## 2. Metas Nota 10

| Métrica | Atual | Meta 10 | Como |
|---------|-------|---------|------|
| D0 FTUE | 8.5 | 10 | Splash min 0.8s, ghost ON default D0-D3, skip reposicionado, QR real escaneável, second station hint |
| D1 Retenção | 7 | 10 | Offline cap 4h base + 8h primeira noite + 2x, badge robusto via ref, daily auto-popup garantido, notif A/B |
| D2-D7 Progressão | 7 | 10 | Bia celebração, VIP explicação, mastery visível, weekly urgência domingo, tip odds HUD |
| D30 Conteúdo | 5 | 10 | Research 15 nós (segunda fila, offline cap, VIP, tip, combo, mastery, automation), diary 50 pets custom, cosmetics 40+, segunda sala funcional, prestige rebalance 250k divisor + 1 token garantido Nv15 |
| Economia | 6 | 10 | Prestige sqrt(total/250k) + min 1 token 20k, offline 0.15→0.18 base + research 0.05→0.23, hire sink balanceado, tip odds visível |
| Viral / Share | 6 | 10 | QR lib real escaneável, share race fix (botão disabled até path pronto), caption + hashtag + link |
| Performance | 7 | 10 | QR fill_rect, PetShopCanvas cache, badge sem busca frágil |

---

## 3. P0 — Bloqueantes D1/D7 (implementar primeiro)

### P0-1: Offline cap fix + primeira noite generosa
- **Arquivos:** `autoload/SaveManager.gd`, `autoload/Economy.gd`, `autoload/RemoteConfig.gd`
- **Bug atual:** `effective_elapsed = maxf(elapsed, minf(elapsed, 8h)) = elapsed` — não dá 8h mínimo. Cap base 2h punitivo.
- **Implementação:**
  - RemoteConfig DEFAULTS offline_cap_hours 2.0 → 4.0
  - Economy.offline_earnings(new param is_first:bool = false, research_cap_bonus:float): cap_hours = base_cap + prestige_level + research_bonus_offline_cap; if is_first: cap_hours = max(cap_hours, 8.0)
  - SaveManager._grant_offline_reward: passar is_first para offline_earnings, remover lógica effective_elapsed bugada, usar elapsed_seconds direto + is_first flag para dobrar reward (já existe) e cap 8h.
  - Teste: simular 8h offline first night → reward = income_per_sec * 8h * (0.15+automation+research) *2
- **Critério aceite:** 8h sono D1 dá 4h+ de progresso (não 18min). First night 8h cap + 2x.

### P0-2: Splash visível mínimo 0.8s
- **Arquivos:** `core/ui/SplashArt.gd`, `scenes/main/Main.gd`
- **Bug:** Barra visível só 0.18s (progress 1.0 em 1.18s, visible após 1s).
- **Implementação:**
  - SplashArt.make_splash: adicionar keys visible_since, min_visible 0.8
  - update_splash: quando visible vira true, grava visible_since = elapsed. Só retorna false (pode esconder) se progress>=1.0 AND elapsed - visible_since >=0.8 AND elapsed>0.5
  - Main._process: garantir splash_progress mínimo 0.5s? Já tem delta*0.85 =1.18s total, ok. Mas hide_splash só chama quando still false. Ajustar para aguardar min visible.
- **Critério:** Splash fica visível 0.8-1.2s legível, barra anima.

### P0-3: Ghost default ON D0-D3 + auto-off após 10 perfects
- **Arquivos:** `autoload/GameState.gd`, `scenes/main/Main.gd` (ou GameState)
- **Implementação:**
  - GameState.settings training_ghost default false → true
  - _sanitize_settings: default true se não existir
  - GameState.register_tool_use ou _on_service_completed: se total_perfect_services >=10 e training_ghost true → set false + toast "Fantasma de treino desativado — você já é craque!"
  - PetShopCanvas: se training_ghost true, mostrar ghost translúcido (já existe, mas default off)
- **Critério:** Novos jogadores veem ghost nos 5 primeiros clientes, aumenta perfect rate D0 70%→85%, desliga auto após maestria.

### P0-4: Prestige token rebalance
- **Arquivos:** `autoload/Economy.gd`, `autoload/GameState.gd`
- **Bug:** sqrt(total/1M) → 1 token só em 1M, mas Nv15 total 22k → prestige bloqueado até Nv45-60
- **Implementação:**
  - Economy.prestige_tokens(total): nova fórmula = floor(sqrt(total/250000.0)) + floor(total/1000000.0 *0.5) ; se total>=20000 e tokens==0 → 1 (garantia Nv15)
  - Ou mais simples: tokens = int(floor(sqrt(max(total,0)/250000.0))); if tokens==0 and total>=20000: tokens=1
  - Isso dá: 20k→1, 250k→1, 1M→2, 4M→4, 10M→6, 25M→10, 100M→20
  - GameState.can_prestige(): manter level>=15, mas se tokens==0 e total>=15000, mostrar "quase lá" toast
  - Ajustar research custos: total 10 tokens hoje, com 15 nós total ~28 tokens — com nova fórmula, 10 tokens em ~6M (cerca de 10h) vs 100M antes (40h) — mais acessível D7
- **Critério:** Prestige desbloqueia Nv15 com 1 token, 10 tokens em ~15-20h, não 50h.

### P0-5: Research expandir 5 → 15 nós
- **Arquivos:** `data/research.json`, `core/progression/Research.gd`, `autoload/ContentDB.gd`, `autoload/Economy.gd`, `core/gameplay/SalonTuning.gd`, `core/progression/Rewards.gd`, `scenes/main/MetaPanel.gd`
- **Implementação:**
  - Novo research.json 15 nós (manter 5 IDs antigos para compatibilidade save):
    - tier1 (1 token): clean_water bath_income 0.1, gentle_formula satisfaction 0.05, quick_hands service_speed 0.04
    - tier2 (2 tokens): fast_dryer service_speed 0.06 requires clean_water, calm_pets patience 0.08 requires gentle_formula, tip_training tip_bonus 0.05 requires gentle_formula, vip_marketing vip_chance 0.05 requires quick_hands
    - tier3 (3 tokens): mobile_clinic offline_rate 0.05 requires fast_dryer+calm_pets, second_branch offline_cap 2.0 requires fast_dryer+vip_marketing, combo_shield combo_protection 1.0 requires calm_pets+tip_training, master_tools mastery_bonus 0.05 requires tip_training+vip_marketing, auto_groomer automation 0.10 requires quick_hands+fast_dryer
    - tier4 (4-5 tokens): franchise_network offline_cap 4.0 offline_rate 0.08 requires mobile_clinic+second_branch, elite_clients vip_chance 0.08 tip_bonus 0.08 requires combo_shield+master_tools, empire_legacy offline_cap 6.0 offline_rate 0.10 prestige_bonus 0.10 cost 5 requires franchise_network+elite_clients+auto_groomer
  - Research.bonus(): já soma por effect, funciona para novos keys
  - Economy.offline_earnings: adicionar param research_cap_bonus = Research.bonus(offline_cap) e somar ao cap_hours
  - Economy.vip_chance(): adicionar Research.bonus(vip_chance)
  - Economy.tip_bonus(): adicionar Research.bonus(tip_bonus)
  - SalonTuning.compute_reward: adicionar mastery_bonus e prestige_bonus
  - Rewards.automation_share(): adicionar Research.bonus(automation)
  - Goals, SalonTuning: combo_protection research check
  - MetaPanel: exibir 15 nós, tier agrupado
- **Critério:** Pesquisa dura D7-D30, não 1 dia. Segunda sala, offline cap, VIP, tip, combo, mastery, automation todos pesquisáveis.

---

## 4. P1 — Retenção +5-8%

### P1-6: Segunda sala funcional (Rede Regional)
- **Arquivos:** `core/gameplay/StationArt.gd`, `core/progression/Rewards.gd`, `scenes/main/Main.gd`, `autoload/GameState.gd`
- **Implementação:**
  - StationArt: quando tier>=6, desenhar "FILIAL 2 ATIVA" + barra progresso + glow; se research second_branch owned, mostrar "FILIAL 2 +100% RENDA"
  - Rewards.automation_share(): +0.15 se tier>=6, +0.10 se research second_branch
  - GameState._process passive: se tier>=6, passive income * (1.0 + 0.5*(tier-5)/5) → tier6=1.1x, tier10=1.5x
  - Main._process_queue: refill delay *0.5 quando tier>=6 (segunda equipe ajuda fila)
  - Main._update_queue_ui: quando tier>=6, queue cards mostram "FILIAL 2" badge se slot 0 recomendado
  - Futuro: queue 3→4 slots tier6, 4→5 tier8 (opcional, se não quebrar UI)
- **Critério:** Tier6 não é só visual, dá +15% automation + refill rápido + passive bonus. Jogador sente progressão.

### P1-7: Diário custom completo 50 pets
- **Arquivos:** `core/story/PetStories.gd`
- **Implementação:**
  - PET_MEMORIES hoje 6/50 custom, resto genérico 3 frases
  - Criar 50 entradas custom: usar template por temperamento+espécie+city+service, mas escrever 3 memórias únicas por pet (usar breed, city, temperament, preferred_service, base_tip)
  - Exemplo: para cada pet em pets.json, gerar memórias baseadas em breed+temperament (ex: "Pinscher agitado não para quieto" etc)
  - Manter GENERIC_MEMORIES como fallback, mas adicionar 44 novos pets com 3 memórias cada
  - all_memories, affection_memory já funcionam
  - Adicionar memórias em PT_BR e EN_US? Por enquanto PT_BR, usar mesmo template EN fallback genérico
- **Critério:** Coleção 50 pets, cada um com 3 memórias únicas, diary_progress 3/3 significativo.

### P1-8: Cosméticos D30 — 23 → 43 (+20)
- **Arquivos:** `data/cosmetics.json`, `autoload/ContentDB.gd`
- **Implementação:**
  - Adicionar 20 novos cosméticos:
    - bath: tub_neon (rare embers 35), tub_marble (common 1000), tub_candy (common 1200), tub_midnight (epic 80), tub_rainbow (epic 90), tub_vintage (rare 50)
    - wall: wall_forest (common 1100), wall_city (rare 40), wall_space (epic 65), wall_retro (common 1300), wall_ocean (rare 55), wall_sunset (common 1500)
    - pet_accessory: bandana_green (common 300), bow_tie (rare 30), glasses_cool (epic 50), hat_party (rare 45), collar_gold (epic 75), scarf_winter (common 800), flower_crown (rare 60), bandana_pink (common 400)
  - Preços escalados via Rewards.cosmetic_price (segundos de renda)
  - Adicionar source achievement para 5 novos: cosmetics_10, staff_3 etc
  - Rotação diária: ContentDB.weekly_featured_cosmetic() já existe semanal; adicionar daily_featured_cosmetic() por hash dia + weekly, e MetaPanel mostrar 2 destaques (diário + semanal)
- **Critério:** Loja não esgota em 1 semana, 40+ itens, rotação diária, metas de coleção.

### P1-9: Weekly reset urgência + timer
- **Arquivos:** `autoload/LiveOps.gd`, `core/progression/Goals.gd`, `scenes/main/MetaPanel.gd`, `core/ui/D1Retention.gd`
- **Implementação:**
  - LiveOps.weekly_reset_label(): hoje retorna "X dias", melhorar para "Último dia! 2/7" domingo + horas restantes
  - Adicionar LiveOps.weekly_hours_remaining() e weekly_is_last_day()
  - MetaPanel._build_missions: se último dia (domingo) e progresso <7/7, mostrar banner vermelho "⏰ ÚLTIMO DIA! 2/7 missões" + timer horas
  - Goals.hud_line(): se domingo, adicionar "⏰ Último dia semanal!"
  - D1Retention: no domingo, toast "Semana acabando! Complete 7/7 para baú 3 brasas"
- **Critério:** Jogador sente urgência domingo, FOMO weekly chest.

### P1-10: QR escaneável real
- **Arquivos:** `core/ui/QRCodeArt.gd`, `autoload/ShareManager.gd`
- **Implementação:**
  - Substituir pseudo-QR por lib QR real escaneável (implementar algoritmo QR Code Model 2, ECC L/M, mask, etc)
  - Opção A: implementar QR Code generator completo em GDScript (ex: Nayuki QR Code MIT port)
  - Opção B: usar lib existente qrcode.gd (se não existir, implementar versão simplificada que gera QR válido para URLs curtas)
  - Gerar QR com dados: SHARE_URL se existir, senão "petshop://pet=caramelo&stars=5&shop=MeuPet" ou link curto
  - Otimizar generate_image: usar fill_rect em vez de set_pixel loop O(N²) — criar Image, depois desenhar rects por célula
  - ShareManager: qr_data = SHARE_URL if not empty else "https://petshop.tycoon/share?pet=%s&stars=%d" % [pet_id, stars] (placeholder escaneável)
- **Critério:** QR no share card é escaneável por celular, leva a link (mesmo que placeholder), viralidade real.

---

## 5. P2 — Polish

### P2-11: Tutorial skip reposicionar
- **Arquivos:** `scenes/main/Main.gd`, `scenes/main/TutorialFlow.gd`
- **Implementação:**
  - Main._build_interface: tutorial_skip_button position (45,145+safe) colide com nav (30,145). Mover para (750,145+safe) ou (900,145+safe) direita, ou (540-150, 100) topo centro
  - Tamanho 300x68 → 220x56 para não cobrir nav
  - TutorialFlow: spot_rect já ok
- **Critério:** Skip não sobrepõe nav, legível.

### P2-12: Share race fix
- **Arquivos:** `autoload/ShareManager.gd`, `scenes/main/Main.gd`, `core/gameplay/SalonPanels.gd`
- **Implementação:**
  - ShareManager: adicionar signal share_ready(path) emitido após finish_snapshot salvar
  - Main: share_button disabled até last_saved_path != "" ; conectar signal para habilitar
  - Ou: share_button visible = false inicialmente, só true após finish_snapshot + path existir
  - Adicionar ShareManager.is_ready() bool
  - Main._show_success: após finish_snapshot, await ou check path antes de mostrar share_button
  - Fix race: finish_snapshot é async (await frame_post_draw), mas _show_success não await — fazer _show_success await ShareManager.finish_snapshot e só então mostrar botão
- **Critério:** Botão share nunca aparece com path vazio, nunca toast "Falhou" se clicado rápido.

### P2-13: Missions badge robusto via ref
- **Arquivos:** `core/ui/D1Retention.gd`, `scenes/main/Main.gd`, `scenes/main/MetaPanel.gd`
- **Implementação:**
  - Main.gd: guardar ref missions_button ao criar nav (var missions_button: Button)
  - D1Retention._find_missions_button: tentar main.missions_button primeiro, fallback busca frágil
  - Ou: Main expõe missions_button property, D1Retention usa diretamente
  - ensure_missions_badge e update_missions_badge usam ref robusta
- **Critério:** Badge não quebra se SalonPanels mudar estrutura.

### P2-14: Tip odds visível HUD
- **Arquivos:** `core/gameplay/SalonTuning.gd`, `scenes/main/Main.gd`, `core/ui/SessionFeedback.gd`
- **Implementação:**
  - Economy.TIP_ODDS já publicadas: 60/25/10/5
  - Main._refresh_economy ou queue_info: mostrar tip odds no result_detail ou no goal_label?
  - Melhor: result_detail já mostra tip_line, mas antes do serviço, queue_info_text poderia mostrar "$/$$/$$$ + odds"
  - Adicionar SalonTuning.tip_odds_text() que retorna "60% 0% | 25% +15% | 10% +30% | 5% +60%"
  - MetaPanel settings ou map: adicionar nota "Gorjetas: 60% sem, 25% +15%, 10% +30%, 5% +60% + bônus bairro"
  - HUD: adicionar tooltip no coin_label ou review_label com odds
- **Critério:** Jogador entende loteria gorjeta, transparência aumenta confiança.

### P2-15: Performance QR + PetShopCanvas
- **Arquivos:** `core/ui/QRCodeArt.gd`, `core/gameplay/PetShopCanvas.gd`
- **Implementação:**
  - QRCodeArt.generate_image: ao invés de set_pixel por pixel (44k calls), usar Image.fill + draw rects: criar imagem branca, depois para cada célula preta, fill_rect com black
  - Usar Image.fill_rect() se disponível, ou criar PackedByteArray e set data
  - PetShopCanvas._draw: verificar se desenha tudo a cada frame — já ok, mas adicionar culling: só desenha bolhas, hearts se world.service_active
  - Cache de texturas já existe em StationArt._art_cache
- **Critério:** Share card gera em <100ms, sem lag.

---

## 6. Ordem de Execução (para commit único ou sequencial)

1. **P0-1 Offline cap** (SaveManager, Economy, RemoteConfig) — 30min
2. **P0-2 Splash** (SplashArt, Main) — 15min
3. **P0-3 Ghost default** (GameState) — 10min
4. **P0-4 Prestige** (Economy) — 15min
5. **P0-5 Research 15 nós** (research.json + Research.gd + Economy + Rewards + SalonTuning) — 1h
6. **P1-6 Segunda sala funcional** (StationArt, Rewards, GameState, Main) — 45min
7. **P1-7 Diário 50 pets** (PetStories.gd) — 1h
8. **P1-8 Cosméticos 43** (cosmetics.json) — 30min
9. **P1-9 Weekly urgência** (LiveOps.gd, MetaPanel) — 30min
10. **P1-10 QR real** (QRCodeArt.gd) — 1.5h
11. **P2-11 Skip reposicionar** (Main.gd) — 5min
12. **P2-12 Share race** (ShareManager, Main) — 20min
13. **P2-13 Badge robusto** (D1Retention, Main) — 15min
14. **P2-14 Tip odds HUD** (SalonTuning, Main, MetaPanel) — 20min
15. **P2-15 Performance** (QRCodeArt) — incluído no P1-10

**Total estimado:** 7h de implementação, 1h testes, 30min docs.

---

## 7. Critérios de Aceite Nota 10

- **D0:** Novo jogador vê splash 0.8s legível, ghost ON, Caramelo recomendado, empty CTA funciona, first perfect celebração, skip não sobrepõe, QR escaneável no share (teste com celular).
- **D1:** Dorme 8h, volta e vê cofre 4h+ (não 18min), daily auto-popup, badge pulsante, spin, notif prompt, comeback 48h com freeze.
- **D2-D7:** Bia chega com celebração, VIP explicado, weekly urgência domingo, tip odds visível, mastery selos, combo chest, upsell.
- **D30:** 15 pesquisas (não 5), 50 pets memórias custom, 43 cosméticos, segunda sala funcional (automation + refill), prestige Nv15 com 1 token, 10 tokens em ~15h, offline cap 24h max com pesquisa.
- **Economia:** Nenhum bloqueio, prestige mantém 25% estação, pesquisa sobrevive, sink tokens→brasas funciona, hire price escala.
- **Viral:** Share card 9:16 com QR escaneável, caption pronta, pasta galeria, legenda clipboard.
- **Performance:** Share <100ms, sem set_pixel loop, badge sem busca frágil.

---

## 8. Riscos e Mitigação

- **Save compatibilidade research:** manter IDs antigos, adicionar novos — _valid_research_array já filtra por ContentDB.research_by_id, ok.
- **Main.gd 1100 linhas limite:** usar static helpers (SalonTuning, Research, D1Retention, Rewards) já padrão, não adicionar lógica no Main, só refs.
- **GameState 38 métodos limite:** não adicionar métodos públicos, usar existing ou static helpers.
- **QR lib pesada:** implementar versão mínima QR v1-v4 com ECC L, suficiente para URL curta <50 chars, não precisa suportar 100+ chars.
- **Second station quebra UI:** manter queue 3 slots visual, bonus via automation, não expandir para 6 slots sem teste UI.

---

## 9. Commit e Entrega

- Branch: arena/01a0c221-game-idlepet
- Commits: 1 commit plano + 1 commit implementação completa (ou múltiplos P0/P1/P2)
- Push: git push origin arena/01a0c221-game-idlepet
- Testes: DomainTests.gd headless (bath boundaries, economy invariants, content contract 50 pets, state sanitization, liveops schedule, rewards/missions determinism, save migration, prestige/research, discovery)
- Docs: atualizar AUDITORIA_D1_RETENCAO.md, AUDITORIA_PRIMEIRA_IMPRESSAO_D0.md com "Corrigido P0-P2 Nota 10"

---

## 10. Próximos Passos Pós-Nota 10

- Fundo por capítulo (art/backgrounds por tier)
- Multiplayer visitas (visitar pet shop amigo)
- Torneio combo semanal (ranking local)
- IAP real billing (Google Play Billing)
- Analytics funil D0-D7-D30 (eventos já existem, só dashboard)

**Fim do plano.**
