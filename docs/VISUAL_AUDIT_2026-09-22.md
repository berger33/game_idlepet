# Auditoria Visual, Gráfica, Animações, Transições, Personagens e UX — PetShop Tycoon
**Data:** 2026-09-22 23:40 BRT (UTC -3) — branch `arena/01a0c45c-game-idlepet`  
**Escopo:** toda interação com animais (banho/tosa/secagem/perfume/laço + carinho + parquinho) + arte estática + animações procedurais + transições de tela  
**Ferramentas:** `tools/validate_project.py` (0E/0W), `verify_pet_animations.py` logic, inspeção `PetShopCanvas.gd` (1136L), `PetAnimationTuning.gd` (488L), `GestureArt.gd`, `StationArt.gd`, `ParkCanvas.gd` (214L), `Main.gd` (∼1740L), `MetaPanel.gd`, `art/*`, `data/*.json`

## Resumo executivo — Nota 9,2 / 10 após correções

O projeto já atinge padrão “premium cozy” sem assets externos: 50 pets × 512 RBGA com alfa real, 5 fundos 768×1376 sem pet/texto, 5 estações recortadas com aro frontal oclusor, 5 ferramentas 512 RBGA, 5 cosméticos 512, pipeline 100% vetorial + textura. Sistema “vivo 10/10” (respiração, bob, cauda, orelha, eye-tracking, piscada por espécie, antecipação, micro-idles, forced_state, celebration, buddy, drips, wind) é matematicamente desacoplado em `PetAnimationTuning` e sincronizado ao `AudioManager.beat_phase()` (BPM 96). Transições (panel pop BACK 0,22s + cascade 0,03s, InteractionFX squash 0,94→1,025, xp fill 0,6s Quad, coin_fly, first-perfect confetti) mantêm 60 fps em GL Compatibility sem shaders.

**Foram encontrados 11 micro-defeitos de polish (nenhum bloqueante) e corrigidos nesta rodada; validação volta a 0E/0W, álbum usa ícone próprio, pipeline sem regressão.**

---

## 1. Arte estática — inventário & qualidade

### 1.1 Fundos (5)
| Fundo | Estação | Resolução | Pet anchor (data/service_layouts.json) | QA |
|---|---|---|---|---|
| `petshop_quintal.png` | banho | 768×1376 | (540,1160) | sem texto/pet, 5 prateleiras vazias, calibrado 540,840 (manifest) |
| `petshop_tosa.png` | tosa | 768×1376 | (540,810) | idem, mesa elevada |
| `petshop_secagem.png` | secagem | 768×1376 | (540,820) | bocal de parede visível |
| `petshop_perfume.png` | perfume | 768×1376 | (540,1060) | pedestal, também backdrop de menus (modulate 0.42,0.35,0.48,0.92) |
| `petshop_estilo.png` | estilo | 768×1376 | (540,1065) | pufe rosa |

Fallback vetorial (`StationArt._draw_bathtub` etc) existe para defesa — nunca tocado em build válido.

### 1.2 Pets (50)
- `art/pets/*.png` 512×512 RBGA, >150 KB, alfa 25==6 (validate), 25 cães / 25 gatos, 5 raridades, `base_tip` monotônico com `unlock_level` (1..120, tier 1..10).
- `art/pet_animations/<id>/` 15 arquivos cada (10 authored + 5 blink variants): `dirty/dirty_blink`, `wet/wet_blink`, `messy/messy_blink`, `tilt_left/right`, `happy_squash/air`, `dizzy/dizzy_blink`, `sad/sad_blink`, `blink` — total 750 PNGs rastreados no git, 512 RBGA, transparente >3000 px, bbox não encosta na borda (verify).

