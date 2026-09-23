# Plano Executivo — Animações Vivas 10/10
**Data:** 2026-09-21
**Branch:** arena/01a0c221-game-idlepet
**Origem:** Auditoria `docs/AUDITORIA_ANIMACOES_PETS.md` (8/10 → 10/10)
**Objetivo:** Fazer cada pet parecer um animal real, consciente e afetivo, reagindo ao jogador de forma natural. Retenção D1/D7/D30 via vínculo emocional.

---

## 1. Estado Atual (resumo auditoria)

- **Arte:** 50 pets ×10 estados autorais +5 blink variants =750 PNGs 172MB, qa_passed, integrado.
- **Runtime:** `PetShopCanvas.gd` 1101 linhas — breathing 2.2Hz, bob 5Hz, tilt 8s cycle, blink global 4.7s/0.13s com offset hash, squash/stretch felicidade 72px jump, dizzy vibrate 32Hz, sad darkening, hearts 3, bubbles 42 cap, tool shelf, buddy estático, sombra fixa.
- **Gaps críticos:** sem eye-tracking, cauda genérica cão=gato, orelha sem inércia, respiração igual todos temperamentos, idle só tilt, sem antecipação (<200px), afeto não muda comportamento, buddy morto, sombra não squash, sem física pelo/vento, acessório rígido, piscada gato = cão, rush/VIP não afeta pet, sem yawn/sono fila vazia.

## 2. Princípios 10/10

- **12 princípios animação:** squash/stretch já ok, antecipação, secondary motion (orelha/cauda), follow-through, exaggeration por porte, timing por temperamento.
- **Game feel:** olho segue ferramenta (consciência), respiração por temperamento (vida), micro-idles 3-7s (não robótico), reação a proximidade (inteligência), buddy sincronizado (social), sombra reativa (peso), afeto mudando personalidade (vínculo).
- **Restrições:** Main<1100, GameState<38, textura budget pode crescer (user autorizou 1000+ imagens), mas P0-P1 sem novas PNGs via procedural.

## 3. Arquitetura — Como manter limites

**Novo helper estático `PetAnimationTuning.gd` (mesmo padrão `SalonTuning`):**
```gdscript
class_name PetAnimationTuning
static func breathing(temperament, affection, rush, vip, empty_time, phase) -> Vector2
static func tail_wag(species, temperament, affection, happy, celebration, phase) -> float
static func eye_offset(target, body_center, temperament, anticipation) -> Vector2
static func ear_jiggle(species, breed_name, phase, jump_height, celebration) -> Vector2
static func anticipation_factor(tool_pos, body_center, service_active) -> float
static func micro_idle_name(idle_phase, empty_time, temperament) -> StringName
static func blink_duration(species, temperament) -> Vector2 # duration, interval
static func shadow_scale(reaction_scale, jump_height, happy) -> Vector2
static func accessory_sway(phase, jump_height, fit) -> Vector2
```

**PetShopCanvas.gd refactoring:**
- Extrair breathing, tail, blink logic para Tuning.
- Novas vars: eye_offset, ear_offset, tail_phase, micro_idle_timer, micro_idle_state, micro_idle_time, anticipation, empty_room_time, look_at_target, vip_active, buddy_reaction_time, buddy_celebration, buddy_jump_height, water_drips, wind_offset.
- _process atualiza todos timers, queue_redraw.
- _draw_pet consome Tuning, aplica eye highlight, ear jiggle, tail como transform extra, micro-idle overlay.
- Linha alvo: reduzir de 1101 para <1000 movendo VFX bubble/heart para helper se necessário.

**StationArt.gd upgrade:**
- draw_station recebe jump_height, reaction_scale, celebration → sombra reativa scale.
- draw_station_foreground adiciona reflexo água (alpha 0.08) + água translúcida pulsante.

**PetCosmeticsArt.gd upgrade:**
- draw_pet_accessories recebe sway = PetAnimationTuning.accessory_sway() → bandana flutter 2-3px.

