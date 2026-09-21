# Auditoria Profissional — UX, Storytelling, Gatilhos Mentais e Retenção

**Data:** 2026-09-21 · **Branch:** arena/01a0c221-game-idlepet · **Versão:** early vertical slice jogável
**Objetivo:** elevar de slice bom para nível profissional publicável (D1 >40%, D7 >15%, D30 >6%, retenção por narrativa).

---

## 1. Diagnóstico Geral — Onde estamos

### Forças atuais (já profissionais)
- **Core loop de 10s com identidade**: 5 gestos distintos (rub, stroke, zone, pulse, drop) com tuning por temperamento/espécie/porte + feedback tátil/sonoro por traço. Variedade motora real, não só skin.
- **Juice**: VFX por serviço com beat pulse ancorado no áudio real, partículas com highlight, aro de dosagem no utensílio, celebração com estrelas.
- **Progressão 61h**: 50 pets (25 cães/25 gatos), 120 níveis, 10 capítulos (quintal → império), 6 staff com passivo + automação 4-10%, 23 cosméticos, 5 pesquisas permanentes, prestígio com herança 25%.
- **Retenção básica**: offline cofre 15% → 50% com staff, comeback 48h com freeze, login diário 7 dias com pet lendário Mel, missões diárias sorteadas por data + épica, semanais 7 + baú, passe 28 dias, evento semanal com meta do dia, pico do bairro a cada 240s, VIP, upsell 35%, buddy +40%, afeto 50 com brasas, visitante misterioso 3×.
- **Acessibilidade**: daltonismo, assistência motora, fonte 0.8/1.0/1.2, mão esquerda, reduced particles, eco mode, safe area, back button Android.

### Gaps para nível profissional
| Dimensão | Sintoma | Impacto D1/D7/D30 |
|---|---|---|
| **Storytelling** | Sem arco do jogador, pets sem bio, capítulos só nome na placa, staff sem diálogo, sem diário/memórias | D7 fraco: jogador não tem motivo emocional para voltar além de números |
| **Gatilhos mentais** | Reciprocidade, escassez, prova social, perda, curiosidade implementados parcialmente mas sem explicitação visual | Conversão e retenção abaixo de benchmark: gatilhos existem mas não são percebidos |
| **Retenção** | Recompensas escaladas mas sem *momentos* diários fortes (spin, caixa misteriosa), sem calendário LiveOps visível, sem meta de longo prazo além de 120 | D30 fraco: após 20h (38k por atendimento) nada novo acontece |
| **UX de progressão** | Upgrades sem ROI, prestígio sem simulação, coleção 50 sem busca, loja 23 sem categorias (já melhorado com filtros mas ainda sem preview) | Fricção: jogador não entende onde investir |
| **Social/Viral** | Share 9:16 com marca ok, mas sem QR, sem leaderboard, sem visita a amigos | Viral K <0.2 |

---

## 2. Storytelling — Auditoria

### 2.1 Narrativa atual
- `career_track.json`: 10 tiers com `name` e `feature` (banho, tosa, vacinação, etc) mas sem descrição, sem personagem, sem conflito.
- `pets.json`: cada pet tem `temperament`, `patience`, `base_tip`, `preferred_service`, `city`, mas sem bio, sem história, sem motivo de estar no pet shop.
- `staff.json`: 6 membros com `passive` e `automation`, sem bio, sem diálogo, sem evolução.
- `ChapterArt` e `StationArt`: mural cresce por tier, estação evolui a cada 10 níveis, mas sem texto narrativo.
- `RevealCard`: mostra pet/capítulo/conquista com título genérico “Novo pet na coleção!”.

### 2.2 Problemas de storytelling
1. **Sem protagonista**: jogador é “Você” sem nome, sem arco (de quintal humilde a império sem história).
2. **Pets intercambiáveis**: Caramelo (vira-lata caramelo, happy, patience 42) = mesmo que Luna (shih-tzu anxious) em narrativa; temperamento afeta janela mas não diálogo.
3. **Sem conflito**: por que clientes estão impacientes? Por que VIP paga ×2? Sem contexto “dona apressada”.
4. **Sem memórias**: afeto 50 mas sem diário “Caramelo te trouxe bolinha no dia 12”.
5. **Capítulos sem cerimônia**: tier 2 “Pet Shop de Bairro” desbloqueia no nível 8 com toast, mas sem cutscene ou carta da Bia.

