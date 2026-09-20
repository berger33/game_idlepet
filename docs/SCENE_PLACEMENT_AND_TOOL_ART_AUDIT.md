# Auditoria completa — apoio dos pets, cenários e utensílios

## V2 — mobiliário funcional por código (supera a versão pintada)

**Problema relatado:** com a troca de cenário, pets ficavam fora da banheira e utensílios desalinhados das prateleiras pintadas. Causa raiz: três fontes de posição divergentes (const `SERVICE_PET_POSITIONS` do canvas, `data/service_layouts.json`, e a calibração da auditoria V1) somadas a móveis que mudavam de lugar em cada ilustração.

**Contrato V2 (corrente):**

- **Mobiliário funcional desenhado por código** (`core/gameplay/StationArt.gd`): estante de utensílios (fundo translúcido + pranchas de madeira), cinco estações (banheira com borda frontal que oclui as patas, mesa de tosa, maca de secagem, pedestal de spa, otomana) e placa do título. Geometria determinística — alinhamento garantido por construção em qualquer cenário.
- **Fonte única de layout:** `data/service_layouts.json` via `ContentDB.service_layout()`; o canvas não tem mais constantes de posição/prateleira.
- **`pet_position` é a âncora dos PÉS** (baseline 479/512 aplicada no draw): superfície da estação = Y do pet, idêntico nos cinco serviços (540, 1160). Hit test de carinho e spotlight usam `pet_focus()` (centro do corpo, −170px).
- **Prateleiras uniformes** (centros dos utensílios): 560, 730, 900, 1070, 1240 — mesmos valores nos cinco serviços; a estante desenhada usa exatamente esses Y (+34px de drop da prancha).
- **Backgrounds regenerados como cenário ambiente** (768×1376): parede direita limpa para a estante (verificação programática de densidade de bordas: 7–37% da densidade global) e piso central livre para a estação. Nenhum mobiliário funcional pintado.
- **Ordem de desenho:** fundo → placa/título → estante → cosméticos de parede → utensílios → estação → pet → borda frontal da banheira → VFX.
- **HUD de ação enxugado:** os dois botões grandes de upgrade saíram do HUD; um botão redondo no canto superior direito (ícone procedural `upgrades.png`, pulso quando há melhoria comprável) abre o painel de melhorias do MetaPanel (estação + 5 utensílios, com moedas).

**Defesas de regressão V2:** `tools/smoke_interact.gd` (CI, Godot 4.7.2) afirma o contrato espacial em runtime (pés em 540,1160; 5 prateleiras; utensílio centrado na prancha) e o ciclo do painel de melhorias; testes estáticos exigem as chamadas `StationArt.*` no canvas, o botão `upgrades_button` e proíbem o retorno dos botões grandes; `tools/compose_preview.py` lê o JSON como fonte única (âncora de pés) para mock visual offline.

---

## V1 — histórico (mobiliário pintado nos backgrounds)


## Falha confirmada

Os cenários antigos não compartilhavam um contrato espacial. Banho e tosa possuíam estação, enquanto secagem, perfume e estilo deixavam o pet sobre piso/tapete. A posição global única `(540,930)` não garantia contato com nenhum móvel. Além disso, a coluna de ferramentas usava o mesmo espaçamento em artes cujas prateleiras tinham alturas diferentes. Por fim, os utensílios eram polígonos runtime simples e não atingiam acabamento comercial.

## Contrato espacial corrigido

Todos os backgrounds são 768×1376 e renderizam integralmente no canvas 1080×1920, sem crop/estiramento parcial. Cada sala agora foi reconstruída com um suporte central cuja superfície coincide com a base do pet:

| Nível | Serviço | Suporte obrigatório | Centro do pet |
|---:|---|---|---:|
| 1 | Banho | banheira profunda com cuba/rim visível | (540,840) |
| 3 | Tosa | mesa de grooming elevada | (540,810) |
| 5 | Secagem | mesa acolchoada sob secador | (540,820) |
| 7 | Perfume | pedestal de spa acolchoado | (540,1060) |
| 10 | Estilo | pufe/plataforma de styling | (540,1065) |

O corpo, sua sombra de contato e o suporte foram calibrados em conjunto. O pet nunca usa piso vazio como estação.

## Prateleiras por sala

As prateleiras são parte da ilustração raster, não geometria desenhada por código. Cada background possui cinco áreas de apoio no lado direito. Como perspectiva e móveis mudam entre salas, cada serviço agora tem seu próprio vetor de alturas, em vez de reutilizar uma coluna genérica:

- Banho/Tosa: 235, 390, 545, 700, 855.
- Secagem: 330, 500, 670, 840, 1010.
- Perfume: 310, 500, 690, 880, 1070.
- Estilo: 290, 470, 650, 830, 1010.

A hit area usa a mesma função `_tool_position()` utilizada no desenho. Portanto, imagem, clique, drag e posição de retorno não podem divergir.

## Arte comercial dos utensílios

Os cinco desenhos procedurais foram substituídos por sprites 512×512 RGBA com transparência real:

- Sabonete: frasco coral/turquesa, pump, vidro, bolhas e reflexo.
- Máquina: corpo turquesa, grip coral, lâmina metálica e highlight.
- Secador: volume, nozzle, outline, brilho e sombra.
- Perfume: vidro lavanda, atomizador dourado, laço e reflexo.
- Laço: tecido com dobras, costura dourada e gema turquesa.

Todos possuem contorno marrom coerente, iluminação superior, sombreamento e contact shadow. Em runtime os objetos têm bob idle; ao serem retirados da prateleira, aumentam de escala, inclinam, pulsam e recebem brilho. O aro de progresso permanece acoplado ao sprite arrastado. Partículas e sons continuam específicos por ação.

## Progressão das salas

A progressão visual e mecânica usa os mesmos gates: níveis 1, 3, 5, 7 e 10. Ao desbloquear um serviço, sua sala entra no ciclo de pedidos com workstation, prateleiras, ferramenta, VFX, áudio, upgrade e recompensa correspondentes. O contrato está registrado em `data/service_layouts.json` e validado automaticamente.

## Defesas de regressão

- Exatamente cinco layouts e cinco prateleiras por layout.
- Gates estritamente 1/3/5/7/10.
- Background referenciado deve existir.
- Cada ferramenta deve ser PNG RGBA, ter transparência e mais de 100 KB.
- `_draw_tool()` deve usar textura; polígonos de ferramenta são proibidos pelo teste.
- Hit test e desenho compartilham `_tool_position()`.

## Limite de validação

A auditoria geométrica foi feita contra a resolução-fonte e o canvas lógico, e os recursos/contratos passam nos testes estáticos. A confirmação perceptual final (oclusão do rim da banheira, suporte sob patas e alinhamento fino de cada sprite) ainda deve ser feita no Godot 4.7.2 em tela cheia, pois não há engine compatível disponível no ambiente automatizado.