**GestureArt.gd upgrade:**
- draw_buddy recebe buddy_celebration, buddy_jump, look_at_target → buddy vivo com salto sincronizado, olha main pet, espuminha animada.

**Main.gd integração:**
- Passar vip_active para canvas quando current_vip != "", rush_active já existe, tool_position já existe.
- Passar empty_room_time (tempo sem cliente).
- Ao perfect, set buddy_celebration.

## 4. Roadmap P0-P2 detalhado

### P0 — VIDA EM 3 SEGUNDOS (obrigatório 10/10 primeira impressão)

**P0-1 Eye Tracking — Olhar segue ferramenta/toque**
- Vars: eye_offset Vector2, look_at_target Vector2
- Em _process: se service_active && tool_visible → target=tool_position senão pet_focus() + random look (20% olha câmera, 10% olha buddy).
- Calcular: dir=(target-body_center).normalized(), dist clamped 0-6px * temperament factor (fearful *0.5 evita contato, curious *1.4 fixa).
- Render: após desenhar textura base, desenhar 2 círculos highlight branco com offset: eye_pos + eye_offset (pos olhos estimada: body_center + Vector2(-52,-22) e +52). Pupila preta 17px já no sprite, mas highlight dá sensação movimento.
- Para sprites raster, adicionar camada eye_glint procedural: draw_circle(eye_pos+eye_offset, 5, white 0.9) + small black pupil offset 2px.

**P0-2 Respiração & Bob por Temperamento + Afeto + Rush + Porte**
- Tuning.breathing:
  - calm/gentle: freq 1.4, amp x 0.002/y 0.008, bob 1.0Hz
  - happy/playful: freq 2.2, amp x 0.004/y 0.012, bob 5Hz (atual)
  - active/irritated: freq 3.2, amp x 0.006/y 0.018 + jitter sin*0.5, bob 6.5Hz
  - anxious/fearful: freq 2.2+sin(phase*1.7)*0.6 irregular, amp tremida 0.003+rand*0.002, bob 4Hz+ jitter 2px
  - affection 25+: freq -15%, amp -20% relaxado
  - affection 50: freq -25%, bob suave 0.8
  - rush: freq *1.5, bob *1.3
  - small breed: freq *1.2, large *0.85
  - empty_time>8s: freq *0.7 (quase dormindo)

**P0-3 Cauda com Personalidade**
- Tuning.tail_wag:
  - dog: wag = sin(phase * (4+affection/25) * (1.5 se happy)) * (0.25+affection/100) * breed_factor (large 0.8 lento pesado, small 1.3 rápido)
  - cat: flick = sin(phase*8)*0.15 + spike random a cada 2-4s (0.6 rad) + happy → slow sway 0.3Hz
  - Afeto: 0-9 tail baixo (wag -0.3 rad offset), 50 tail alto alegre
  - Celebration: wag *2.5 + jump
- Render: desenhar cauda procedural por cima da textura? Ou como offset do sprite? Para P0, aplicar como rotacao extra do pet via spin + tail_phase usado em _draw_illustrated_pet: adicionar tail_spin = tail_wag, se species cat desenhar arc com tail_spin, senão já tem fallback vetorial mas para textura usar overlay? Solução: para pets ilustrados, cauda já está no sprite, mas podemos desenhar uma cauda extra vetorial sutil por cima quando happy (brilho). Ou simplesmente animar foot_anchor.x com tail_wag*2 para dar sensação abano corpo todo.

**P0-4 Orelha Secondary Motion (inércia)**
- Tuning.ear_jiggle: ear_offset_y = sin(phase*5 + jump_height/20)* (2 + ear_factor) onde ear_factor: Basset/Beagle/Dachshund=2.5 (orelha grande balança), Poodle/Samoieda=1.8 (pelo), Husky/Akita/Corgi/Spitz=0.4 (orelha em pé rígida), cat=0.6.
- Aplicar: foot_anchor.y += ear_offset_y*0.3, reaction_scale.y += ear_offset_y*0.002, e em happy_air adicionar ear_jiggle extra 4px.

