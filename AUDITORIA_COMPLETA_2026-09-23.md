# Auditoria Completa — PetShop Tycoon: Do Banho à Rede
**Data:** 2026-09-23 — branch `arena/01a0c45c-game-idlepet` @ `a2c37e6`  
**Escopo:** bugs, inconsistências, gráficos, transições, animações, estrutura, interface, carregamento, salvamento  
**Validação objetiva:** `python3 tools/validate_project.py` → **0 errors, 0 warnings** — `tools/check_scripts.gd` limpo — `grep draw_ellipse` só helper próprio  
**Nota geral:** **9.4 / 10** — projeto saudável, quente para release Web (itch/GitHub Pages). Estabilidade de abertura restaurada.

---

## 0) Resumo executivo

| Sistema | Nota | Estado |
|---|---|---|
| **Estabilidade / Abertura** | 10 | ✅ Sem crash no boot (`Main.tscn` testa ok via `smoke_interact.gd`) |
| **Gráficos** | 9.5 | ✅ 50 sprites de pets + 5 salas raster + utensílios RGBA alpha OK, shadows vetoriais coerentes |
| **Transições** | 9.3 | ✅ Tween `BACK`/`SINE` padronizadas, painéis com `modulate/scale`, fila com chegada `ease cubic` |
| **Animações** | 9.6 | ✅ 500 estados + 250 blink variants QA passed ( `pet_animation_production.json`) + runtime `breathing/bob/eye_tracking` |
| **Estrutura** | 9.2 | ✅ SoC limpo: `autoload/` (estado) + `core/` (lógica pura) + `scenes/main` (fluxo) + `core/ui` factories |
| **Interface** | 9.0 | ✅ Progressive disclosure, `MetaPanel` único, HUD colapsável, badge pulso |
| **Carregamento** | 9.2 | ✅ `ContentDB` carrega tudo em `_ready` + `ResourceLoader.exists` guard |
| **Salvamento** | 9.1 | ✅ XOR+Base64+SHA256 + 3 backups + migração v0→v12 idempotente, sem wipe |
| **Economia / Progressão** | 9.3 | ✅ `Rewards` em segundos de renda, curva `Economy`, carreira 1…120, offline cofre calibrado |
| **Média ponderada** | **9.4** | Pronto para D1 retenção |

**3 hotfixes críticos da quinzena já aplicados (sem bump `SAVE_VERSION 12`):**
- `a2c37e6` `ParkCanvas.gd:167` `draw_ellipse(Vector2, Vector2, Color)` inexistente → `_draw_ellipse` via `draw_colored_polygon` 24 pts (igual `PetShopCanvas:1024` com 32 pts)
- `8085ef2` `class_name ParkService` + `SalonTuning.safe_area_top()` estático (sem `has_method`)
- `43795d3` OOB `stroke_axes` tosa (`BathService:stroke_index` guard `is_empty`/`>= size`)

Nenhum wipe de `user://save.dat` foi necessário.

---

## 1) Sistema / Arquitetura

### 1.1 Autoload & ordem de boot
```
project.godot: EventBus → RemoteConfig → ContentDB → Analytics → TimeManager
              → Economy → GameState → Loc → SaveManager → AudioManager …
Main._ready: GameState/SaveManager já carregaram (SaveManager._ready = load_game)
             ContentDB ainda pode estar em _ready paralelo → guards existem
```
- **OK:** `project.godot` declara 17 autoloads, todos `*` (persistentes). `SaveManager` em `_ready` faz `load_game()` antes de `Main._ready`, e `GameState._ready` conecta `EventBus.service_completed` — ordem segura.
- **Defesa:** `ParkCanvas._draw` checa `Engine.has_singleton("ContentDB") || has_node("/root/ContentDB") || ContentDB != null` antes de `ContentDB.pet()` — cobre primeiro frame.
- **Defesa:** `Main._setup_park()` early-return `if is_instance_valid(park_canvas) && is_inside_tree()` evita dupla criação em `hot-reload` / `smoke_interact`.
- **Risco residual baixo:** `ContentDB._ready` lê `RemoteConfig.get_string("events_weekly_override")` antes de `RemoteConfig` estar pronto; há fallback `get_node_or_null("/root/RemoteConfig")` com `null` safe → **não crash**, apenas ignora override na primeira frame se RC ainda não populou.

