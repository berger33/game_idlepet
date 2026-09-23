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

### Lote 17 — Bento Beagle

Os 10 estados foram aprovados, normalizados e integrados. Nove são gerações originais curadas; `tilt_right` é o espelhamento lossless do keyframe esquerdo. Sela preta, face/pernas castanhas, faixa branca, focinho/peito/patas/ponta da cauda claros, olhos avelã e orelhas longas permanecem reconhecíveis. `wet` cola e escurece o pelo curto com gotas; `messy` usa tufos breves compatíveis com a raça; dizzy, sad, blink e squash/air comunicam emoções diferentes sem VFX externo.

### Lotes 18–37 — atualização consolidada

O tracker `data/pet_animation_production.json` continua sendo a fonte auditável; o resumo abaixo acompanha a produção acelerada. O padrão consolidado é: 9 gerações originais + `tilt_right` como espelhamento lossless do keyframe esquerdo aprovado; `messy` com brief espinhoso/dentado (gate de rugosidade de contorno ≥ +63% vs base, respeitando pelo curto em raças de pelo curto); `wet` validado por paleta/brilho quando a pelagem neutra engana a correlação de matiz; chroma-key cirúrgico de franja com anel de borda e fundo medido por imagem, preservando sombreamento frio interior; caminho flood quando o GrabCut remove pelagem clara (Belinha) ou linhas de movimento (happy_air da Maya).

| Lote | Pet | Tent. | Observações-chave de QA |
|---|---|---:|---|
| 18 | Azul (Azul Russo) | 10 | 1º happy_air com painel bege embutido rejeitado; chroma key + hole filling |
| 19 | Paçoca (Dachshund) | 10 | Primeiro lote 100% aprovado na primeira leva |
| 20 | Lua (Maine Coon) | 10 | tilt_right regenerado (caption embutido); dizzy com tint menta intencional |
| 21 | Kiko (Pug) | 10 | sad desenrola a cauda como linguagem corporal |
| 22 | Sushi (Bobtail Jap.) | 11 | sad regenerado por perder as manchas gengibre |
| 23 | Cacau (Labrador) | 10 | happy_air concluído no turno seguinte ao limite por turno |
| 24 | Juma (Bengal) | 10 | blink regenerado preservando rosetas e cauda anelada |
| 25 | Tupã (Lobo-guará) | 10 | happy_squash regenerado (orelhas enormes caídas + juba) |
| 26 | Aurora (Ragdoll) | 10 | sad regenerado (orelhas caídas, lágrima, cauda envolta) |
| 27 | Gaia (Samoieda) | 10 | sad regenerado (cauda desenrolada e caída) |
| 28 | Nox (Sphynx) | 12 | tilts regenerados com lean forte (IoU tl-vs-tr 0.335) |
| 29 | Rio (Savannah) | 10 | dizzy/sad/blink aprovados no turno seguinte |
| 30 | Estrela (Khao Manee) | 10 | flood path; olhos ímpares preservados em todos os estados |
| 31 | Pipoca (Corgi) | 10 | sad reancorado lossless na baseline 478; chroma-key do fundo |
| 32 | Zeca (Schnauzer) | 10 | messy retake (+23% largura, IoU 0.600); chroma-key preserva pelagem prata |
| 33 | Belinha (Maltês) | 11 | flood path preserva o sombreamento cfd8dc oficial; messy retake +91% |
| 34 | Duke (Husky) | 10 | tilt retake (lean −47.3); wet aprovado por paleta; olhos azul-gelo |
| 35 | Lola (Boxer) | 10 | tilt retake (±40.6); brief de pelo curto no messy (+75%) |
| 36 | Nico (Aussie merle) | 9 | Lote limpo, sem retakes; identidade merle por bandas de cinza |
| 37 | Maya (Akita) | 10 | tilt com dupla referência; urajiro preservado; sad flagged p/ art lead |

Itens abertos de revisão humana: `sad` da Maya (leitura contida, cauda permaneceu enrolada) e a métrica de lean do tilt da Maya (inflada pela cauda enrolada) — ambos registrados nas `qa_notes` do tracker.

### Lotes 38–50 — fechamento do catálogo (FASE 8 COMPLETA: 500/500)

Os lotes 38–40 fecharam os cachorros (40/40) e os lotes 41–50 introduziram os dez gatos, que concentraram os casos-limite do catálogo: bases esguias (Zara 309×449, Íris 247×446), bases diagonais com cabeça no extremo (Olívia −47.8, Simba −37.9, Zara +63.8, Lilo +50.5) e pelagens quase-neutras em que a correlação de matiz falha e a paleta oficial k-means vira o gate (Yuki prata, Zara lilac-point, Odin azul-cinza — precedente merle). O `tilt_right` por espelhamento, padrão dos lotes 18–40, foi progressivamente substituído: par 100% gerado (Lilo, primeiro do catálogo), edit direto de um estado aprovado preservando pose (Zara edit-do-sad, Íris edit-do-sad_v2), dupla referência com verificação de pose/aspect-ratio do par (Mimi, Odin) e espelho apenas com exceção documentada (Zara +12.7, Odin +7.9 — precedentes Bob ±13). `happy_air` consolidou o override para o caminho flood em 9 lotes consecutivos (Zara→Cléo): o GrabCut funde as linhas de movimento no corpo; o flood preserva o corpo aéreo e os rastros alongados. O `blink` dos gatos passou a ser validado por diff-clustering (par simétrico nos olhos), técnico superior ao diff de pupila escura quando olhos cobre/face colorida dominam a banda facial. Registros próprios de chão por base curta: Otto 411, Mimi 400, Apolo 465, Simba 434, Odin 409, Zara 481, Lilo 465 — os aterrados de cada pet alinham com a base embarcada para os crossfades dirty→clean e messy→clean.