**P0-5 Micro Idles 3-7s (sem PNG novo)**
- Vars: micro_idle_timer 3-7s random, micro_idle_state &"", micro_idle_time
- Em _process: decrementa timer, quando <=0 escolhe micro_idle_name(): ear_twitch (0.15s scale x 1.08), nose_wiggle (0.3s tint rosa nariz + circle), paw_shift (0.2s foot_anchor.x +=4), yawn (0.6s reuse sad + scale y 1.12), sniff (0.4s head tilt + nose circle), tail_flick (0.2s tail wag spike), blink_double (0.3s dois blinks rápidos).
- Implementar como forced_state temporário com overlay_alpha baixo (0.6) para não interromper serviço.
- Quando room_empty >8s, frequência micro idle *2 (pet entediado).

### P1 — INTERATIVIDADE E VÍNCULO

**P1-6 Antecipação de Ferramenta (<220px)**
- anticipation = 1 - dist/220 quando active_tool == required && tool_visible
- fearful/anxious: reaction_scale (1-0.08*ant, 1+0.05*ant) encolhe, spin -0.04*ant afasta, eye_offset oposto ferramenta.
- playful/happy: spin +0.03*ant inclina para ferramenta, jump_height = ant*8
- focused reaction_kind com pupila dilatada (highlight maior 7px)
- Mostrar bolha de pensamento "?" ou "!" quando anticipation>0.7 (draw_string pequeno).

**P1-7 Buddy Vivo**
- Novas vars em PetShopCanvas: buddy_reaction_time, buddy_celebration, buddy_jump_height, buddy_eye_offset
- Em _process: buddy_celebration countdown, buddy_jump = sin(PI*phase)*40 quando celebration
- Em GestureArt.draw_buddy(shop):
  - Aplicar breathing e jump do main com delay 0.1s
  - Eye tracking buddy olha main pet: dir = (main_body - buddy_feet).normalized()*4px
  - Desenhar eye highlight buddy
  - Quando main celebration>0, buddy também salta: top -= buddy_jump
  - Espuminha animada: circle radius 74+sin(phase*3)*4
  - "+40%" pulsa com beat

**P1-8 Afeto Muda Comportamento**
- 0-9: desconfiado, eye evita, tail baixo, bob nervoso
- 10-24: coração maior, bob suave, permite yawn perto jogador
- 25-49: dorme na banheira idle longo (happy_squash alpha 0.7 + Zzz), segue tool com olhos, tail wag médio
- 50: confete especial carinho, celebration extra, coroa flores auto (se não tem acessório)
- _draw_affection_hearts: escala por threshold, glow por beat, pulse.

**P1-9 Sombra Reativa + Reflexo Água**
- StationArt.draw_station(shop, jump_height, reaction_scale, celebration):
  - sombra ellipse rx = 216 * shadow_scale.x, ry = 26 * shadow_scale.y
  - shadow_scale = Tuning.shadow_scale(reaction_scale, jump_height, happy)
  - happy_squash: sombra larga curta (rx*1.15, ry*0.7)
  - happy_air: sombra pequena clara (rx*0.6, ry*0.5, alpha 0.08)
- Reflexo: em draw_station_foreground, desenhar textura pet refletida vertical flip alpha 0.08 abaixo rim_y, só quando wet.

**P1-10 Física Pelo/Vento**
- Secagem: wind_offset = (zone_target - body_center).normalized()*2*inside, aplicar foot_anchor.x += wind_offset.x
- Pelo: quando dry && service_active, desenhar linhas vento mais intensas e aplicar tint clara no pet
- Banho: drip particles quando wet && progress>0.5: spawn gota caindo draw_circle com life curta (nova array water_drips)

### P2 — JUICE E POLISH (10/10 premium)

**P2-11 Acessório Flutter**
- Tuning.accessory_sway: sway = sin(phase*2 + jump_height/10)*2*fit
- Em PetCosmeticsArt.draw_pet_accessories, adicionar sway ao anchor, bandana balança.