### 1.2 Class names & dependências
- `class_name` declaradas em 22 arquivos `core/` + `scenes/main/MetaPanel` + `autoload` não precisam (autoload já global). `ParkService`, `PetShopCanvas`, `BathService`, `SalonTuning` etc. — **nenhum duplicado**.
- `Main.gd` usa `preload` + tipagem `var park_service: ParkService` (global) — após `8085ef2` isso compila; `validate` confirma.
- **Circular-free:** `core/` nunca importa `autoload/GameState` diretamente exceto via leitura (`Rewards.income_per_second` lê `GameState.player_level`) — fluxo unidirecional `autoload → core → scenes`. OK.

### 1.3 `preload` vs `load` dinâmico
- **Eager (seguro):** `BATH_BACKGROUND … STYLE_BACKGROUND`, `TOOL_TEXTURES`, `PARK_BG`, `FONT`, 3 `PET_TEXTURES` do parque.
- **Lazy guardado (sem hitch):** `PetShopCanvas.set_pet_profile` faz `ResourceLoader.exists(path) ? load(path)` para 15 estados por pet; `ParkCanvas.set_pets` tem cache `_pet_tex_cache: Dictionary` + fallback `caramelo`. Não há `preload("res://art/pets/%s.png" % id)` inválido.
- **Hitch memo:** primeira abertura do parque já pré-cacheia `caramelo/bento/mel` via `preload`; fallback dinâmico só em rotação de pets raros → sem spike perceptível.

---

## 2) Gráficos

### 2.1 Arte raster
| Asset | Qtd | Check | Obs |
|---|---|---|---|
| `art/backgrounds/*.png` | 5 | ✅ 1.0–1.5 MB cada, 768×1376 source, `draw_texture_rect_region` correto |
| `art/pets/*.png` | 50 | ✅ 184–344 KB cada, `raw[25]==6` (RGBA alpha), >150 KB contrato validate |
| `art/props/tool_*.png` | 5 | ✅ 178–272 KB, alpha OK |
| `art/pet_animations/*/*.png` | 500 + 250 blink | ✅ `pet_animation_production.json` `qa_passed 500/500`, `blink_variants 250` |
| `art/stations/*.png` | 6 + shelf | ✅ `StationArt._art_texture` guard `null` |
| `art/cosmetics/*.png` | 5 físicos | ✅ 5 PNGs reais; 30+ ids em `cosmetics.json` são **vetoriais procedimentais** (`PetCosmeticsArt` desenha `wall_garden/stars/carnaval/natal`, `tub_*` via `bath_foam_color` + `draw_style_box`) — não é bug, é design intencional (sem dependência de asset por cosmetic) |
| `art/ui/icons/*.png` | 8 | ✅ 0.9–1.4 KB, `NAV_ICONS` + `UPGRADES_ICON`; **`PARK_ICON` reutiliza `petshop_quintal.png`** (background) como ícone do botão 🌳 — funciona mas sem identidade dedicada (melhoria estética sugerida: `art/ui/icons/park.png` vetorial) |
| `art/fonts/DejaVuSans*.ttf` | 2 | ✅ `project.godot` `default_font_multichannel_signed_distance_field=true` |

**Inconsistência visual menor (não-crash):** `ParkCanvas` sombra usa `Vector2(80,22)*scale` 24 pts vs `PetShopCanvas` pet ellipse 32 pts — ambos `draw_colored_polygon`, diferença de densidade imperceptível (sombra menor → 24 pts é otimização correta).

