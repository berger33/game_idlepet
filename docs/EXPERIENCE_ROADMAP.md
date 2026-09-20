# EXPERIENCE_ROADMAP — experiência progressiva, divertida e viciante

Leitura completa do jogo como ele está construído hoje (código + dados), o que a fase
atual (HUD V2) entregou, e o catálogo priorizado de melhorias de mecânica, meta,
animação e som — sem alterar o que já foi conquistado (gates M0–M4 de
`docs/ROADMAP.md` continuam mandando).

## 1. O jogo como está hoje (verificado no código)

- **Core loop:** cliente entra na fila → pet na estação → gesto de serviço
  (banho/tosa/secagem/perfume/estilo) com Perfect/Good → moedas + gorjeta + review →
  upgrade → próximo pet. Cinco serviços destravados por nível (1/3/5/7/10), cada um
  com seu utensílio no mesmo nível (`TOOL_LEVELS` em `PetShopCanvas.gd`).
- **Meta:** missões diárias (6) e semanais (7), conquistas, coleção de 50 pets com
  cosméticos, staff, mapa, pesquisa (`research.json`), passe (`pass.json`),
  eventos semanais/sazonais com modificadores por dia (`events.json`), renda offline
  com cofre melhorável, prestígio planejado no ROADMAP.
- **Vínculo:** carinho no pet aumenta `pet_affection` (0–50, salvo) que multiplica a
  renda do pet em até +25% (`Main.gd`), com reações animadas (10 overlays de estado
  por pet, 500 PNGs validados).
- **Áudio:** música procedural em duas camadas (ambiente + energia) cruzadas por
  estado de jogo, pulsos visuais sincronizados ao compasso real
  (`AudioManager.beat_phase()`), SFX procedurais (`tap`, `coin`, `upgrade`,
  `panel_open`, `equip`…).
- **HUD V2 (esta fase):** mobiliário funcional desenhado por código
  (`StationArt.gd`) com contrato espacial único (`data/service_layouts.json`):
  pés do pet sempre na superfície da estação (540,1160) e utensílios sempre nas
  pranchas da estante — em qualquer cenário. Botões grandes de upgrade removidos;
  um botão redondo no canto superior direito abre o painel único de melhorias
  (estação + 5 utensílios) e pulsa quando há compra disponível.

## 2. Por que já é divertido — e onde a experiência vaza

**Fortalezas:** o pet reage (é o coração do jogo); progresso visível a cada minuto;
sessões curtas cabem no bolso; o mundo tem identidade (Bairro, Bia, eventos temáticos).

**Vazamentos identificados (ordem de impacto):**

1. **Vínculo invisível:** o afeto só aparece num toast. Num jogo de pets, o medidor
   de amizade deveria estar *na tela do pet* — é o loop emocional que faz voltar.
2. **Serviço repetitivo:** o gesto é o mesmo do nível 1 ao 50; faltam *momentos*
   (timing, surpresa, pedido especial) que quebram a rotina sem virar skill-game.
3. **Sem “uau” compartilhável:** a celebração existe, mas nada gera um *momento
   guardável* (foto/álbum) — combustível de retenção D7+ e de share orgânico.
4. **Música única:** a sala muda (5 ambientes lindos) mas o tema não; o crossfade de
   energia já prova que a arquitetura aguenta temas por sala.
5. **Milestones sem payoff visual:** `visual_milestones` já existe no
   `upgrades.json` (níveis 1/5/10/20/35/50/70/90/120) mas a estação não muda de cara.

## 3. Catálogo de ideias (esforço P/M/G × impacto)

### 3.1 Core loop — variedade com propósito

| Ideia | Descrição | Esforço | Impacto |
|---|---|---|---|
| **Sequência perfeita** | Perfects em sequência sobem um multiplicador visível (×1.1…×1.5) com pitch do SFX subindo; errar zera. Missões `*_combo_*` já medem isso. | P | Alto |
| **Micro-timing** | Banho: enxágue no momento certo da espuma = crítico; Tosa: pulga fugitiva pra estalar com tap. Crítico = chuva de moedas curta + VFX próprio. | M | Alto |
| **Pedido do dia** | Usa o schema de `events.json`: cliente com pedido (“laço vermelho”, “perfume de lavanda”) paga 2× e dá item de coleção. | M | Alto |
| **Spa completo** | 3 serviços no mesmo pet na visita = celebração especial + polaroid (3.3) + bônus. Dá objetivo à troca de sala. | M | Médio |
| **Assistente visível** | Staff contratado aparece na sala e “ajuda” (segura a toalha, espuma) — o número vira personagem. | G | Médio |