| Lote | Pet | Tent. | Observações-chave de QA |
|---|---|---:|---|
| 38 | Otto (Basset Hound) | 9 | Base curta bottom 411 (registro próprio); aterrados re-registrados 411±3; messy +63% (piso da família); base flutua ~68px (flag art lead) |
| 39 | Kiara (Doberman) | 9 | Identidade por tan points (hue fraco em pelo preto); rótulos tl/tr corrigidos por troca lossless; happy_squash re-registrado 380→478 |
| 40 | Apolo (Boiadeiro Bernês) | 9 | Lendário; bandas tricolores + marcas ferrugem; wet com colapso forte (cov 0.496→0.356); blink validado por eye-shine (face preta anula gray diff) |
| 41 | Mimi (Persa) | 10 | 1º gato; base curta bottom 400; wet V 211→165; tilt por dupla referência (base + Lola); par fraco documentado (rel tr −4.3) |
| 42 | Yuki (Scottish Fold) | 9 | Assinatura orelhas dobradas = 0 picos no topo (needle test); happy_air override INVERSO p/ flood (grab destruiu 19 motion lines); tilt rel −52.0 |
| 43 | Olívia (Calico) | 14 | Tilt em 6 tentativas (cabeça da base no extremo esquerdo); resolução por convenção absoluta; seleção invertida (flood em 8 estados); messy +214% (recorde absoluto) |
| 44 | Simba (Norueguês da Floresta) | 9 | Base curta/larga bottom 434; wet veio baixo/largo nativamente (zero rescale); tilt de 1ª; blink com face larga (filtro de par dx<240) |
| 45 | Lilo (Munchkin) | 11 | 1ª base com cabeça à direita (espelho não serve) → PAR 100% GERADO (tl rel −26.6 / tr +46.9); wet única com cov subindo |
| 46 | Zara (Oriental Shorthair) | 13 | Base mais esguia (cov 0.239) e mais diagonal (+63.8) do catálogo; tr fechado por edit-do-sad c/ exceção documentada (+12.7); wet clareia (V 164→183, brilho especular) |
| 47 | Cosmo (Sagrado da Birmânia) | 9 | Luvas brancas + olhos azuis preservados; 1ª base quase simétrica dos gatos → primeiro par totalmente válido nas 2 direções (tl −24.3/espelho +24.3) |
| 48 | Íris (Cornish Rex) | 13 | Base mais esguia (247×446); orelhas gigantes (34 spikes); tr no piso exato por edit-do-sad_v2; sad v1 rejeitado por escala → novo gate de cov relativo |
| 49 | Odin (Nebelung) | 11 | Azul-cinza quase-neutro (paleta oficial B>G>R); tr dual-ref rejeitado por pose em pé (ar 0.98 vs 0.68) → espelho c/ exceção; wet 74 comps (recorde de gotas) |
| 50 | Cléo (Mau Egípcio) | 9 | Gate spots ≥40 (base 72 manchas; estados 64–150); tilt espelhado mais forte (±111.0); blink IoU 0.980 (recorde); zero retakes — fechamento limpo |

Gates de QA criados ou refinados nesta era: needle test para orelhas dobradas (Yuki); gate de escala `sad`/`dizzy` cov < base×1.35 (Íris, refinamento relativo do cov<0.40); contagem de manchas da assinatura da raça (Cléo); verificação obrigatória de pose/aspect-ratio do par tilt além do piso de lean (Odin); filtro de par de olhos por largura de face (Simba). Recorde do catálogo em `messy`: Olívia +214%.

Itens abertos de revisão humana: re-ground lossless da base do Otto (e re-registro dos 10 estados como uma mudança dedicada) — a base renderiza ~68px acima da baseline 479 das demais; `sad` da Maya e métrica de lean inflada (cauda enrolada), ambos pré-existentes. Todos os demais registros próprios de chão (Mimi/Apolo/Simba/Odin/Zara/Lilo) alinham os aterrados com a base embarcada por design e não exigem ação.

### Verificação funcional automatizada

`tools/verify_pet_animations.py` (executado no CI) confere o contrato ponta a ponta: 50 pets × 10 estados `qa_passed`/`integrated` no tracker com resumo recalculado; `PET_STATE_NAMES` do renderer idêntico ao contrato; gatilho funcional para cada um dos 10 estados no `PetShopCanvas.gd`; catálogo `data/pets.json` ↔ tracker ↔ diretórios ↔ sprites base sem órfãos; e os 500 PNGs válidos (assinatura, 512×512 RGBA, transparência real, conteúdo e margens seguras) e rastreados no git. Orçamento de textura medido no fechamento: 500 estados = 158,7 MB (média 310 KB, mín. 174 KB, máx. 442 KB), mais 13,5 MB das 50 bases — para o export final, avaliar atlas/compressão (WebP/ETC2) no Godot conforme item LOW do backlog.

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
- Produção completa dos 50 lotes: 500/500 imagens `qa_passed`, 50/50 pets integrados (518 tentativas; detalhes por lote nas seções acima e nas `qa_notes` do tracker).
- Verificação funcional automatizada dos 500 PNGs no CI (`tools/verify_pet_animations.py`): contrato tracker→renderer→catálogo→arquivos.
- Orçamento de textura medido: 158,7 MB nos 500 estados (média 310 KB) + 13,5 MB nas 50 bases.

### MEDIUM

- Ajustar amplitudes por temperamento e `reduced_particles`.
- Validar escala, apoio, oclusão e conforto tátil no Godot 4.7.2 para Windows.
- Avaliar atlas/compressão de textura (WebP/ETC2) no export para reduzir os ~172 MB de arte de pet.

### LOW

- Refinar cadências raras de idle após playtest da Vertical Slice.