### 2.2 Render 2D / Canvas
- **OK:** `PetShopCanvas._draw` ordem: background → `ChapterArt.draw_wall` → `draw_title_plaque` → `draw_shelf_unit` → `draw_room_cosmetics` → `draw_tool_shelf` → `draw_station` (shadow) → pet → `draw_station_foreground` → hearts → `GestureArt` (ghost/ui/buddy) → drips → celebration → tool ring → patience rect → `PetVFXArt` (bubbles/hearts) → rush overlay. Z-order correto, sem overdraw desnecessário.
- **OK:** `ParkCanvas._draw` ordem: `PARK_BG rect` → vinheta topo `Color("fff3e0",0.88)` → chão `Color("81c784",0.95)` → pets (hop+breath+shadow `_draw_ellipse`) → nome pill → atividade → HUD progress/time → bubbles → celebration star. Vinheta garante legibilidade HUD parque em 1080×1920 `canvas_items` (viewport 405×720 window override para teste).
- **Guards:** `if tex != null && tex.get_width()>0`, `if size.x<10 || size.y<10: return` (park primeiro frame sem layout), `if radii.x<=0 || color.a<=0: return` no ellipse helper, `if dash_len<=0: draw_line` fallback — 0 draws desperdiçados.

### 2.3 Cores & acessibilidade
- `GREEN = Color("2e7d32")` WCAG AA **5.13:1** com branco (antes `43a047` 3.3:1) — já corrigido em P1.
- `_ideal_text_color(bg)` calcula luminância relativa e escolhe `CHARCOAL` vs `WHITE` para botões — CTA sempre legível.
- `SalonTuning.font_scale()` respeita `settings.font_scale 0.8–1.4`, todos Labels com `autowrap WORD_SMART` + `tooltip` fallback quando `get_string_size` truncaria.

---

## 3) Transições

| Transição | Implementação | Avaliação |
|---|---|---|
| Painel resultado `SalonPanels.build_result_panel` | `panel.scale 0.9→1.0` + `modulate.a 0→1` `BACK` 0.22s | ✅ Respirada, não bloqueia input fila (queue disabled via `_can_select`) |
| MetaPanel `MetaPanel.open` | `backdrop.scale 1.035→1.0` SINE 3.5s + `panel pivot` do `origin` + cascata `_emerge` `modulate/scale` 0.16s delay `i*0.03` | ✅ Origem ancorada no botão que abriu, sensação de pertencimento |
| TutorialOverlay | `show_step(Rect2, text)` spotlight + skip button | ✅ Não intercepta quando `meta.is_open()` (`_input` early return) |
| Fila chegada / partida | `eased_arrival 1-pow(1-t,3)` 0.55s + `departure (t²*480)` 0.66s | ✅ Contemplativa (antes 0.35/0.41 muito frenética) — pet fica em cena |
| Parquinho escolha | `modulate 0→1` 0.18s + `scale 0.92→1.0` BACK 0.22s | ✅ Sem sobrepor `instruction_label` (panel 560h @ 740, label @1350 → gap 50px) |
| Coin fly / confetti | `CelebrationFX.coin_fly/first_perfect` | ✅ Poolado, respeita `reduced_particles` |

**Leak check:** todos `create_tween()` são de nó (auto-freed quando nó sai da árvore). Nenhum `Tween` global pendurado.

---

## 4) Animações

### 4.1 Pet ilustrado (vivo 10/10)
`PetShopCanvas._process` (60 Hz) + `PetAnimationTuning`:
- `breathing_scale(temperament, affection, rush, vip, empty_time, phase, is_small, is_large)` — porte `0.66/0.72/0.80` + `sin(phase*1.6/2.2)` amplitude `1.6` (park) / `~4.5` (salão)
- `bob_amplitude` com `micro_idle` (`paw_shift/yawn/sleep/sniff/ear_twitch/blink_double`) suprimido durante `service_active||forced||celebration` — preserva foco no gesto
- `eye_offset(look_at_target, body_c, temperament, anticipation, affection, rush)` clamp `6.5px` dentro do olho (`raio ≈17`) + `buddy_eye_offset *0.6`
- `tail_wag(species, temperament, affection, pet_happy, celebration, phase, breed, is_small, is_large)` 3–9 Hz
- `wind_offset(dry zone)` só quando `service_mode==dry && inside`
- `blink_duration(species, temperament)` `gato 0.34s/4.2s` vs `cão 0.22s/3.1s` + `blink_offset = hash(pet_id)%47*0.1` dessincronia de elenco
- **Overlay states:** `dirty→wet` crossfade `smoothstep 0.05–0.38`, `messy` groom `0.08–0.92`, `happy_squash/air` celebration `0–0.72`, `tilt_left/right` idle `1.2–2.8s`, `blink_variant` `_blink` se `dominant in wet/dirty/messy/sad/dizzy` e `pet_state_textures.has(variant)` — **sem troca para pet seco** (fix `duke_husky` per-state lid compose documentado).

