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

Os 10 estados foram aprovados, normalizados e integrados. A primeira correção de `tilt_right` resolveu a orelha pontuda, mas repetiu a mesma direção de `tilt_left`; uma segunda tentativa também repetiu o ângulo. Ambas foram rejeitadas e não entraram no produto. A solução selecionada foi um espelhamento lossless do keyframe esquerdo já aprovado, garantindo inclinações realmente opostas, orelhas caídas e identidade consistente sem nova deriva generativa. O tracker contabiliza as 12 tentativas e registra a decisão de QA.

### Lote 03 — Mingau SRD branco

Os 10 estados foram aprovados, normalizados e integrados. As substituições resolveram os dois bloqueios: `blink` foi gerado sobre fundo sólido e ficou sem resíduos; `wet` ganhou volume reduzido, mechas encharcadas para baixo, cauda fina e leitura fria de pelo molhado. `tilt_left` foi aprovado e `tilt_right` deriva de espelhamento lossless para garantir oposição geométrica. Quatro alternativas posteriores foram revisadas, mas não selecionadas porque o conjunto já integrado preserva melhor a identidade e a uniformidade de estilo; o tracker contabiliza as 15 tentativas.

### Lote 04 — Thor Pinscher

Os 10 estados foram aprovados, normalizados e integrados. Duas tentativas geradas de `tilt_left` permaneceram centralizadas e foram rejeitadas; a versão final é o espelhamento lossless do `tilt_right` aprovado, garantindo oposição geométrica e preservando as orelhas grandes características. O molhado mantém pelo curto, liso e escuro; o messy usa tufos irregulares sem perder marcações pretas e castanhas. Sombras de chão geradas anteriormente foram removidas no QA de alfa. O tracker contabiliza 14 tentativas.

### Lote 05 — Mel Golden Retriever

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` deriva de espelhamento lossless do `tilt_left` aprovado para garantir oposição sem deriva. `dirty` preserva dourado sob poeira e lama, `wet` reduz volume e direciona mechas para baixo, `messy` amplia a pelagem irregular, e o par squash/air comunica antecipação e salto. A elevação momentânea de uma orelha em `happy_air` foi aprovada como movimento secundário exclusivo do salto, não como anatomia idle.

### Lote 06 — Frajola

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo aprovado. A máscara preta e branca, faixa branca central, peito/patas claros, olhos verdes e nariz rosa permanecem legíveis em todos os estados. `wet` escurece e achata a silhueta com gotas, `messy` expande pelos irregulares, `dirty` acinzenta áreas claras, e as emoções possuem poses imediatamente distinguíveis sem estrelas indevidas.

### Lote 07 — Fred Poodle

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. O estado `wet` reduz radicalmente o volume dos cachos em mechas escuras, pesadas e direcionadas para baixo, enquanto `messy` expande cachos assimétricos e embaraçados. `dizzy` usa olhos espiralados sem estrelas, e squash/air formam um arco de salto legível mantendo orelhas e pompom da cauda.

### Lote 08 — Amora Siamês

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Máscara, orelhas, patas e cauda seal, corpo creme e olhos azuis permanecem reconhecíveis em todos os estados. `wet` reduz a silhueta e transforma cauda/pelagem em mechas pesadas com gotas; `messy` expande intencionalmente o pelo pré-tosa sem perder os points siameses; dizzy, sad e blink têm leituras distintas e sem VFX indevido.

### Lote 09 — Nina Yorkshire

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. A pelagem sedosa cinza-aço e dourada permanece legível em todos os estados. `wet` estreita e escurece a silhueta com fios longos para baixo, `messy` cobre parcialmente a face com fios irregulares, e squash/air comunicam antecipação e salto. A queda de uma orelha em `dizzy` foi aprovada como instabilidade contextual, sem alterar a anatomia idle. Nove alternativas posteriores foram auditadas, mas não selecionadas porque o conjunto integrado manteve melhor squash, identidade molhada e uniformidade visual; todas as 18 tentativas permanecem contabilizadas.

### Lote 10 — Tigrinho Tabby

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. O M frontal e as listras da face, corpo, patas e cauda permanecem legíveis, junto ao peito claro e olhos oliva-dourados. `wet` estreita e escurece a pelagem em mechas com gotas, `messy` cria tufos irregulares, e dizzy/sad/squash/air possuem silhuetas emocionais distintas sem VFX indevido.

### Lote 11 — Bob Bulldog Francês

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Pelagem azul-cinza, focinho/peito creme, máscara, olhos castanhos e grandes orelhas de morcego permanecem reconhecíveis. `wet` cola e escurece o pelo curto com gotas, `messy` usa somente tufos curtos compatíveis com a raça, `dizzy` combina espirais e desequilíbrio sem estrelas, e squash/air comunicam peso compacto e salto.

### Lote 12 — Neve Angorá

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Olhos azuis, pelagem branca longa, orelhas pontudas e cauda-pluma gigante permanecem reconhecíveis. `wet` reduz radicalmente o volume em fios cinza, estreitos e pesados com gotas; `messy` adiciona tufos e comprimentos irregulares; dirty, sad, dizzy, blink e o arco squash/air têm leitura imediata sem VFX indevido.

### Lote 13 — Sol Border Collie

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. A faixa branca central, peito/patas claros, ponta branca da cauda e heterocromia azul/castanha permanecem legíveis. `wet` estreita e escurece a pelagem em mechas pesadas; uma poça gerada junto aos pés foi identificada e removida durante o QA de alfa, preservando apenas o pet e gotas corporais. `messy`, dizzy, sad e o arco squash/air mantêm anatomia atlética e leitura emocional clara.

### Lote 14 — Café Bombay

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas após uma resposta vazia do modelo ser repetida; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Pelagem quase preta com reflexos chocolate, olhos âmbar, face arredondada e cauda longa permanecem legíveis. `wet` aprofunda o preto, reduz volume e adiciona mechas pesadas/gotas; `messy` cria tufos irregulares; dizzy usa espirais sem estrelas, e squash/air têm silhuetas de antecipação e salto distintas.

### Lote 15 — Jade Spitz Alemão

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Pelagem dupla creme-branca, face de raposa, orelhas triangulares e cauda-pluma gigante permanecem reconhecíveis. `wet` colapsa radicalmente o volume em fios cinza-bege pesados e descendentes; `messy` amplia nós e comprimentos irregulares; dirty, sad, dizzy, blink e o arco squash/air mantêm leitura imediata e nenhum VFX indevido.

### Lote 16 — Pitanga Abissínio

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Pelagem ruddy/canela com ticking, olhos verdes, face em cunha, orelhas grandes, corpo esguio e cauda longa permanecem legíveis. `wet` cria superfície cobre escura, lisa e encharcada com gotas; `messy` usa tufos curtos compatíveis com a raça; dizzy, sad, blink e o arco squash/air mantêm silhuetas emocionais distintas sem VFX externo.

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
