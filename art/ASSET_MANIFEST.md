# Asset Manifest

| Arquivo | Uso | Origem | Resolução | Revisão |
|---|---|---|---:|---|
| `backgrounds/petshop_quintal.png` | banho, banheira profunda + 5 prateleiras vazias | ilustração gerada e curada para este projeto | 768×1376 | suporte calibrado para pet (540,840); sem texto/personagem |
| `backgrounds/petshop_tosa.png` | tosa, mesa elevada + 5 prateleiras vazias | ilustração gerada e curada para este projeto | 768×1376 | suporte calibrado para pet (540,810); sem texto/personagem |
| `backgrounds/petshop_secagem.png` | secagem, mesa acolchoada + 5 prateleiras | ilustração original gerada e curada | 768×1376 | suporte calibrado (540,820); secador de parede contextual |
| `backgrounds/petshop_perfume.png` | spa, pedestal acolchoado + 5 prateleiras | ilustração original gerada e curada | 768×1376 | suporte calibrado (540,1060); fundo também usado em menus |
| `backgrounds/petshop_estilo.png` | estilo, pufe elevado + 5 prateleiras | ilustração original gerada e curada | 768×1376 | suporte calibrado (540,1065); sem pet/texto embutido |
| `props/tool_*.png` (5) | sabonete, máquina, secador, perfume e laço | ilustrações originais geradas e recortadas/curadas para este projeto | 512×512 RGBA | transparência real, sombra, highlight, contorno; animação runtime |
| `pets/*.png` lotes 1–2 (20) | 10 pets iniciais + Bob, Neve, Sol, Café, Jade, Pitanga, Bento, Azul, Paçoca e Lua | ilustrações originais geradas e recortadas/curadas para este projeto | 512×512 RGBA | raças individualizadas; nenhuma imagem de referência foi incorporada |
| 30 pets restantes | runtime temporário | desenho vetorial procedural original em GDScript | escalável | fallback preservado até os próximos três lotes de arte |
| SFX/BGM | runtime | síntese procedural original | 22.050 Hz mono | sem arquivo/licença externa |

## Regras

- Cenários raster não contêm texto; títulos são localizados pelo jogo.
- Não inserir asset externo sem origem, licença e revisão de coerência.
- Antes de release, preservar arquivos-fonte/editáveis, revisar artefatos em 200% e comprimir com preset mobile após profile.
- Fontes finais não foram baixadas devido a erro SSL; usar fallback do Godot somente em desenvolvimento e empacotar OFL no gate indicado.