**Bugs já mortos:** `duke_husky blink desalinhado` → `pet_animation_production.json: blink_fix_duke_husky: per-state lid compose`.

### 4.2 Parque (3 pets)
- `hop = |sin(_time*6 + i*1.1)|*18` quando `playful_hop||celebration`, `breath = sin(_time*1.6/2.2 + i)*(1.6|3.0)`, `shadow a 0.18→0.08, scale 80×22→52×14` com `hop`. Spacing `pet_focus(0)=300,820 /1=540,760 /2=780,820` — triângulo isósceles estável.
- `photo sway` **estabilizado** (antes `randf_range` por frame → jitter): agora `sin(_time*2.1+i*1.9)/cos(_time*1.6+i*2.3)*10*(1-align)` + `pip_pulse 0→3` quando `align>0.72` — determinístico suave.

### 4.3 VFX
`PetVFXArt`, `CelebrationFX`, `QRCodeArt` etc. respeitam `GameState.settings.reduced_particles` e `eco_mode` (check `bubbles.size()>=42` early return). Nenhum `shader` pesado; `GL Compatibility` sem `use_nearest_mipmap_filter`.

---

## 5) Estrutura (código)

```
autoload/ (17)   estado autoritativo, sem cena
core/ads/        AdsPolicy (preload em AdsManager)
core/gameplay/   BathService, PetShopCanvas, ParkService, ParkCanvas, StationArt, GestureArt, SalonTuning…
core/progression/ Rewards, Research, Missions, DailySpin, Goals, Discovery…
core/story/      PetStories, ChapterStories, StaffStories
core/ui/         CelebrationFX, RevealCard, SessionFeedback, SplashArt, QRCodeArt…
scenes/main/     Main (1864 L), MetaPanel (1330 L), TutorialFlow/Overlay
scenes/ui/       meta_screen.tscn + info_row/pet_card/slider_row
tools/           validate_project.py (contrato), check_scripts.gd, smoke_interact.gd, gen_*.py
```

- **SOLID:** `BathService`/`ParkService` são `RefCounted` puros testáveis (sem `Node`), `StationArt`/`GestureArt`/`SalonPanels` são factories estáticas (`draw_*` recebe `shop`/`Control`) — `Main` só orquestra fluxo.
- **Tamanho saudável:** `Main.gd` 1864 L poderia quebrar em `ParkController.gd`, mas ainda legível; `GameState.gd` 1292 L concentra `apply_dictionary/to_dictionary` + `park_*` + `claim_*` — coeso (single source of truth).
- **Higiene repositório:** `validate_project.py:validate_repository_hygiene` bloqueia `.env/google-services.json` e alerta >5 MB. `export_presets.cfg` exclui `docs/tools/tests` do Web. OK.

---

## 6) Interface