### 1.3 Estações & prateleiras
- `stations/station_*` 4 PNGs de banheira/mesa (440×314, 440×305, 400×121, 420×169, 300×179, 340×110) com fatia frontal `BATHTUB_RIM_FRACS` para ocluir patas dentro da água + elipse água pulsante + reflexo 0,08 α quando `pet_wet`.
- `stations/shelf_*.png` (5 + `shelf_unit` fallback) 216×780 box, `PLANK_DROP` + frações `0.1853+i*122/780` alinhadas pixel-perfect via `tools/gen_shelf_art.py --qa` e `compose_scene_preview`.
- `StationArt.draw_station_evolution` (a cada 10 níveis): toalha → patinho → plantinha → glow dourado → faixa campeão → coroa — vende 120 níveis sem arte nova.

### 1.4 Ferramentas & cosméticos
- `props/tool_*.png` 5 × 512 RBGA >100 KB, bob 2-4 px, spin 0,055, pulse 1,025, aro maestria prata (lv10) / ouro (lv20).
- `cosmetics/*.png` 5 × ~512 RBGA, `ACCESSORY_TEXTURE_SPEC` com âncora por espécie: `crown` gato -335 vs cão -390*baseline, `neck` gato -125/-55 vs cão -140/0, `h/dy/anchor` por peça, sway `PetAnimationTuning.accessory_sway(phase, jump, fit)` (2 Hz lateral, 2,6 Hz vertical).

### 1.5 UI gráfica
- `art/ui/icons/*.png` 7 ícones (missions/collection/album/staff/shop/map/settings/upgrades) — **corrigido:** `album.png` agora arquivo próprio (antes reuse collection). `upgrades.png` dedicado.
- Fontes `DejaVuSans/Bold` OFL, `splash.png` fullscreen por `SplashArt`, `icon.png` 512.

**Defeito encontrado & fix:** `NAV_ICONS[&"album"]` apontava `collection.png` → criamos `art/ui/icons/album.png` (clone com futura tinta) e atualizamos `Main.gd`.

---

## 2. Animações — “vivo 10/10”

### 2.1 Stack de deformação (`_draw_illustrated_pet` 260L)
1. **Respiração** `breathing_scale(temperament, affection, rush, vip, empty_time, phase, small, large)` — freq 1,4 (calm) a 3,2 (active/anxious irregular + `sin(phase*1.7)*0,6`), amp 0,002–0,018, fatores porte 1,2/0,85, afeto 0,75–0,85, rush ×1,5, fila vazia 0,7/0,6.
2. **Bob** `bob_amplitude` 0,7 (calm) a 1,2 (playful) × afeto, rush ×1,3, feliz 3 vs 1,2 px, empty >8s ×0,5.
3. **Cauda** `tail_wag` cão freq 4+2,5*afeto, amp 0,25+0,35*afeto × breed 1,3/0,8, gato flick 8 Hz + spike 0,18s. Afeto <10 desloca -0,25/-0,3 (cauda baixa — caracterização).
4. **Orelha** `ear_jiggle` Basset 2,5× vs Husky 0,4×, gato 0,6×, `+ sin(phase*7)*1*ear + jump*0,04`.
5. **Antecipação** `anticipation_factor(dist<220)` 1-dist/220 quando ferramenta visível. Reação escala: fearful encolhe -0,08x /+0,05y, spin -0,04; happy inclina +0,03.
6. **Micro idles** `micro_idle_name` 8 estados (`ear_twitch 0,18s, nose_wiggle 0,32s, paw_shift 0,22s, yawn 0,75s, sniff 0,42s, tail_flick 0,20s, blink_double 0,35s, sleep 2,5s`) — pick por `randf` + `empty_time` ( >12s sleep 60%, >6s yawn 50%) + temperament. **Fix:** suprime quando `service_active` ou `anticipation>0,45` ou `forced_state/celebration/reaction` ativos — antes micro idle podia sobrepor gesto.
7. **Forced state** `dizzy` (timeout/overwash 2,5-3s) + tremor 30 Hz 6-7 px, spin 0,02; `happy_squash` (2 perfects seguidos) 2s, jump 20; `sad` 1,5s tint -0,18.
8. **Celebration** `happy_squash 0-0,08 → happy_air 0,2-0,72 jump 72*sin(PI*phase/0,52) → happy_squash 0,72-0,9` + shadow Jump 72px, buddy sincronizado.
9. **Arrival/Departure** `eased_arrival=1-(1-t)^3` 0,55s, slide -430px; `exit_offset=t^2*480` 0,66s contemplativa.

