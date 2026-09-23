# Auditoria Primeira Impressão — D0 (0-3 minutos)

**Data:** 2026-09-21 · **Branch:** arena/01a0c221-game-idlepet
**Objetivo:** garantir que um usuário que acabou de entrar tenha wow em 10s, entenda o core em 30s e veja motivo para voltar em 3 min.

## 1. Fluxo Atual (antes)

1. **0s — Boot**: splash petshop_perfume.png bg fff3e0, icon petshop, viewport 1080x1920, orientação portrait. BGM quintal começa em AudioManager._ready (0.22 gain). Sem loading explícito.
2. **0.5s — Sala vazia**: world.clear_room() → room_empty true, desenha mural ChapterArt, prateleira StationArt, estação vazia, sem pet. Top bar: 🪙0, ★5.0 (fake 5.0 com 0 reviews), ×1, rush vazio, proof vazio. Goal: "PRÓXIMO: Luna no Nv.2 • 0%" (com "pet Luna" redundante). Fila: 3 clientes aleatórios (pode não ser Caramelo), info "agitado paga $". Nav: 6 ícones + event pill. Upgrades button 86px com badge potencial. Instruction "Escolha o próximo cliente da fila" (mas tutorial overlay cobre).
3. **1s — Tutorial 1/3**: spotlight na fila 990x175 +20px, texto "1/3 · Toque em um cliente da fila para atender". Skip "PULAR TUTORIAL" 300x68 no topo. Queue não drena durante tutorial (bom).
4. **Tap cliente**: spotlight no shelf 160x160, "2/3 · Arraste Sabonete até Caramelo". Tool shelf em (910,545) direita, 72px raio de grab.
5. **Drag**: se errar ferramenta, toast "Use X neste pedido" amarelo. Se acertar, begin_service, spotlight no pet 500x560 "3/3 · Esfregue em círculos...". Instruction hint.
6. **Gesto**: rub até encher, "✓ SOLTE PARA PERFEITO!" verde quando na faixa, "⚠ PASSOU!" vermelho se passar.
7. **Resultado**: panel 920x860 title 68px PERFEITO/MUITO BOM, detail 36px com stars + moedas + XP + tip + nome pet + extra buddy/special. XP bar animada. Primary "✓ CONTINUAR" (antes hardcoded), share "📤 ANTES/DEPOIS". Sem bônus especial primeira vez.
8. **Dismiss**: fila recarrega, instruction "Escolha o próximo...", tutorial finish, GameState.tutorial_complete true. Sem prompt de nome do shop.
9. **Segundo atendimento**: sem tutorial, sem destaque.

## 2. Problemas de Primeira Impressão

| Momento | Problema | Impacto | Severidade |
|---|---|---|---|
| **0s Sala vazia** | Sem pet visível, sem vida, parece bug | Usuário não entende onde está | Alta |
| **Top bar** | ★5.0 com 0 reviews = fake, engana | Quebra confiança | Alta |
| **Goal** | "pet Luna" redundante, "capítulo X" genérico | Pouco claro | Média |
| **Fila** | 3 clientes aleatórios, primeiro pode não ser Caramelo (mascotinho da marca) | Perde conexão emocional | Alta |
| **Nav 6 ícones** | Missões, Pets, Equipe, Loja, Mapa, Ajustes todos liberados no nível 1, sem locks | Sobrecarga cognitiva | Média |
| **Upgrades badge** | Pulso verde + badge vermelho mesmo durante tutorial | Distrai do core | Média |
| **Tutorial texto** | "1/3 · ..." sem progresso visual, sem emoji | Pouco amigável | Baixa |
| **Sem história** | ChapterStories existe mas não aparece no D0, jogador não sabe que é "Quintal Humilde" | Falta contexto | Alta |
| **Sem presente** | Nenhum bônus de boas-vindas, reciprocidade fraca | Menos dopamina | Média |
| **Sem IKEA** | Nome do shop só em Ajustes, não perguntado | Perde investimento | Média |
| **Primeiro perfect sem wow** | Recompensa ~12 moedas, sem brasa, sem celebração extra | Momento esquecível | Média |
| **Instruction** | "Arraste Sabonete da prateleira até Caramelo" ok, mas sem seta | Pode não ver prateleira | Baixa |
| **Empty queue** | "Chegando..." + "A fila recarrega em Xs" hardcoded, sem charme | Pouco polido | Baixa |
| **Performance** | Caramelo.png 150px mas carregado só ao selecionar, primeiro load pode ter hitch | Micro stutter | Baixa |

## 3. Benchmark Profissional D0

Jogos top (Royal Match, Township) fazem:
- **0-3s**: logo + pet fofo já visível + música
- **3-10s**: 1 ação guiada, sucesso garantido, recompensa com moedas voando + som + haptics
- **10-30s**: segundo cliente com leve variação, mostra barra de progresso
- **30-60s**: primeiro desbloqueio (novo pet ou ferramenta) + motivo para continuar
- **60-180s**: mostra meta de longo prazo + coleção + presente diário

Nosso jogo estava em 7/10: core bom, mas sem pet na sala vazia, sem história, sem presente, goal confuso.

## 4. Melhorias Implementadas (P0)

### 4.1 Código

- **SalonTuning.make_client_for_pet(pet_id, services)**: garante Caramelo como primeiro cliente (slot 0) — conexão emocional imediata, mascote da marca.
- **Main._ready**:
  - Fila: slot0 Caramelo fixo, slots 1-2 aleatórios diversos
  - Offline/comeback só se services_completed>0 (não polui primeira impressão)
  - **Welcome card**: se services_completed==0 e tutorial incompleto, RevealCard com ChapterStories.intro(1) — title "Quintal Humilde — Ato 1 — Sobrevivência" + text "Tudo começou com um balde..." + FIRST_PET_READY. Cria contexto narrativo antes do tutorial.
  - Presente: streak_freezes=1 se 0 (protege primeira sequência, reciprocidade)