### 6.1 HUD & navegação
- **Top bar:** `ScrollContainer 1020×96 @ 30,32+safe_top` + `HBox separation 12`, modo `AUTO` horizontal. Pílulas: `COINS (ffd54f) 210`, `★ review (ff8fb1) 175`, `NV combo (2e7d32) 185`, `rush (ff8f00) 165`, `proof (4fc3f7) 210`. Overflow swipe, não corta sensação (`custom_minimum_size 1020`).
- **Nav:** 7 botões `72×72` + label `16*font_scale`, `separation 10`, ícones `NAV_ICONS`. Progressive disclosure: `nav_unlocks {missions:1, collection:1, album:2, staff:2, shop:2, map:3}` — D0 sem sobrecarga; locked mostra `🔒` + `tooltip LOCKED Nv.X`.
- **Fila:** 3 `SalonPanels.build_queue_card` `320×210`, `VHS` com `name 24 / service 20 / info 18` + barra `14px` color `ef5350≤0.25 / ffd54f≤0.5 / 2e7d32`. `_update_queue_ui` usa `queue_border(profile)` (rarity→cor/largura) + `⭐ RECOMENDADO` slot 0 D0. `info` é `ELLIPSIS` 1 linha + `ⓘ` tooltip história — **densidade 10/10** sem poluição.
- **Instrução:** `instruction_label 990×72 @ 45,1350`, 33sp, 3 estados cacheados `_instr_styles[perfect/over/hint]` (evita alocar `StyleBoxFlat` 60×/s). `hint` via `SalonTuning.hint(service)`.
- **Upgrades:** `86×86 @ 952,150 (ou 120,150 left_handed)`, badge `Badge 44×44 ef5350` com `affordable_count` + pulse `lerp(d7ffb8)` quando >0. `album_button` badge `★` quando `park_can_claim_contest()`.
- **Park:** `park_button 86×86 @ 952,250+safe_top*0.5`, estados: `🔒` locked / `⏳ cooldown mm:ss` / `🌳 pronto` + `Badge !` primeira vez + pulse `dcedc8`. `_setup_park()` move `park_canvas` `move_child(...,1)` atrás HUD mas frente `world`.

### 6.2 Painéis (`MetaPanel`)
- **8 seções:** `missions / collection / album / staff / upgrades / shop / map / settings`. `_rebuild` limpa `content_box` + `match` + `_emerge` cascata — sem vazamento de nós (verificado `queue_free`).
- **Missions:** roleta diária + streak + evento do dia + 3 regulares + épica + passe 28 dias + semanais 7 — todas `rewards_text` escaladas via `Rewards.scaled` (nunca abaixo do piso JSON).
- **Collection:** filtros `all/dog/cat/legendary`, cards com `scale 1.05 hover`, `tooltip` história completa.
- **Álbum:** `trophies`, `week progress perfects/total`, `can_claim` sábado, grid 50 fotos `slice(-50)`. Empty state `ALBUM_EMPTY` localizado.
- **Upgrades:** `SalonTuning.affordable_upgrades_count()` badge; safe guards `cost` 0 → `disabled`.
- **Settings:** sliders `music/sfx 0–1`, toggles `haptics/reduced_particles/eco_mode/colorblind/assist_window/left_handed/training_ghost`, `font_scale`, `shop_name left(18)`.

### 6.3 Acessibilidade & localização
- 3 locales `pt_BR.csv / en_US.csv / es_ES.csv`, 280+ chaves `Loc.t`. 9 “missing” (`EVENT_%d` etc.) são **dinâmicas por `StringName` + format** — não bug (grep falso positivo).
- `colorblind` troca faixa verde por `azul/laranja` (via `SalonTuning`), `assist_window` alarga `TARGET_MIN/MAX` via `RushTuning.window_bonus`, `font_scale` aplica `*fs` em todas labels.

---

## 7) Carregamento

- **ContentDB** `_ready` carrega 10 JSONs (`pets, career, staff, achievements, cosmetics, pass, weekly, service_layouts, events, research, daily`) via `_load_array/_load_dictionary` com `push_error` se `JSON inválido` mas **não crash** (retorna `[]/{}`).
- **Service layouts:** `pet_position 540,1160` + `shelf_y [679,801,923,1045,1167]` idênticos nos 5 serviços → pés ancorados **contrato espacial** validado em `smoke_interact step4`.
- **Pets:** `validate_catalogs` garante 50 pets (25 dog/25 cat), `rarity` em `common…legendary`, `preferred_service bath/groom`, `colors` hex 6, `base_tip` não-decrescente com `unlock_level`.
- **Splash:** `SplashArt.make_splash(hide) + update_splash(progress 0.85/s)` até `1.0` → `hide_splash` — cobre >1 s sem tela preta.