**P2-12 Piscada Felina**
- Tuning.blink_duration(species, temperament): cat duration 0.22s vs dog 0.13s, interval 3.5s vs 4.7s
- Cat blink fenda: desenhar linha horizontal em vez de círculo? Mas textura blink já tem fenda se arte contempla. Ajustar pulse curve: cat sin com plateau 0.05s fechado.

**P2-13 Rush e VIP Reagem no Pet**
- rush_active: breathing freq *1.5, eye_offset maior, orelha em pé scale y 1.05, pupila dilatada
- vip_active: novo var em canvas, setado por Main quando current_vip != "", pet mais atento tilt frequente, brilho olhos, aura dourada extra.

**P2-14 Yawn e Sono Fila Vazia**
- empty_room_time tracking em _process quando room_empty
- >6s: micro_idle força yawn: overlay sad + scale y 1.15 por 0.8s + "Zzz" label
- >12s: deita reuse dizzy + tint escuro + sombra maior + Zzz particles

**P2-15 Som Sincronizado (se AudioManager tem beat)**
- breathing sync beat quando quintal BGM relax: breathe_y += sin(beat_phase*TAU)*0.005
- Latido/miau curto em react_to_touch com pitch por porte (small pitch 1.2, large 0.8) via AudioManager.play_sfx se existir.

**P2-16 Novos Estados Autorais (opcional, 250-500 PNGs)**
- Se budget permitir, gerar: yawn (boca aberta, olhos fechados), sniff (nariz franzido), paw_lift (pata levantada), ear_twitch (orelha torta), sleep (deitado, Zzz)
- Cada 50 pets ×5 =250 imagens, +5 blink variants =250, total 500. Pipeline existente em tools/verify_pet_animations.py
- Gerar via generate_image tool com prompt por espécie/raça.

## 5. Tasks Ordenadas

1. Criar `core/gameplay/PetAnimationTuning.gd` com todos statics P0-P2
2. Refatorar `PetShopCanvas.gd`: adicionar vars, mover lógica para Tuning, implementar eye tracking highlight, tail wag via body shift, ear jiggle, micro idles, anticipation, water drips, empty tracking
3. Upgrade `StationArt.gd`: sombra reativa + reflexo
4. Upgrade `PetCosmeticsArt.gd`: sway
5. Upgrade `GestureArt.gd`: buddy vivo
6. Integrar `Main.gd`: passar vip_active, empty_room_time, buddy_celebration
7. (Opcional) Gerar novos estados yawn/sniff/sleep via generate_image (se tempo)
8. Teste manual + verify_pet_animations.py + headless check
9. Commit final + push

## 6. Critérios Aceitação 10/10

- Pet olha ferramenta quando <220px e segue toque (eye_offset visível)
- Respiração diferente por temperamento (calm lento, active rápido) testável via shake_phase
- Cauda cão abana, gato flick, intensidade cresce com afeto 0→50
- Orelha balança no pulo, Basset balança mais que Husky
- Micro idle a cada 3-7s quando ocioso (ear_twitch, nose_wiggle, paw_shift, yawn)
- Antecipação: pet encolhe se medroso quando ferramenta perto, inclina se feliz
- Buddy salta junto no perfect, olha main pet
- Afeto 50 pet dorme na banheira e segue cursor
- Sombra esmaga no squash, encolhe no ar
- Acessório balança com bob
- Piscada gato mais lenta 0.22s vs cão 0.13s
- Rush faz pet alerta (respiração rápida)
- Fila vazia >6s boceja, >12s dorme com Zzz
- Main<1100, GameState<38, sem regressão build
- Todos 750 PNGs ainda carregam, fallback seguro

## 7. Riscos

- Performance: eye highlight 2 draw_circle extra ok, micro idle timer ok, manter bubbles cap 42
- Mirror tilt: raças assimétricas já documentadas, P2 opcional gerar ambos tilts para 5 raças
- Godot parser: draw_set_transform já usado, manter compat 4.7

## 8. Estimativa

- P0: 3h
- P1: 4h
- P2: 2h
- Total 9h, entrega incremental com commits

---
**Assinado:** Agent Mode — execução imediata após push deste plano.
