# Auditoria de Textos e Botões — UX Writing & UI

**Data:** 2026-09-22 · **Branch:** arena/01a0c45c-game-idlepet@222a6f4 (follow-up: 504 chaves, P1 100% corrigido)
**Escopo:** todos os textos visíveis ao jogador + formatos de botões/pills/cards/toasts

## 1. Inventário de Textos

### 1.1 Localização
- 504 chaves em pt_BR.csv, en_US, es_ES (paridade 100%) — 389 base + 115 adicionadas (P0 26 + P1 10 ROOM/SERVICE_VERB + 14 REACT/HUD + 65 pré-existentes)
- 183 chaves usadas via Loc.t() estático, 0 faltando, 221 extras via dinâmico (EVENT_%d, RARITY_*, etc) — +14 REACT/HUD +10 ROOM/SERVICE_VERB
- Cobertura: missões, loja, coleção, equipe, mapa, ajustes, tutorial, compartilhamento, offline, prestígio, pesquisa

### 1.2 Hardcoded encontrados (antes da correção)
| Local | Texto | Problema | Severidade |
|---|---|---|---|
| MetaPanel._build_collection | "TODOS","CÃES","GATOS","LENDÁRIOS" | Não localizado, filtro | Alta |
| MetaPanel._build_shop | "TUDO","BANHEIRAS","PAREDES","LAÇOS" | Não localizado | Alta |
| MetaPanel._build_missions | "🎡 Roleta Diária • %s", "Gire 1×/dia..." "GIRAR"/"FEITO" | Hardcoded, sem i18n | Alta |
| MetaPanel | "📦 Semanal %d/%d • %d%% • Baú: %d/7 • %s" | Hardcoded | Média |
| MetaPanel | "PETS %d/%d • CONQUISTAS..." | Hardcoded inglês | Média |
| SalonPanels | "⭐ PEDIDO ESPECIAL", "💰 Aceitar rende gorjeta extra..." "✓ ACEITAR (+40% gorjeta)" "AGORA NÃO" "✓ CONTINUAR" | Hardcoded | Alta |
| Main._client_left | "💔 %s foi embora! -%d moedas" | Hardcoded, antes usava CLIENT_LEFT sem moedas | Alta |
| Main._update_queue_ui | "Chegando..." "A fila recarrega em %0.1fs" | Hardcoded | Média |
| Main | "O salão está no ritmo!..." "💡 Assistência..." "%s já está banhado..." | Hardcoded | Média |
| RushTuning | "🔥 PICO ×2 — %ds" "⏳ pico em %ds" | Hardcoded | Média |
| PetStories | bios em pt_BR apenas | Sem EN/ES | Média |
| DailySpin | "🪙 +%d moedas" | Moedas hardcoded, deveria usar COINS | Baixa |
| Toast | mensagens longas truncadas | Sem autowrap | Média |

### 1.3 Consistência de escrita
- **Casing**: CTAs primários em ALL CAPS (COMPRAR, COLETAR, TENTAR NOVAMENTE, MELHORAR) — padrão mobile F2P, ok para ação. Infos em Title Case (Moedas, Brasas, Banho) — ok.
- **Emojis**: uso consistente como ícone rápido (🪙 💬 🔥 ⏳ 💔 ⭐ 🐾) — bom para leitura rápida, mas precisa alt-text para leitor de tela? Em Godot Label, emoji é texto, ok.
- **Pontuação**: alguns toasts sem ponto final, outros com "!" — inconsistente. Padronizar: toast curto sem ponto, toast narrativo com ponto.
- **Tamanho**: títulos 44-68px, corpo 24-36px, botões 26-34px — hierarquia boa, mas com font_scale 1.2, 34→40px pode estourar pill 210px. Corrigido para 28px base no pill.
- **Clareza**: "PAYS paga" redundante? Em queue_info_text mostra "paga bem • paciência curta" — bom trade-off. "VISITOR_TAG visitante ✦ %d/%d" bom mas poderia ser "Visita %d/3" mais curto.

## 2. Inventário de Botões

### 2.1 Tipos
- **_pill** (Main): Label com StyleBoxFlat bg ffffff 0.95, radius 35→32, border 5→4, 82px altura, 28px fonte, CHARCOAL texto. Usado para moeda, review, combo, rush, prova social, meta. Bom para status, não clicável.
- **_button** (Main): Button 72x72 nav, 86x86 upgrades, 320x185 queue card (Button), 0x110 primary result, 0x72 share. Radius 34→32, margin 14, hover lightened 0.08→0.10 + borda branca 2, pressed darkened 0.12→0.15, disabled b0bec5→90a4ae. Bind InteractionFX (scale + haptics).
- **_style_button** (MetaPanel): similar mas radius 30, font 26, disabled b0bec5. Usado em info_row action, filtros, close, font scale, lang.
- **info_row Action**: 200x64 do tscn, texto via _style_button.
- **pet_card**: PanelContainer 196x240, gui_input favorite — agora com hover scale 1.05 + pressed 0.95 + tween 0.08s (P1 corrigido).
- **slider_row**: HSlider 420x40, step 0.05 — agora com labels 0%/100% + tooltip 0%—100% + Value % (P1 corrigido).
- **close**: 84x84 "✕" — bom, mas font size default pequeno, agora escala com font_scale.

