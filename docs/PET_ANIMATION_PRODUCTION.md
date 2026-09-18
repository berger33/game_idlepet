# Produção de animação e estados dos 50 pets

## Objetivo e decisão de arquitetura

Cada raça terá leitura emocional e de cuidado própria, sem transformar o catálogo em uma sequência cara e inconsistente de frames raster. A solução comercial é híbrida:

1. **Arte autoral por pet** somente quando anatomia, pelo ou expressão realmente muda.
2. **Interpolação em runtime a 60 fps** para movimento, peso e transições.
3. **VFX reutilizável** para partículas que não pertencem à anatomia do animal.

O contrato reduz a proposta bruta de aproximadamente 20 imagens por pet para 10 estados anatômicos por pet, além da base limpa já existente. O escopo visual não foi removido: os demais estados são mais fluidos, leves e consistentes quando executados pelo renderer. O total planejado é 500 novos PNGs, não 1.000. Isso reduz tamanho instalado, memória de textura, deriva de identidade e trabalho de manutenção.

A fila autoritativa e auditável está em `data/pet_animation_production.json`. Cada lote contém exatamente um pet e no máximo 10 gerações.

## Contrato de arte por pet

A base limpa/arrumada é `art/pets/<pet_id>.png`. Os estados ficam em `art/pet_animations/<pet_id>/<state>.png`:

| Estado | Significado visual | Gatilho permitido |
|---|---|---|
| `dirty` | Sujeira, pelo opaco e pequenos pontos de lama | Início do banho, antes de progresso de limpeza |
| `wet` | Pelo escuro, liso, caído e com silhueta molhada | Durante banho após molhar e durante início da secagem |
| `messy` | Pelo crescido, irregular e desalinhado | Início da tosa, antes do progresso de arrumação |
| `tilt_left` | Curiosidade natural à esquerda com pés ancorados | Idle contextual, alternado com centro/direita |
| `tilt_right` | Curiosidade natural à direita com pés ancorados | Idle contextual, alternado com centro/esquerda |
| `happy_squash` | Antecipação comprimida de alegria | Início de recompensa ou carinho bem-sucedido |
| `happy_air` | Stretch no ar, patas sem apoio | Ápice do bounce feliz, nunca como idle |
| `dizzy` | Expressão sem foco e postura instável | Somente reação explícita de tontura/sobrecarga |
| `sad` | Cabeça/orelhas baixas, expressão de falha gentil | Falha de serviço; combinado com darkening runtime |
| `blink` | Pálpebras fechadas, pose limpa preservada | Piscada curta em idle ou cuidado confortável |

`clean` não é duplicado: após banho usa a base. `groomed` não é duplicado: após tosa usa a base. As imagens são 512×512 RGBA, corpo inteiro, transparência real, sem cenário, texto, acessórios ou marca d'água. O baseline normal é `y=479`; a pose aérea preserva margens e recebe deslocamento vertical pelo runtime.

## Movimento e VFX em runtime

- **Respiração:** escala sutil com pés fixos; amplitude e cadência por temperamento.
- **Inclinação:** crossfade curto entre base, `tilt_left` e `tilt_right`; sem rotação rígida do corpo inteiro.
- **Squash/stretch e felicidade:** antecipação `happy_squash`, arco eased, ápice `happy_air`, aterrissagem e settle.
- **Tontura:** `dizzy` com vibração amortecida; sem estrelas.
- **Falha:** `sad` com escurecimento gradual, hold curto e recuperação; não altera permanentemente a arte.
- **Molhado:** `wet` mais tint azul discreto. O tint complementa, mas nunca substitui, o pelo caído.
- **Entrada/saída:** antecipação, aceleração/desaceleração e leve squash; pés ancorados ao suporte da estação.
- **Transições de cuidado:** dirty→clean, messy→clean e wet→clean usam crossfade mascarado/progresso, sem troca abrupta.
- **Corações:** somente `react_to_touch`, isto é, carinho direto.
- **Espuma:** somente ferramenta de sabonete ativa em banho e em contato válido.
- **Pelo solto:** somente máquina/pente ativo em tosa e em contato válido.
- **Perfume:** somente ferramenta de perfume ativa e em contato válido.
- **Estrelas:** somente conquista ou recompensa realmente especial; conclusão comum usa alegria sem estrelas.

