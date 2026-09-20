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

## Lista do que criar — 245 imagens 512×512 RGBA (CRIADAS)

Para **49 dos 50 pets** (todos exceto `duke_husky`, ver exceção abaixo), cinco
variantes cada: `dirty_blink.png`, `wet_blink.png`, `messy_blink.png`,
`sad_blink.png`, `dizzy_blink.png` em `art/pet_animations/<pet>/`.

### Exceção documentada (1 pet)
| Pet | Arquivo | Decisão |
|---|---|---|
| duke_husky | variantes `*_blink` | **não criadas.** O `blink.png` autoral tem pose trocada (diff 36%, drift não rígido — medido por SAD de janela: offsets batem no teto da busca, alinhamento impossível por composição); geração de imagem devolveu 1024×1024 RGB sem alpha duas vezes. O original foi **mantido** (piscada expressiva aceitável no seco) e o pet ficou fora da matriz de variantes: pisca no seco, não pisca durante estados. Ferramentas tratam a exceção (`EXCLUDED_PETS`). |

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