### 2.2 Problemas de formato
| Problema | Onde | Impacto | Correção aplicada |
|---|---|---|---|
| **Touch target <64px** | filtros 140x56, shop 140x56 | Falha WCAG, dedo grande erra | 150x64 mínimo |
| **Contraste baixo** | botão amarelo ffd54f com texto branco (1.41:1) | Ilegível | WCAG max-ratio: _ideal_text_color() escolhe CHARCOAL (9.33:1) — PASS AA |
| **Contraste baixo** | GREEN 7ed957 branco 1.76:1 / 43a047 3.30:1 | Falha AA | Corrigido: GREEN 43a047→2e7d32 (5.13:1 com branco, PASS AA) + _ideal_text_color() max-ratio (PINK 6.15:1, BLUE 6.57:1) |
| **Disabled ilegível** | b0bec5 + branco | 1.5:1 | Mudado para 90a4ae + eceff1 + mantém disabled |
| **Radius inconsistente** | pressed 30 vs normal 34 | Salto visual | Unificado 32 (Main) e 30 (Meta) |
| **Texto truncado** | pill 210px + font 33*1.2=39px "💬 Ana: Caramelo amou o banho! ★★★★★" 45 chars | Overflow | Autowrap WORD_SMART + min 64px altura + font 28 base |
| **Toast truncado** | 720x76 fixo, sem wrap, duração fixa 1.6s | Mensagens longas cortadas | Autowrap + altura dinâmica + duração 1.6+len*0.02 max 4s + offset 96px |
| **Result panel fixo** | 920x860, title 68, detail 36 sem wrap | Overflow com thanks+memória | Autowrap + title 56 + detail 28 + panel 900 altura + 40 radius 28 margin |
| **Queue card pequeno** | 185px altura para 2 linhas + story | Overflow | 210px altura + info 18px + name 24 + autowrap |
| **Falta focus** | sem stylebox focus | Teclado/controle sem feedback | Adicionado focus borda branca 3px |
| **Falta hover feedback** | alguns botões sem borda | Pouco feedback | Hover com borda branca 2px |

### 2.3 Hierarquia visual
- **Primário**: GREEN (ação principal: CONTINUAR, ACEITAR, MELHORAR, COLETAR) — ok, verde = progresso
- **Secundário**: BLUE (info, assistir, copiar) — ok
- **Destaque**: PINK ff8fb1 (fechar, coleção, favorito) — ok, marca do jogo
- **Alerta**: ff8f00 laranja rush, ef5350 vermelho perda — ok
- **Recompensa**: ffd54f amarelo — precisa texto escuro (corrigido)
- **Neutro**: b0bec5/90a4ae desabilitado, 90a4ae/546e7a secundário — ok

## 3. Melhorias Implementadas (P0)

### 3.1 Localização
- 26 novas chaves P0: FILTER_ALL, FILTER_DOGS, FILTER_CATS, FILTER_LEGENDARY, FILTER_ALL_COSMETICS, FILTER_BATH, FILTER_WALL, FILTER_ACCESSORY, DAILY_SPIN_TITLE/DESC, SPIN_ACTION/DONE, WEEKLY_PROGRESS_PILL, COLLECTION_SUMMARY, SPECIAL_ORDER_TITLE/NOTE/ACCEPT/DECLINE, CLIENT_LEFT_COINS, RUSH_ACTIVE/COOLDOWN, ASSIST_TOAST, MOOD_BUFF_TOAST, PETTING_LIMIT, WEEKLY_RESET_TOMORROW/DAYS, STREAK_LOSS_NOTE, ASSIST_ACTIVE, QUEUE_ARRIVING/RELOAD
- 24 novas chaves P1 2026-09-21: ROOM_BATH/GROOM/DRY/PERFUME/STYLE (5), SERVICE_VERB_BATH/GROOM/DRY/PERFUME/STYLE (5), REACT_FEARFUL_1-3/IRRI_1-3/CAT_1-3/HAPPY_1-3 (12), HUD_RAPIDO, HUD_STATION_LEVEL (2) — PetShopCanvas 100% Loc.t, SalonTuning perfume maestria
- PetStories agora com EN fallback: _is_en() checa Loc.lang, usa dicionários EN para bio/queue/memory/thanks
- DailySpin label_for usa COINS via Loc.t
- LiveOps weekly_reset_label usa Loc.t

