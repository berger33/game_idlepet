# Asset Manifest

| Arquivo | Uso | Origem | Resolução | Revisão |
|---|---|---|---:|---|
| `backgrounds/petshop_quintal.png` | banho, banheira profunda + 5 prateleiras vazias | ilustração gerada e curada para este projeto | 768×1376 | suporte calibrado para pet (540,840); sem texto/personagem |
| `backgrounds/petshop_tosa.png` | tosa, mesa elevada + 5 prateleiras vazias | ilustração gerada e curada para este projeto | 768×1376 | suporte calibrado para pet (540,810); sem texto/personagem |
| `backgrounds/petshop_secagem.png` | secagem, mesa acolchoada + 5 prateleiras | ilustração original gerada e curada | 768×1376 | suporte calibrado (540,820); secador de parede contextual |
| `backgrounds/petshop_perfume.png` | spa, pedestal acolchoado + 5 prateleiras | ilustração original gerada e curada | 768×1376 | suporte calibrado (540,1060); fundo também usado em menus |
| `backgrounds/petshop_estilo.png` | estilo, pufe elevado + 5 prateleiras | ilustração original gerada e curada | 768×1376 | suporte calibrado (540,1065); sem pet/texto embutido |
| `props/tool_*.png` (5) | sabonete, máquina, secador, perfume e laço | ilustrações originais geradas e recortadas/curadas para este projeto | 512×512 RGBA | transparência real, sombra, highlight, contorno; animação runtime |
| `stations/station_bathtub_rustic.png` | banho, capítulo 1 (quintal): tina rústica com faixas de madeira, espuma, pato de borracha e toalha | ilustração original gerada (2 candidatos, melhor por métricas) e recortada/curada (tools/normalize_station_art.py) | 440×314 RGBA | aro frontal fatiado em runtime para ocluir as patas do pet; sem texto |
| `stations/station_bathtub_spa.png` | banho, capítulo 2+: banheira de porcelana com torneira de cisne dourada, pétalas, espuma e toalha | ilustração original gerada (2 candidatos, melhor por métricas) e recortada/curada (tools/normalize_station_art.py) | 440×305 RGBA | elementos laterais fora da zona do pet; fatia frontal idem rústica |
| `stations/station_groom_table.png` | tosa, mesa de aço com tapete | ilustração original gerada e recortada/curada | 400×121 RGBA | topo ancorado na superfície do pet (pet_position.y) |
| `stations/station_drying_table.png` | secagem, mesa acolchoada com bocal de ar | ilustração original gerada e recortada/curada | 420×169 RGBA | topo ancorado na superfície do pet |
| `stations/station_spa_pedestal.png` | spa, pedestal com almofada | ilustração original gerada e recortada/curada | 300×179 RGBA | topo ancorado na superfície do pet |
| `stations/station_ottoman.png` | estilo, pufe rosa com botões | ilustração original gerada e recortada/curada | 340×110 RGBA | topo ancorado na superfície do pet |
| `stations/shelf_unit.png` | estante de utensílios, 5 pranchas de madeira | ilustração original gerada e recortada/curada | 216×780 RGBA | pranchas medidas e mapeadas em data/service_layouts.json (dados seguem a arte; snap uniforme 122px, desvio ≤3px) |
| `pets/*.png` coleção completa (50) | todos os 25 cães e 25 gatos do catálogo | ilustrações originais geradas e recortadas/curadas para este projeto | 512×512 RGBA | raça individualizada, transparência real; referências anexadas não foram incorporadas |
| fallback de segurança | runtime | desenho vetorial procedural original em GDScript | escalável | mantido apenas para defesa contra recurso ausente/corrompido |
| SFX/BGM | runtime | síntese procedural original | 22.050 Hz mono | sem arquivo/licença externa |

## Regras

- Cenários raster não contêm texto; títulos são localizados pelo jogo.
- Não inserir asset externo sem origem, licença e revisão de coerência.
- Antes de release, preservar arquivos-fonte/editáveis, revisar artefatos em 200% e comprimir com preset mobile após profile.
- Fontes finais não foram baixadas devido a erro SSL; usar fallback do Godot somente em desenvolvimento e empacotar OFL no gate indicado.