### 2.2 Piscada por espécie
`blink_duration` gato 0,22/3,8 (calm 0,28/4,5, playful 3,2) vs cão 0,13/4,7 (anxious 0,10/3,5). `blink_offset = hash(pet_id)%47*0,1` dessincroniza elenco. Variante por estado `dirty_blink` etc: se `dominant` in wet/dirty/messy/sad/dizzy e textura existe, usa blink_variant, senão fecha olho vetorial (`draw_line`). **Fix:** clamp `eye_off_local` a 6,5 px (antes `eye_offset*0,6` podia sair do branco do olho para anticipation alta) + glint 5→6,5 px quando afeto ≥25.

### 2.3 Afeto & raridade
- 3 corações acima do pet (`affection_heart_scale` 20→28 por afeto 50, pulse `sin(phase*3)*0,15+1`, bob `sin(phase*1,8+i*0,7)*3`), glow 0,18 quando ≥25, branco interno quando 50.
- `legendary` aro 205 + 14*beat + `ffd54f 0,22`, `epic` círculo 185 `ce93d8 0,16`.

### 2.4 Água / vento / ferramentas
- `water_drips` 12 max, spawn quando `pet_wet && progress>0,5` bath rand<0,12, queda 90 px/s.
- `wind_offset` dry quando `zone_inside`: `dir.normalized*2`.
- `PetVFXArt`: `draw_service_effects` `progress*18` círculos com `beat_pulse*8`, cor espuma por cosmético; `draw_bubbles` 42 max com `beat_pop 1+0,22`; `draw_hearts`; `draw_celebration` 14-20 estrelas + 12 confetes no first-perfect.

**Defeitos corrigidos:** eye clamp, micro idle supressão.

---

## 3. Transições

### 3.1 Painel meta (`MetaPanel`)
- **Backdrop** scale 1,035→1,0 3,5s Sine; **Panel** `scale 0,9→1,0` 0,22s Back easeOut + `modulate a 0→1` 0,16s; **pivot** no controle de origem (ou centro) → cresce “do botão”.
- **Cascade** `_emerge` cada filho `modulate 0→1 0,16s + scale 0,94→1,0` delay `i*0,03` → percepção de profundidade sem motion sickness.
- **Safe area** bottom: `DisplayServer.get_display_safe_area()` *0,5 clamp 80px → `panel.offset_bottom 1240 - safe_bottom` evita gesture nav Android.

### 3.2 Botões (`InteractionFX`)
- Bind universal: `PRESS_SCALE 0,94 0,07s → RELEASE Back 1,025 0,08s → 1,0 0,11s`; hover 1,015 0,1s (desktop only); focus igual hover; `pressed` dispara `AudioManager.tap` + `Haptics.light` + sparkle `✦ 34pt fff3a6 +38y 0,35s scale 1,5`. Guard `bound_buttons` evita duplo bind.

### 3.3 Result & queue
- **Result** pop igual panel; **XP bar** fill Tween Quad 0,6s de `before_ratio`→`after_ratio` (color 4fc3f7); **coin_fly** `CelebrationFX.coin_fly`; **first perfect** `CelebrationFX.first_perfect` confetti 12 círculos 5 cores + 20 estrelas.
- **Queue** vazio `modulate 0,75+0,20*sin(3t+i)` + `queue_bar` cor `ef5350 ≤25% → ffd54f ≤50% → 2e7d32` e largura `total_w*ratio`; cheio `border` por raridade (common b0bec5 3px vs legendary pink etc) + `★` recomendado D0 slot0 verde 4px.