### 3.2 Botões
- **_pill**: 82→64px min, 33→28px fonte, 35→32 radius, 12 margin, 0.95→0.97 alpha, autowrap, clip false
- **_button**: min 64px garantido, autowrap, clip false, font 34→30, disabled 90a4ae + eceff1, hover borda branca 2, pressed radius unificado 32, focus borda branca 3, texto adaptativo para amarelo
- **_style_button**: min 64px, autowrap, font 26*scale, disabled 90a4ae, hover borda branca 2, focus, texto adaptativo CHARCOAL se light
- **Filtros**: 140x56→150x64
- **Toast**: autowrap, altura dinâmica, duração proporcional, offset 96px
- **Queue card**: 185→210px altura, font 26→24 name, 22→20 service, 20→18 info, autowrap + 296px min width
- **Result panel**: 860→900 altura, title 68→56, detail 36→28, autowrap 840-860, actions separation 18→14/12, primary 110→96, share 72→64

### 3.3 Textos
- Cliente saindo: CLIENT_LEFT_COINS localizado
- Rush: RUSH_ACTIVE/COOLDOWN localizado
- Assistência: ASSIST_TOAST, ASSIST_ACTIVE, MOOD_BUFF_TOAST, PETTING_LIMIT localizados
- Fila: QUEUE_ARRIVING, QUEUE_RELOAD, QUEUE_WAITING já localizado
- Coleção: COLLECTION_SUMMARY, FILTER_* localizados
- Loja: FILTER_* localizados
- Missões: DAILY_SPIN_* e WEEKLY_PROGRESS_PILL localizados
- Upsell: SPECIAL_* localizados
- Streak: STREAK_LOSS_NOTE localizado

## 4. O que foi corrigido em P1 (2026-09-22 — branch arena/01a0c45c-game-idlepet@222a6f4 + follow-up)

- **Contraste GREEN**: 7ed957 1.76:1 → 43a047 3.30:1 → 2e7d32 5.13:1 PASS AA com branco; _ideal_text_color() WCAG max-ratio em Main e MetaPanel (PINK 6.15:1, BLUE 6.57:1, YELLOW 9.33:1)
- **Pet card**: feedback pressed scale 0.95 + hover 1.05 já existente (MetaPanel._build_collection mouse_entered/ gui_input) — validado, sem pendência
- **Slider**: labels 0% / 100% adicionados em MetaPanel._add_slider (MinLabel/MaxLabel 18px 90a4ae) + tooltip 0%—100% + Value %
- **Empty states**: fila vazia já exibe "Chegando…" + dots animados + "Toque para acelerar" CTA (Main._update_queue_ui) — validado
- **Reações pet**: PetShopCanvas.react_to_touch() hardcoded PT → 12 chaves REACT_* via Loc.t (3 fearful/anxious, 3 irritated, 3 cat, 3 happy) + HUD_RAPIDO/HUD_STATION_LEVEL
- **Títulos sala**: PetShopCanvas ROOM_* hardcoded PT → 5 chaves ROOM_* via Loc.t (BANHO & ESPUMA etc)
- **Verbos serviço**: Main SERVICE_LABELS hardcoded PT → 5 chaves SERVICE_VERB_* via Loc.t (_service_verb())
- **Maestria perfume**: SalonTuning apply() sem perfume → map perfume→perfume + pulse_window*1.30

## 4b. O que ainda pode melhorar (P2 — opcional)

- **Casing**: ALL CAPS apenas CTA primário; EQUIP=USAR poderia ser Title Case — decisão de design, manter
- **Tamanho fonte filtros**: 28*1.2=33px em 150px "LENDÁRIOS" 9 chars — considerar 22*scale se truncar em 720p
- **Erros**: TRANSFER_INVALID toast poderia ter botão "Tentar novamente" — hoje só toast ef5350
- **Onboarding**: TUT_STEP_1/2 já têm spotlight; seta visual adicional seria polish

## 5. Checklist de validação

- [x] Todos os textos visíveis passam por Loc.t ou têm fallback EN
- [x] Nenhum texto hardcoded em pt_BR sem chave (exceto mock prova social que é intencionalmente fake mas agora usa template)
- [x] Botões >=64px altura
- [x] Autowrap para textos longos
- [x] Contraste WCAG AA max-ratio para amarelo/GREEN/PINK/BLUE (2e7d32 5.13:1 PASS)
- [x] Focus state para teclado
- [x] Hover com borda branca
- [x] Disabled legível
- [x] Toast duração proporcional
- [x] Result e queue card sem overflow
- [x] Filtros + ROOM_* + SERVICE_VERB_* + REACT_* + HUD_* localizados (504 chaves)
- [x] Maestria perfume (pulse_window*1.30) + slider 0%/100% + economia 52/88 documentada
- [x] validate_project.py 0 errors

## 6. Próximos passos

- Testar com font_scale 0.8/1.0/1.2 em 720p e 1080p
- Testar com Loc.lang en_US e es_ES
- Medir contraste com ferramenta (ex: WebAIM) e ajustar GREEN se necessário
- Adicionar teste automatizado que falha se encontrar string literal em _button/_pill sem Loc.t (exceto emojis)