### 2.3 Gatilhos narrativos que faltam (profissional)
- **Efeito IKEA**: jogador nomeia pet shop (já existe) mas não nomeia pets, não customiza bandana → falta investimento.
- **Narrativa emergente**: cada pet deveria ter 3 micro-histórias que aparecem na fila (“Thor, pinscher irritado, fugiu do colo da dona, paciência 27, paga $ porque dona rica está atrasada”).
- **Arco de 3 atos**: Ato 1 (1-10 quintal, sobrevivência), Ato 2 (11-60 clínica, equipe, dilemas), Ato 3 (61-120 rede, prestígio, legado). Cada ato com carta de personagem.
- **Diário do pet**: ao atingir afeto 10/25/50, desbloqueia memória com texto + foto.
- **Staff com arco**: Bia entra no serviço 8 com diálogo “Aprendi a dar banho sozinha!”, Téo no 15, etc.

### Recomendações storytelling (P0)
- Criar `core/story/PetStories.gd`: gera bio a partir de `breed + temperament + city + preferred_service` usando templates, sem precisar alterar JSON.
- Adicionar `ChapterStories.gd`: texto de introdução por tier com personagem (Bia, Seu Zé, Maya).
- RevealCard com narrativa: pet novo mostra bio + dica de temperamento.
- Toast de afeto com história: “♥ Caramelo te considera família! (20/50) — ele dormiu na sua banheira ontem”.
- Diário simples em coleção: ao tocar pet com afeto >=10, mostra 1 memória.

---

## 3. Gatilhos Mentais — Auditoria

Mapeamento dos 12 gatilhos de Cialdini + Nir Eyal:

| Gatilho | Status atual | Como aparece | Gap profissional |
|---|---|---|---|
| **Reciprocidade** | ✅ Parcial | Carinho → afeto → +25% renda + brasas | Sem “presente inesperado” do pet; afeto só número, sem animação de presente |
| **Escassez** | ✅ Parcial | Rush 45s a cada 240s, VIP, weekly featured, seasonal wall | Sem countdown visual, sem “só hoje”, sem timer no card |
| **Prova social** | ⚠️ Fraco | Reviews ★ média, neighborhood tier | Sem “12 jogadores atenderam Luna hoje”, sem “mais popular da semana” |
| **Autoridade** | ✅ Bom | 10 capítulos, staff lendário Maya, mastery aro ouro | Sem selo “veterinário recomenda” |
| **Compromisso/Coerência** | ✅ Bom | Streak 7 dias, passe 28, weekly 7, afeto 50 | Sem “você está a 1 dia de completar” + freeze visual |
| **Afeição (liking)** | ✅ Bom | Pets fofos, 10 estados, corações, buddy | Sem nomeação de pets, sem customização profunda |
| **Perda (loss aversion)** | ✅ Parcial | Cliente sai sem reputação, combo grace 1×, rush protege combo | Cliente saindo sem mostrar moedas perdidas (“-840 moedas perdidas”) |
| **Curiosidade (curiosity gap)** | ⚠️ Fraco | Visitante “✦” com progresso 1/3 | Sem “??? raça rara” com silhueta + dica |
| **Recompensa variável** | ✅ Bom | Tips 0-60%, VIP ×2, rush ×2, buddy 40%, mastery +6% | Sem caixa misteriosa no combo 10, sem spin diário |
| **Progresso dotado** | ✅ Parcial | XP %, afeto 3 corações, coleção % | Sem barra “15/50 pets” com recompensa no fim |
| **Efeito IKEA** | ⚠️ Fraco | Shop name, favorite pet | Sem customização de bandana, sem nomear pet |
| **Novidade** | ✅ Bom | 5 serviços, temperamento muda gesto, eventos semanais | Sem “serviço surpresa” diário |

### Gatilhos que faltam para profissional
1. **Contagem regressiva explícita**: rush “PICO ×2 — 23s” existe mas sem barra circular, sem som de relógio.
2. **Perda quantificada**: cliente saindo deveria mostrar “-840 moedas + -20 XP perdidos” para ativar loss aversion.
3. **Prova social ao vivo**: fila poderia mostrar “🔥 3 pessoas atenderam hoje” (mock local com `services_completed`).
4. **Recompensa misteriosa**: combo 10 deveria dar baú misterioso com moedas + chance de brasa.
5. **Escassez sazonal**: parede carnaval/natal sem timer “só até 28/02”.
6. **Reciprocidade com presente**: afeto 25 deveria dar presente físico (bandana) não só brasas.

---

## 4. Retenção — Auditoria por D0/D1/D7/D30

### D0 (primeiros 10 min) — BOM
- FTUE 3 passos + mini-tutorial por serviço.
- Primeiro pet Caramelo + Luna no nível 2.
- Recompensa imediata: moedas voam, combo, review.
- **Gap**: sem “primeira compra” de upgrade guiada (jogador pode ficar 5 min sem saber que pode melhorar).

