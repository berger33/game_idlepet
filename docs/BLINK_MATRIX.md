# BLINK_MATRIX — piscada em todos os momentos, para todos os pets

## Auditoria do estado anterior (verificada por scan de pixels nos 500 PNGs)

- A piscada só existia como **overlay exclusivo**: `overlay_state = &"blink"` no idle
  seco e na reação de serviço. Consequência: pet **molhado, sujo ou peludo não
  piscava**; pior, quando a reação de blink disparava durante o serviço ela
  **substituía** o sprite molhado/sujo pelo seco de olhos fechados (flash seco).
- Scan `base × blink` nos 50 pets: 49 com diff 5–10% (só olhos ✓). **1 inconsistência:**
  `duke_husky/blink.png` com diff 36% (pose trocada — piscada expressiva autoral).
- Todos os estados `dirty/wet/messy/sad/dizzy` diferem da base (nenhum estado invisível).

## Arquitetura nova (código já no lugar)

- **Camada de blink independente** (`PetShopCanvas`): pulso global (fase 4.7s, janela
  0.13s, offset por pet via hash para o elenco não piscar em uníssono) desenhado POR
  CIMA de overlay/second state.
- **Variante por estado dominante:** se o pet está `wet`, a piscada usa
  `wet_blink.png`; `dirty`→`dirty_blink`; `messy`→`messy_blink`; `sad`/`dizzy` idem.
  Sem variante no disco → **não pisca naquele estado** (nunca flash seco). Carregamento
  gracioso via `ResourceLoader.exists` (nomes novos em `PET_STATE_NAMES`).
- Reação `&"blink"` (carinho/serviço confortável) virou `blink_force_time` (pulso da
  camada), não mais overlay substituto. Piscada de idle saiu da cadeia de overlays.
- `happy_squash/happy_air` não piscam por cima (olhos já fechados/felizes).

## Lista do que criar — 250 imagens 512×512 RGBA (CRIADAS)

Para **os 50 pets**, cinco
variantes cada: `dirty_blink.png`, `wet_blink.png`, `messy_blink.png`,
`sad_blink.png`, `dizzy_blink.png` em `art/pet_animations/<pet>/`.

### Caso especial resolvido: duke_husky

O `blink.png` autoral do duke tem diff 36% contra a **referência seca** — a
exclusão anterior nasceu daí. Reauditoria: o blink **alinha com os sprites de
estado** (bbox de silhueta idêntico ao dirty, pálpebras ∪ 36x12 em
(169,176)/(251,176) vs olhos do dirty em (172,166)/(247,166)); quem não alinha
é a referência seca (bbox 245px vs 325px — pose própria). Como cada estado
também foi gerado com pose própria, os olhos mudam de posição/tamanho por
estado. Solução (`compose_duke_state`): olhos localizados por estado por
análise de pixels (blob escuro/azul + brilho do olho como furo de alpha no
wet; rastros de lágrima e espiral de tontura no sad/dizzy), pálpebra autoral
do blink colada **por olho**, escalada para a abertura do olho daquele estado
(`DUKE_EYES`), grade de cor medido na banda de fronteira da máscara (costura
contínua por construção) e lágrimas do sad preservadas acima da pálpebra
fechada. Seam medido na fronteira: 2–24 — dentro da faixa das variantes em
produção dos outros 49 pets (5,6–31,7).

### Não criar (decisão documentada)
- `happy_*_blink`: olhos já fechados/felizes por construção.
- `tilt_*_blink`: janelas de 1,6s; piscada cairia raramente e custaria 100 imagens.
- `clean/groomed`: usam a base + `blink` (contrato original).

## Método de produção: composição determinística (não geração)

Geração de imagem foi testada e **rejeitada**: deriva de pose/escala de 56–94% e
quebra de contrato (1024 RGB sem alpha). A pipeline `tools/make_blink_variants.py`
compõe cada variante a partir dos sprites existentes, idempotente e auditável:

1. `eye_mask`: diff `base × blink` @256 (alpha>24 ou RGB>40) ∩ interior da silhueta
   (MinFilter 3) → componentes conexos (mantém px≥12, bbox≤45% da tela — descarta
   anel de outline) ∩ zona dos olhos (x 12–88% da silhueta, topo→60% da altura;
   fallback 48% quando a máscara estoura o teto, ex. rosto expressivo da yuki).
2. Upscale NEAREST p/ 512 + MaxFilter 9 (pálpebra cobre a íris inteira).
3. `grade_factor`: média RGB do estado ÷ média da base na bbox da máscara (+pad 10),
   clamp 0.85–1.15 — a pálpebra herda o grading de molhado/sujo/peludo.
4. Cola o `blink` gradado sobre o estado aberto usando a máscara → alinhamento
   perfeito por construção (mesmos pixels de pose/outline/gotas/sujeira).
5. **duke_husky** (composição por estado, `compose_duke_state`): por olho, o
   blink é escalado por (largura/altura da abertura do olho do estado ÷ a do
   dirty) e transladado para que o arco da pálpebra caia no ponto autoral
   (centro do olho + (∓3.5,+11)); máscara = elipse 25·sx × 24·sy com feather
   2.5; grade de cor = banda de fronteira e∈(1.02,1.5) só com pelo claro em
   ambos os lados (exclui lágrima/íris azul-escura e traço), clamp 0.70–1.35.

## QA (rodado no lote final)

- `tools/scan_blink_variants.py`: para cada variante, diff(variante × estado-aberto)
  na faixa de olhos (0.5%–18%); variante ≠ estado-aberto (não idêntica); heredou a
  condição (diff vs blink-seco > 0). Progresso em
  `data/pet_animation_production.json` → `pets[].blink_variants` + `summary`.
- `tools/verify_pet_animations.py`: as variantes entraram no **contrato CI** —
  arquivos esperados por pet + formato 512 RGBA + renderer usa as variantes.
  0 erros / 0 warnings no lote final.
- Inspeção visual em folhas `.preview/blink_*.png` (gotas de molhado intactas,
  sujeira/pelo herdados, pálpebras fechadas).