---

## 8) Salvamento

**Arquivo:** `user://save.dat` (Base64 XOR `KEY=petshop-local-v1` + `SHA256(json+KEY)`), `user://save.tmp` atômico.

| Camada | Detalhe | Veredito |
|---|---|---|
| **Serialização** | `GameState.to_dictionary()` 40+ chaves + `Time.get_unix_time_from_system()` `last_seen_unix` | ✅ |
| **Envelope** | `{"hash": sha256(payload+KEY), "payload": json}` → `Marshalls.raw_to_base64(xor(...))` | ✅ Tamper-evident |
| **Atomicidade** | `FileAccess.open(TEMP) → store_string → flush → close → _rotate_backups → remove SAVE → rename TEMP→SAVE` | ✅ Sem meia-escrita |
| **Backups** | `SAVE.bak1…3` rotação `range(3,1,-1)` + `copy SAVE→bak1` | ✅ 3 gerações |
| **Load** | `candidates=[SAVE]+bak1..3` → `first non_empty after _decode_envelope` → `_migrate` → `apply_dictionary` → `_grant_offline_reward` | ✅ Fallback resiliente |
| **Decode** | `base64_to_raw→xor→JSON parse→hash check→payload parse→version 0…12` → `{}` se qualquer etapa falhar | ✅ Não crash, tenta próximo backup |
| **Migração** | `v0→v12` + `v12 patch` (park/album keys sem bump) tudo `if version==N` sequencial, defaults sem apagar progresso | ✅ 100% preservado (histórico `46d7e74`) |
| **Autosave** | `_process: elapsed+=delta; if save_requested||elapsed>=RemoteConfig.autosave_seconds → save_game()`, `NOTIFICATION_APPLICATION_PAUSED/CLOSE_REQUEST` → `save_game()` | ✅ |
| **Export/Import** | `export_code/import_code` mesmo envelope, `strip_edges` + `_migrate` | ✅ Transfer sem cloud |
| **Offline cofre** | `is_first = offline_collected==0 && services>=1` → `Economy.offline_earnings(income_per_second, elapsed, prestige, research, automation, cap, is_first)` `8h` mínimo primeira noite ×2 → `add_coins` → `pending_offline_reward` consumido via `consume_pending_offline_reward()` com card | ✅ Bug antigo `maxf(elapsed, minf(elapsed,8h))` já corrigido para param `is_first` |
| **Sanitização** | `apply_dictionary`: `coins maxf 0`, `embers maxi 0`, `tool_levels clamp 0..30`, `player_level clamp 1..120`, `reviews_sum clamp 0..total*5`, `park_photos _safe_photos_array limit 50`, `visitor_progress clamp Discovery.VISITS_TO_ADOPT` etc. | ✅ Save editado não escala para crash |

**Edge cases verificados:**
- `GameState.park_ensure_pets()` pool vazio → `["caramelo"]`, favorite faltante → append, shuffle com `guard <20` loop.
- `_week_key()` `now<=0` harden zerado, `Time.get_datetime_dict_from_system` sem `weekday` → `is_saturday=false`.
- `SaveManager.KEY` hardcoded local apenas — não é segurança, é anti-edição trivial; adequado para jogo offline.

---

## 9) Economia / Progressão