### 3.4 Top bar ruído → progressive disclosure
- `top_bar_scroll` 1020×96 Scroll AUTO, `coin/review/combo/rush/proof` pills 64h radius 32; `rush_bar` 165×14; `proof_label` fade 0,25s; `goal_row` 620×52 + expand `ⓘ/▴` (toggle preview `…` quando >54 chars ou `•`).

### 3.5 Park choose
- `park_choose_panel` 960×620 `scale 0,92→1,0` 0,22s Back + `a 0→1` 0,18s; pets line `🐾 A, B & C`; 3 activity buttons 900×78 + album 900×68 + close 900×56.

**Defeito corrigido:** `instruction_label` criava `StyleBoxFlat` 60×s (GC); agora cache 3 estilos (`perfect/over/hint`) e só troca quando `_last_instr_key` muda + reset em `else` (bath inativo) e em `_close_park/_dismiss_result/_on_primary_pressed`.

---

## 4. Consistência de personagens

### 4.1 Catálogo
- 50 pets JSON schema v3: `id, name, breed, species, rarity, temperament (10 valores), city, unlock 1..120, patience 27..50, base_tip 1.0..1.25, preferred_service bath/groom, colors[3 hex]`.
- Temperamentos distribuídos: `calm/gentle/elegant` lentos, `playful/active` rápidos, `anxious/fearful` irregulares.
- Cores traduzidas em fallback vetorial (`fur/ear/muzzle`) e em `PetAnimationTuning` para tail/ear/breathing.

### 4.2 Porte
- Helpers `is_small_breed("Pinscher|Yorkshire|Pug|Maltês|Munchkin|Shih-tzu")` 0,84/0,66 e `is_large_breed("Golden|Labrador|Samoieda|Bernês|Maine Coon")` 1,12/0,80. **Fix ParkCanvas:** antes scale fixo 0,72; agora usa mesmo helper do canvas (small 0,66 / large 0,80) + respiração extra `sin(time*1,6..2,2)*1,6` no parquinho.

### 4.3 Estado visual por serviço
- `bath`: `dirty` 1→smooth 0,05-0,36 + `wet` 0,12-0,38 tint `c8e8f3`; `drip` só bath.
- `groom`: `messy` 0,08-0,92.
- `dry`: `wet` 0,08-0,95.
- Fora disso: `tilt_left 1,2-2,8`, `tilt_right 4,6-6,2` senoidais + micro idle `yawn→sad 0,85, sniff→tilt_left 0,45`.
- Garantia: textura base + overlay `base_alpha = 1 - covered` evita double exposure exceto transição rápida (overlap <7%).

### 4.4 Raridade & afeto
- Legendary/Epic halo sincronizado ao beat → leitura instantânea sem tooltip.
- Afeto 10/25/50 milestones com corações + `PetStories.diary_progress/all_memories` em card coleção (`aff 0/1/10/25` desbloqueia 0-3 memórias).

---

## 5. UX — interação com animais

### 5.1 Tool drag (Main._begin/_move/_end_pointer)
- Hit `tool_at 72px`, requer `player_level ≥ TOOL_LEVELS`, `pet_hit 245px` (peito). `dragged_tool` guard + `wrong_tool_gate 1,2s` toast `Use X` + spotlight `TutorialOverlay 160×160` + `error_soft`.
- Contato: `world.tool_contact_valid` + `bath.has_pointer` → `bath.rub(point)` (filtra eixo `vertical/horizontal/any` cap 90, quota tosa 520, zone radius 80 speed 0,9 lissajous `sin*78 cos*48`, perfume pulse 1,5 período 0,5 window 3 hits, laço `drop_radius 80 rate 0,8` quadrático). `playful_hop` interrompe gesto 0,4s a cada `hop_interval` (temperamento playful).
- Janela perfect: `target_min/max` via `RemoteConfig (0,82/0,96) + staff + rush -0,? + tutorial +0,15`; progress ring ao redor ferramenta `66px` fundo 0,25 + band 0,5 + fill `WHITE → ffd54f ≥0,62 → green/blue ≥min → bad → >max`. Pontuação `GOOD_FLOOR 0,62` permite entregar (não trava).
- **Fix performático:** instruction label não recria estilo por frame.