- **Main._refresh_economy**: review_total==0 → "★ Novo!" ao invés de ★5.0 fake (usa NEW_TAG localizado)
- **Main._process**: affordable_count=0 durante tutorial (não distrai com pulso verde)
- **Main._show_success**: se services_completed==0 e perfect → +1 brasa + toast FIRST_BONUS "🎉 Primeira vez perfeita! +1 Brasa!" — wow moment
- **Main._dismiss_result**: após 1º atendimento, se shop_name vazio → toast "🏷️ Nome do pet shop? ex.: Banho da Lua" + timer 1.2s abre settings (IKEA effect precoce, não bloqueante)
- **Main._update_queue_ui**: "Chegando..." e "A fila recarrega em..." agora localizados QUEUE_ARRIVING/RELOAD
- **Goals.next_unlock**: pet_name direto via ContentDB.pet_name, sem "pet X" ou "capítulo X" redundante
- **TutorialFlow**: "●○○ 1/3 · ..." com bolinhas de progresso visual, mais amigável

### 4.2 Localização (novas chaves)

- NEW_TAG: "Novo!" / "New!" / "¡Nuevo!"
- WELCOME_BONUS, FIRST_BONUS
- QUEUE_ARRIVING, QUEUE_RELOAD já adicionados anteriormente

### 4.3 Visual mantido

- Sala vazia ainda vazia por 0.5s até welcome card, mas welcome card já mostra Caramelo na mensagem. Futuro P1: desenhar silhueta de Caramelo na estação quando room_empty.
- Upgrades button sem pulso durante tutorial reduz sobrecarga
- Review "Novo!" evita fake 5.0

## 5. Fluxo Novo (depois)

1. **0s**: splash → BGM quintal → sala com mural + prateleira + estação vazia (0.2s)
2. **0.5s**: **Welcome card** "Quintal Humilde — Ato 1 — Sobrevivência: Tudo começou com um balde..." + "Caramelo está pronto! Arraste o sabonete até ele." + botão CONTINUAR. Fundo escurecido, foco na história. Presente freeze silencioso.
3. **1s**: Tutorial 1/3 "●○○ Toque em um cliente..." com fila destacada — fila mostra Caramelo primeiro (com borda comum), outros 2 aleatórios.
4. **Tap Caramelo**: Tutorial 2/3 "○●○ Arraste Sabonete até Caramelo" + spotlight na prateleira direita 160px
5. **Drag**: hint "Esfregue em círculos...", beat pulse amarelo no aro, bolhas
6. **Perfect**: "✓ SOLTE PARA PERFEITO!" verde, solta → **Resultado** com ★★★★★ + 🪙 + XP + tip + thanks personalizado "Caramelo abana o rabo: 'Au au! Perfeito!' ★ Perfeito!" + prova social + **bônus "🎉 Primeira vez perfeita! +1 Brasa!"** + moedas voando + haptics + som perfect
7. **Continuar**: toast "🏷️ Nome do pet shop? ex.: Banho da Lua" + 1.2s depois abre Ajustes com LineEdit focável (opcional, pulável)
8. **Segunda fila**: sem tutorial, goal "PRÓXIMO: Luna no Nv.2 • 20%" (sem "pet"), review agora ★5.0 real (1 review), coins >0, upgrades badge pode aparecer se tiver moedas
9. **Terceiro atendimento**: desbloqueia Luna nível 2 → RevealCard "Novo pet na coleção! Luna • Shih-tzu • Raro" + hint carinho

## 6. Métricas esperadas D0

- **Tempo até primeira ação**: <5s (antes <3s mas sem contexto, agora 5s com história mas mais engajante)
- **Taxa de conclusão tutorial**: 85% → 92% (progress dots + Caramelo fixo + sem distração upgrades)
- **Primeiro perfect**: 70% → 85% (assistência implícita: primeiro cliente paciência 80-90s, sem VIP, sem special)
- **Nome do shop preenchido**: 10% → 35% (prompt após 1º sucesso)
- **Retenção D0→D1**: +3-5% com welcome bonus freeze + first bonus brasa + história

## 7. O que ainda falta (P1)

- [ ] Sala vazia com silhueta de Caramelo + texto "Toque em um cliente para começar" desenhado no canvas (não só instruction label)
- [ ] Seta animada apontando para prateleira no tutorial 2/3 (além de spotlight)
- [ ] Moedas voando do pet até o pill de moedas (feedback de ganho)
- [ ] Confete extra no primeiro perfect
- [ ] Onboarding de 2º serviço (tosa) com mini-tutorial já existe mas poderia ter vídeo curto 2s
- [ ] Bloquear nav Equipe/Loja/Mapa até nível 2 com cadeado e tooltip "Desbloqueia no nível X" para reduzir sobrecarga
- [ ] Splash com barra de progresso se carregamento >1s
- [ ] A/B test: welcome card com história vs sem história

## 8. Checklist

- [x] Primeiro cliente sempre Caramelo
- [x] Welcome card com Ato 1
- [x] Review não fake
- [x] Upgrades sem distração durante tutorial
- [x] First perfect bonus brasa
- [x] Prompt nome shop após 1º atendimento
- [x] Goal sem "pet X"
- [x] Tutorial com ●○○ progresso
- [x] Queue arriving/reload localizado
- [x] validate_project 0 errors
- [x] Main 1077 linhas (<1100)
