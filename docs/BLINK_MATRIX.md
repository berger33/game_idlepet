# BLINK_MATRIX — piscada em todos os momentos, para todos os pets

## Auditoria do estado anterior (verificada por scan de pixels nos 500 PNGs)

- A piscada só existia como **overlay exclusivo**: `overlay_state = &"blink"` no idle
  seco e na reação de serviço. Consequência: pet **molhado, sujo ou peludo não
  piscava**; pior, quando a reação de blink disparava durante o serviço ela
  **substituía** o sprite molhado/sujo pelo seco de olhos fechados (flash seco).
- Scan `base × blink` nos 50 pets: 49 com diff 5–10% (só olhos ✓). **1 inconsistência:**
  `duke_husky/blink.png` com diff 36% (pose trocada — não é uma piscada).
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

## Lista completa do que criar (251 imagens 512×512 RGBA)

### Correção (1)
| Pet | Arquivo | Motivo |
|---|---|---|
| duke_husky | `art/pet_animations/duke_husky/blink.png` | pose trocada (diff 36%) — regenerar mantendo pose da base, só pálpebras fechadas |

### Fase 1 — estados longos de serviço (150)
Para **cada um dos 50 pets**: `dirty_blink.png`, `wet_blink.png`, `messy_blink.png`.
Cobrem banho (sujo→molhado), tosa (peludo) e secagem (molhado) — os momentos em que
o jogador mais olha para o pet.

### Fase 2 — reações (100)
Para cada pet: `sad_blink.png`, `dizzy_blink.png` (triste/tonto também piscam).

### Não criar (decisão documentada)
- `happy_*_blink`: olhos já fechados/felizes por construção.
- `tilt_*_blink`: janelas de 1,6s; piscada cairia raramente e custaria 100 imagens.
- `clean/groomed`: usam a base + `blink` (contrato original).

## Receita de geração por variante (lotes de 1 pet = 3–5 gerações)

Referências: `art/pets/<id>.png` (identidade) + `art/pet_animations/<id>/<estado>.png`
(condição). Mudar SOMENTE as pálpebras (fechadas, serenas); preservar pose, silhueta,
pelo, sujeira/umidade, baseline y=479, transparência real, 512×512, sem cenário/texto.

## QA por lote

`tools/scan_blink_variants.py`: para cada variante existente,
- diff(variante × estado-aberto) na faixa de olhos (0.5%–15%);
- diff(variante × blink-seco) > 0 quando estado != seco (garante que herdou a condição);
- alpha/opacos dentro do contrato (mesmos mínimos do verify_pet_animations).
Progresso rastreado em `data/pet_animation_production.json` → `pets[].blink_variants`
+ `summary.blink_*`. Um commit por lote para não perder o fio.