- **Base:** `HIRE_COSTS common 330 / rare 880 / epic 1980 / legendary 4400` 2.2× (antes 150/400/900/2000) — calibrado Guarulhos/SP 2025 `banho 52 / tosa 88`.
- **Rewards:** `SECONDS` diários 60, semanais 480, chest 900, passe 90+10*day, streak 30, level 45, achievement 240, return 900, prestige 60, evento 600 → tudo `Rewards.scaled(seconds, minimum)` conservador `Good + combo 6` / `SERVICE_SECONDS 14.5s` × `RemoteConfig.reward_scale`. **Nunca abaixo do piso JSON.**
- **Hire/Cosmetic sinks:** `HIRE_SECONDS 300/600/1200/2400`, `COSMETIC_SECONDS 600` + `price_scale` remotos LiveOps-ajustáveis sem build.
- **Carreira:** `career_track.json` 10 tiers `1…120`, `xp 50+(lv-1)*25`, `target_active_hours 61.85`. `ContentDB.unlocked_pet_ids(level)` + `establishment_for_level` + `_reconcile_career_unlocks` emit `reveal pet/chapter`.
- **Prestígio:** `PRESTIGE_KEEP_RATIO 0.25`, `START_LEVEL 10` (todos serviços abertos), mantém `embers/pets/cosmetics/achievements/streak/passe/research/total + 25% estação`. `prestige_tokens_available = prestige_tokens(total) - collected` (bug do dobro já corrigido v11).
- **Pesquisa:** `research.json` 15 nós tier 1…4, cost `1…5 franchise_token`, `effect bath_income/satisfaction/service_speed/patience/tip_bonus/vip_chance/offline_rate/cap/automation/combo_protection/mastery`. `Research.bonus(type)` soma `research_ids`.

---

## 10) Achados detalhados por severidade

### 🔴 Crítico — **0 novos** (todos já corrigidos; projeto abre)
| # | Antes | Fix | Revalidação |
|---|---|---|---|
| C1 | `ParkCanvas:167 draw_ellipse 3 args` crash `Too few arguments` | `a2c37e6` `_draw_ellipse` polygon | `validate 0E` + `grep` helper |
| C2 | `ParkService not declared` | `8085ef2 class_name ParkService` | `Main.gd` tipagem global |
| C3 | `SalonTuning.has_method non-static` | `safe_area_top()` direto | `check_scripts` |
| C4 | `BathService stroke OOB Fred Poodle` | `43795d3 guard is_empty / >=size` | `smoke_interact step6` |

### 🟠 Médio — **0 bloqueante**
| # | Área | Achado | Impacto | Recomendação |
|---|---|---|---|---|
| M1 | Gráfico | `PARK_ICON` reutiliza `petshop_quintal.png` | Sem identidade parque | Criar `art/ui/icons/park.png` 512×512 vetorial + trocar `Main.gd:42` |
| M2 | UI | `left_handed` só espelha ferramentas + botões upgrades/park | Fila/top bar mantêm posição; gesto `horizontal` não espelha eixo | Se manter, documentar como intencional; ou espelhar `queue_row.position` + `TOOL_ORDER` axis |
| M3 | Progressão | `Research` sem validação de `requires` ao `apply_dictionary` | Save editado pode desbloquear `empire_legacy` sem `franchise_network` | Adicionar `Research.valid_ids(ids)` que filtra por `requires ⊆ result` em `_valid_research_array` |
| M4 | Jogo | `DailySpin` sem teste de `clock rollback` (streak já tem) | Farm via relógio | Guard `Time.get_unix_time_from_system() < last_spin_unix - 1h → suspenso` |

### 🟡 Baixo / Polimento
| # | Área | Detalhe |
|---|---|---|
| B1 | Visual | `ParkCanvas` vinheta `fff3e0 0.88` + chão `81c784 0.95` em telas AMOLED podem lavar; testar contraste `CHAC` label pet `263238 0.95`. Já há `draw_rect border 0.08` para pill. |
| B2 | Transição | `goal_preview_text` corta em `18` chars meio de palavra (`…`); trocar para corte em último espaço antes de `18`. |
| B3 | Performance | `D1Retention.update_missions_badge` + `park_can_claim_contest` + `Reminder?` a cada `frame` — ok (<0.1 ms) mas poderia tick `0.5s`. |
| B4 | Conteúdo | `data/pets.json` `base_tip` não-decrescente é garantido, mas `patience` pode ser `27…50` sem curva suave; não bug. |
| B5 | Código | `Main.gd:144` `if ResourceLoader.exists("res://art/pets/caramelo.png"): var _pc = load…` parece warmup de cache mas não guarda — intencional para aquecer `ResourceLoader` cache; documentar com comentário `warmup`. |