`reduced_particles` reduz contagem, nunca a comunicação essencial do estado.

## Máquina de estados e prioridades

Prioridade visual, da maior para a menor:

1. saída/entrada;
2. falha;
3. recompensa especial;
4. reação direta (carinho/tontura);
5. ferramenta de serviço válida;
6. transição de condição do pelo;
7. idle, respiração, inclinação e piscada.

Eventos de prioridade maior interrompem de forma amortecida. Ao terminar, o pet retorna ao estado de condição atual, não necessariamente à base. Timers e curva de blend devem ser determinísticos; partículas podem variar visualmente sem alterar gameplay.

## Produção, QA e rastreabilidade

Para cada lote:

1. Carregar a base do pet como referência de identidade.
2. Gerar exatamente os 10 estados, nunca mais de 10 imagens no turno.
3. Preservar os originais temporariamente fora do Git.
4. Remover fundo, normalizar com `tools/normalize_pet_state.py` e produzir RGBA 512×512.
5. Revisar contact sheet sobre fundo colorido: raça, identidade, pose, alpha, crop e significado.
6. Atualizar os campos de geração, normalização, QA e integração no tracker.
7. Rodar testes, validator, lint/format e auditoria Git antes do commit.

### Lote 01 — Caramelo

Concluídos, aprovados visualmente e integrados os 10 estados. O conjunto mantém a paleta e a leitura do vira-lata caramelo; `messy` aumenta a silhueta, `wet` achata e escurece o pelo, e as expressões são distintas sem VFX indevido. O carregamento possui fallback seguro: pets cujos lotes ainda estejam na fila continuam usando a base comercial e a deformação runtime sem quebrar o jogo.

### Lote 02 — Luna Shih-tzu

Nove estados foram aprovados, normalizados e preservados. `tilt_right` foi rejeitado na revisão porque a geração transformou uma orelha em uma ponta ereta incompatível com a silhueta do Shih-tzu. O arquivo rejeitado não entrou no produto. O tracker registra a tentativa e bloqueia corretamente geração completa, QA e integração até uma nova geração desse único estado. O limite de 10 imagens desta rodada impediu a correção imediata; ela é a primeira ação do próximo lote de geração.

## Backlog

### CRITICAL

- Validar no Godot 4.7.2 para Windows o parser, os pivôs e todas as transições em movimento; o executável não está disponível neste ambiente.

### HIGH

- Integrar e revisar cada novo lote sem alterar o fallback dos pets ainda pendentes.
- Adicionar testes de cena/runtime para os gatilhos exclusivos quando o runner Godot estiver disponível.

### Concluído nesta fundação

- Carregamento seguro de estados com fallback por pet.
- Pivô inferior, blends de condição e máquina determinística sem quebrar serviços.
- Dirty→wet→clean, messy→clean e wet→clean ligados ao progresso válido.
- Entrada, saída, bounce com squash/stretch e recuperação de falha.
- Corações exclusivos do carinho; partículas exclusivas da ferramenta correta.
- Estrelas removidas do styling e da conclusão comum; reservadas a Perfect/combo especial.

### MEDIUM

- Gerar e revisar os 49 lotes restantes na ordem do tracker.
- Ajustar amplitudes por temperamento e `reduced_particles`.
- Validar escala, apoio, oclusão e conforto tátil no Godot 4.7.2 para Windows.

### LOW

- Medir orçamento real de textura/export após os primeiros cinco pets integrados.
- Refinar cadências raras de idle após playtest da Vertical Slice.