### D1 (retorno 24h) — BOM, mas sem gancho forte
- Offline cofre: `Rewards.scaled(50% renda) * offline_seconds` cap 2h→8h + double por brasa/ad. Relevante (antes 0.1%).
- Login diário com streak + freeze + pet lendário Mel no dia 7.
- Evento do dia com meta (ex: “Segunda do Banho ×2”).
- **Gap**: sem notificação push com nome do pet (“Caramelo sentiu sua falta!”) — `NotificationManager` agenda mas texto genérico.
- **Gap**: sem spin diário ou caixa grátis que é padrão profissional.

### D7 (semana) — MÉDIO
- Semanais 7 + baú 3 brasas + 200 moedas escaladas.
- Passe 28 dias (1 dia por 3 missões).
- Streak freeze protege sequência.
- **Gap**: weekly chest progress não visível no HUD; jogador não sabe “falta 1”.
- **Gap**: sem “missão épica da semana” com narrativa.

### D30 (mês) — FRACO
- Prestígio com herança 25% + preview, pesquisa 5 nós, coleção 50, mastery 100/500/2000, afeto 50, staff 6.
- Após nível 120, só prestígio repete; sem endgame (rede, instituto, império são só nomes).
- **Gap**: sem “temporada” com passe premium, sem ranking, sem novos pets sazonais além de 2 paredes.
- **Gap**: sem diário de memórias que faz jogador voltar para ver evolução do vínculo.

### Benchmark profissional
- D1 40% exige: offline relevante + daily spin + evento + push personalizado.
- D7 15% exige: weekly com progress visível + streak com proteção + coleção com meta + social.
- D30 6% exige: prestígio com legado + pesquisa + narrativa de longo prazo + sazonalidade.

---

## 5. Jogabilidade e Gatilhos de Gameplay — Auditoria

### Self-Determination Theory
- **Autonomia**: fila com escolha (3 clientes) ✅, favorite pet ✅, cosméticos 23 ✅, left-handed ✅. Falta: escolher ordem de upgrades, escolher staff para sala.
- **Competência**: gestos com identidade + temperamento + mastery + combo + perfect chime ✅. Falta: fantasma de demonstração, modo treino, ranking de perfects.
- **Vínculo (relatedness)**: afeto, buddy, carinho, corações ✅. Falta: diário, memórias, staff com diálogo, pet que lembra do jogador.

### Flow
- Dificuldade escala com paciência (27-50), temperamento (+0.03 janela), espécie, porte, pesquisa, assistência. Bom.
- **Gap**: sem *dynamic difficulty adjustment* (DDA) — se jogador falha 3× seguidas, deveria alargar janela temporariamente (evita churn).

### Recompensa
- Moedas escaladas à renda (evita morte da economia) ✅, mas sem transparência “por que 840?”.
- **Gap**: sem “moedas voando” do pet para o pill de moedas (feedback de ganho).

---

## 6. O que precisa para nível profissional — Roadmap

### P0 — Esta sessão (sem assets novos, só código/texto)
1. **Storytelling**: `PetStories.gd` + `ChapterStories.gd` com bios geradas, integradas em fila, coleção e resultado.
2. **Gatilho Perda**: cliente saindo mostra moedas perdidas + animação triste + som.
3. **Gatilho Escassez**: rush com barra circular countdown + weekly featured com timer “expira em 2d”.
4. **Gatilho Prova social**: review pill com “12 avaliações hoje” mock + neighborhood tier com progress.
5. **Retenção D1**: spin diário simples (1× por dia, recompensa escalada) via `Rewards`.
6. **Retenção D7**: weekly chest progress no HUD “Semanal 5/7”.
7. **Retenção D30**: diário de afeto com memórias em coleção.
8. **DDA**: se 3 fails seguidos, assistência temporária + toast “Vamos com calma, janela maior!”.

### P1 — Próxima sessão
- Diário completo com 3 memórias por pet, staff com diálogos por tier, endgame com “Rede Regional” tendo gestão de 2 salas.
- Caixa misteriosa no combo 10, moedas voando, QR no share.

### P2 — Futuro (requer arte/backend)
- Leaderboard, visita a amigos, temporadas com passe premium, pets sazonais com VO.

---

## 7. Conclusão

Para profissional, o jogo precisa deixar de ser “salão com números” e virar “bairro com histórias”. Os sistemas de retenção já existem e estão escalados, mas **não contam histórias**. Adicionar bio gerada, memórias de afeto, perda quantificada e escassez visual transforma os mesmos números em motivos emocionais para voltar — é o que separa um slice bom de um produto D30.

**Próximo passo imediato:** implementar P0 acima, manter Main.gd <1100 linhas via helpers estáticos (padrão SalonTuning).