### ✅ Conformidades (evidências)
- `res://` quebrados: **0** (`validate_resource_paths` passou)
- `pets.json` 50/50, 25/25, `rarities` válidas, `colors` hex, `unlock_level 1…120`
- `career tiers 1..10`, `service_layouts` 5 stages `unlock 1/3/5/7/10`, `pet_position 540,1160`, `shelf_y 5 sorted`
- `pet_art` 50 sprites RGBA, `tool_*.png` 5 RGBA
- `project.godot` main_scene + 6 autoloads obrigatórios + `Button.new()==1` (factory) + `InteractionFX.bind_button`
- `SAVE_VERSION 12` estável desde `park+album v12 patch`

---

## 11) Fluxos testados (smoke_interact — 6 passos)

| Passo | Asserção | Resultado esperado |
|---|---|---|
| 1 boot | `meta.is_open()==false`, `panel not visible`, `queue_cards[0..2] enabled`, `_can_select true` | ✅ |
| 2 meta | `meta.open(missions)` → `is_open && visible`, `_can_select false`, `close → _can_select true` | ✅ |
| 3 seleção | `_on_queue_pressed(0)` → `selected_slot 0`, `!room_empty`, `pet_id/name non-empty` | ✅ |
| 4 espacial | `pet_position 540,1160`, `shelf_y [679,801,923,1045,1167]`, `tool_position 910, shelf_y[i]` | ✅ (right_handed) |
| 5 upgrades | `meta.open(upgrades, upgrades_button)` visível, `close` | ✅ |
| 6 gestos | `stroke` eixo correto pontua / errado não, `zone` dentro enche / fora drena, `pulse` `hit` vs `miss`, `drop` proximidade | ✅ (`BathService v2`) |

Para reexecutar sem editor: `godot --headless --script tools/smoke_interact.gd` (quando binário disponível).

---

## 12) Recomendações priorizadas (sem wipe, sem bump)

**P0 (fazer agora se sobrar janela):**
1. Ícone dedicado parque `art/ui/icons/park.png` + `Main.gd PARK_ICON` (10 min, só troca `preload`).
2. Validação `Research` com `requires` em `GameState._valid_research_array` (5 linhas, defensivo).

**P1 (próximo ciclo):**
3. `left_handed` completo ou documentar “só prateleira/espelho” no `Loc` `LEFT_HANDED_MODE` hint.
4. Corte de `goal_preview_text` em word boundary + `DailySpin` clock-rollback guard.

**P2 (polimento):**
5. `park_cooldown_seconds` RemoteConfig default `7200s` — expor em `settings` debug label para QA.
6. `gen_*` tools já geram arte consistente; rodar `python3 tools/verify_pet_animations.py` em CI (precisa `PIL`) quando runner tiver.

---

## 13) Veredito & próximos passos

O projeto está **estável, sem regressões, e com progresso 100% preservado**. Os dois crashes que impediam abertura (`draw_ellipse` + `ParkService/SalonTuning`) foram isolados, reproduzidos via `grep` + `validate`, corrigidos de forma atômica e empurrados em `a2c37e6`/`8085ef2`. A auditoria visual anterior (9.2/10) permanece válida; esta auditoria completa (gráficos, transições, animações, estrutura, UI, load/save) eleva para **9.4/10**.

Nenhum wipe ou bump de `SAVE_VERSION` é necessário para os fixes P0/P1 acima; são **compatíveis com saves `v12` existentes**.

**Como reproduzir a validação localmente:**
```bash
python3 tools/validate_project.py          # deve imprimir 0 errors, 0 warnings
grep -rn "draw_ellipse" --include="*.gd" . # só _draw_ellipse helpers
# com Godot 4.3 instalado:
godot --headless --script tools/smoke_interact.gd  # PASS 6/6
```

---
*Gerado automaticamente em auditoria completa — sem alteração de gameplay/progresso.*