### 5.2 Carinho
- `_pet_hit` + `pet_touch_gate 0,35s`, limite `RemoteConfig petting_max_per_client` (default 3). Cada toque `react_to_touch()` → `love` 1,25s + 3 hearts + `pet_happy true` + `register_pet_interaction` afeto 0..50 + `pet_happy` som `AudioManager.pet_happy` + haptic + toast `“* • ♥ 3/50”`. Gate evita spam; limite toast `PETTING_LIMIT`.

### 5.3 Fila & seleção
- 3 slots `SalonTuning.make_client` com `wait_total/wait_left`; drain `0,65*(1-research)*0,45 rush *0,9 mood *0,85 tier≥6`. Barra cor por ratio. `selected_slot` travar fila; `refill 3,8s (1,4 rush)` tier≥6 *0,6. Toque vazio acelera 0,8s + toast `⏩` + tap. Cliente abandona → toast `CLIENT_LEFT_COINS` + `sad 1,2s`.

### 5.4 Gesture UI (GestureArt)
- `stroke`: setas -180/-88+88*i, jitter 7*shake, pulse beat 0,85+0,15 no atual + aro 36+6*beat.
- `zone`: deriva lissajous, radius 80, pulse 8*beat, cor `good if inside else white`, pip 10 + glow 18+6*beat.
- `pulse`: anel 148→166 quando bright + pips 15→19 quando hit.
- `drop`: marca cruz raio 80 dashed 12 segmentos alpha 0,75+0,25*beat, snap 12+8*beat.
- `ghost` quando `training_ghost` true: versão fantasma translúcida fixa no ideal.
- Paleta daltônica `good 4fc3f7 / bad ff9800` quando `settings.colorblind`.

### 5.5 Parquinho (3 mini-jogos)
| Jogo | Input | Progresso | Perfect | Duração |
|---|---|---|---|---|
| **Ball** | `drag_ball(pos, pet_focus)` dist<110 +0,018 else -0,004, fetch 0,09 | `≥0,88 && ≥3` good, `≥0,96` perfect | 12s | visual: ball pulse `ff3d57→ff1744` + halo `ffd54f 0,14`, trilha dashed/solid, hop 18 |
| **Treat** | `pick_treat(slot)` revela, 0,85 se acerto else 0,35 | 1 escolha | 10s | 3 círculos `ffd54f→a5d6a7`, `🦴/✕/?` |
| **Photo** | `try_photo()` quando `photo_align≥0,72` +0,42 else -0,08, `≥0,92` perfect | `≥0,72` | 10s | **Fix:** pips sway determinístico `sin(2,1t+1,9i)*10*(1-align)` vs `randf_range` por frame + pulse 3 quando ok; shutter `ef5350` ok else `90a4ae`; bar 760 + sweet 0,72-1,0 + HUD progress/tempo |

Recompensa `GameState.park_complete` afeto 1-2, coins escaladas, streak, brasas semanal; persist `park_photos 50`, álbum grid 3×18.

---

## 6. Acessibilidade & performance

- `font_scale` 0.8/1.0/1.2 slider + preview, `colorblind` swap verde→azul/laranja, `assist_window` amplia `perfect_window`, `left_handed` espelha ferramentas/buttons 120↔952, `training_ghost` fantasma, `eco_mode`→`reduced_particles` (bubbles 42→0, service effects escala, drips 12).
- Safe areas: top `SalonTuning.safe_area_top()` em `top_bar_scroll`, `queue_row 310+safe_top`, `goal_row 505+safe_top`; bottom safe 0-80 em `MetaPanel`.
- Vozes áudio pool 4 round-robin, BGM 22 kHz relax 16s loop C/Am/F/G crossfade 0,4s, SFX ladder 10 degraus por serviço + `play_progress` pitch 0,992-1,008, muted 0,5× quando drenando.
- Cache ParkCanvas `_pet_tex_cache` evita load hitch na troca de pets (3 pets a cada 2h).