### 3.2 Vínculo — o pet como protagonista

| Ideia | Descrição | Esforço | Impacto |
|---|---|---|---|
| **Corações de afeto na cena** | 3 corações cheios conforme `pet_affection` (10/25/50) sob o nome do pet; nível novo = reação exclusiva + toast de “amizade”. | P | Alto |
| **Boas-vindas nominal** | Abrir o jogo com o pet favorito correndo até a estação e um “Caramelo sentiu sua falta!” (Loc). | P | Alto |
| **Renomear pet** | Tela de coleção → rename salvo no `GameState`. | P | Médio |
| **Preferência de carinho** | Cada pet ama um canto (cabeça/barriga); acertar o carinho favorito dá afeto em dobro — descobrível pelo jogador. | M | Médio |

### 3.3 Momentos guardáveis (retenção + share)

| Ideia | Descrição | Esforço | Impacto |
|---|---|---|---|
| **Polaroids** | Na celebração (e no spa completo) gera uma “foto” (composição canvas → textura) no álbum do pet; álbum vira aba da coleção. | M | Alto |
| **Álbum do Bairro** | 12 momentos raros (ex.: primeiro perfect com cada serviço) viram figurinhas com recompensa. | M | Médio |
| **Share de transformação** | Antes/depois do banho montado em cartão com logo → `ShareManager`. | M | Médio |

### 3.4 Sensorial — som e animação

| Ideia | Descrição | Esforço | Impacto |
|---|---|---|---|
| **Tema por sala** | 5 variações do loop (mesmo BPM; troca de instrumento) com crossfade igual ao de energia. | M | Alto |
| **Camadas de serviço** | Enquanto o utensílio está ativo: bolhas (banho), zumbido de lâmina (tosa), sopro (secagem) — synth procedural já existe (`_tone/_chime`). | M | Alto |
| **Vocalizes** | Latido/miado por porte na chegada e no carinho; fila “conversa” baixinho. | P | Alto |
| **Brilho de conclusão** | Sweep de luz no pet ao fechar o serviço + respingo ao entrar na banheira; pulsos de espuma já sincronizam com `beat_phase` — estender ao VFX de crítico. | P/M | Médio |
| **Milestones visuais** | Estação muda de cara nos níveis de `visual_milestones` (banheira dourada no 50 etc.) — o upgrade *aparece* na sala. | M | Alto |
| **Dia/noite ambiente** | `TimeManager` já existe; luz da janela e vagalumes noturnos nos backgrounds. | M | Médio |

### 3.5 Meta/retenção

| Ideia | Descrição | Esforço | Impacto |
|---|---|---|---|
| **Calendário de sequência** | 7 dias com recompensa crescente; perder dia não zera, só pausa (anti-punição). | M | Alto |
| **Passe da temporada visível** | Trilha grátis+premium do `pass.json` com cosméticos exclusivos por temporada. | M | Alto |
| **Pesquisa como árvore** | `research.json` em tela de árvore com pré-requisitos — meta de médio prazo legível. | M | Médio |
| **Conquistas com vitrine** | Conquista ganha vira troféu na parede da sala (cosmético de cenário). | P | Médio |

### 3.6 Acessibilidade e conforto (guarda-chuva)

Reduzir movimento (desliga shake/pulsos), modo daltônico para Perfect/Good,
“modo calmo” (sem camada de energia), tamanho de texto no painel de settings.
Esforço P–M, impacto em avaliação de loja.

## 4. O que NÃO fazer agora (protege o conquistado)

- Segunda moeda dura ou energia que trava sessão — o loop atual é honesto.
- Pay-to-progress: IAP só cosmético/conveniência (política de `core/ads`/`core/iap`).
- Conteúdo em massa antes do Vertical Slice (regra do ROADMAP): cada ideia acima
  entra como spike pequeno e só escala com gate de playtest.

## 5. Ordem sugerida para os próximos 3 sprints

1. **Sprint A (vínculo + ritmo):** corações de afeto na cena, boas-vindas nominal,
   sequência perfeita com pitch de SFX. (Tudo P — maior retorno por linha de código.)
2. **Sprint B (sensorial):** camadas de som por serviço, vocalizes, tema por sala.
3. **Sprint C (momentos):** polaroids + pedido do dia + milestones visuais da estação.

Cada sprint termina com o gate de sempre: 5 playtests curtos, “entendeu em <10 s?” e
“sorriu?”. Métricas de apoio: D1/D7, serviços/sessão, carinhos/sessão e upgrades/sessão
no `Analytics` já instrumentado.