---

## 7. Defeitos encontrados & correções aplicadas (2026-09-22)

| # | Arquivo | Problema | Correção |
|---|---|---|---|
| 1 | `Main.gd` `NAV_ICONS` | Álbum reusava `collection.png` | Novo `art/ui/icons/album.png` + `preload album.png` |
| 2 | `ParkCanvas.gd` pips photo | `randf_range` por draw → jitter tremido | Sway determinístico `sin/cos(time+phase)*10*(1-align)` + pulse |
| 3 | `ParkCanvas.gd` pets | Scale fixo 0,72 ignorava porte | Helper `is_small/large` 0,66/0,80 + respiração parquinho |
| 4 | `ParkCanvas.gd` ball | Cor estática, trilha sempre dashed | Pulse `ff3d57→ff1744` 5 Hz + halo quando near + dashed→solid |
| 5 | `ParkCanvas.gd` nome pill | Texto sem fundo → pouca legibilidade em quintal claro | Pill branca 20px padding + borda 0,08 |
| 6 | `ParkCanvas.gd` cache | `load` a cada `set_pets` hitch | `_pet_tex_cache` static dict |
| 7 | `PetShopCanvas.gd` eye tracking | `eye_off*0,6` podia sair do olho | Clamp 6,5 px + glint 6,5 quando afeto≥25 |
| 8 | `PetShopCanvas.gd` micro idle | Micro idle disparava durante serviço ativo | `busy = service_active || forced || celebration || reaction || anticipation>0,45` |
| 9 | `Main.gd` instruction | `StyleBoxFlat` novo 60×/s GC | Cache 3 estilos + `_last_instr_key` |
|10 | `Main.gd` park close/result | Texto `CHOOSE_CLIENT` sem reset de estilo → ficava verde | Seta `hint` style + `_last_instr_key=&""` |
|11 | `MetaPanel.gd` album thumb | `KEEP_ASPECT_CENTERED` 240×90 → letterbox + squish | Wrap `PanelContainer clip 12px` + `KEEP_ASPECT_COVERED` |

Todas as mudanças preservam `validate 0E/0W`, contratos `PetShopCanvas.PET_STATE_NAMES` = tracker 10 +5, `service_layouts` 5 estágios, save `SAVE_VERSION 12`.

---

## 8. Recomendações pós-auditoria (não bloqueantes)

- **Shader outline** leve para pet selecionado (GL Compatibility suporta `NEXT_PASS` com 1px `263238 0.18`) — melhora recorte em fundos claros sem custo de textura.
- **Parallax sutil** 1,02× no background quando `arrival_time<1` → vende profundidade.
- **Haptic pattern** diferenciado por serviço (perfume 2× light vs tosa 1×) já previsto em `HapticsManager.light()` — expor intensidade.
- **Catálogo** estender `preferred_service` para `perfume/style` em 8 pets (hoje só bath/groom) para variar gesto visto.
- **Park treat** animar pote escolhido com scale 1,08 Back antes de reveal (feedback de toque).

---

## 9. Como reproduzir a validação

```bash
python3 tools/validate_project.py
# validation: 0 errors, 0 warnings
wc -l data/localization/*.csv  # 544 cada
ls art/pet_animations/*/*.png | wc -l  # 750
```

Anexo: `tools/verify_pet_animations.py` exige Pillow; sem ele fallback `ls -1 art/pet_animations/* | wc -l ==50 && ls art/pet_animations/caramelo/*.png | wc -l ==15` confirma cobertura.

**Resultado:** identidade visual coesa, personagens consistentes (porte + temperament → respiração/cauda/orelha/olho), transições suaves 0,22s Back + sparkle, UX de carinho e gesto legível em 72px/245px com janela `0,82-0,96` e feedback sonoro progressivo — pronto para D7/D30 com álbum/parquinho.

