# Produção de arte dos 50 pets

## Direção visual

Os anexos do usuário foram usados apenas para compreender a linguagem desejada: chibi/kawaii, olhos expressivos, corpo inteiro sentado e leitura imediata da espécie. Nenhum pixel, marca d'água ou composição dos anexos foi incorporado. Todos os sprites entregues são gerações originais curadas para o projeto.

Contrato de produção:

- Corpo inteiro sentado, vista frontal ou três-quartos.
- Raça reconhecível pela silhueta, orelhas, focinho, pelagem, cauda e marcações.
- Olhos grandes e úmidos sem apagar diferenças anatômicas.
- Contorno marrom quente, pintura em camadas, highlight superior e blush discreto.
- Sem coleira/acessório para não conflitar com cosméticos futuros.
- 512×512 RGBA com transparência real e margens seguras.
- Sem texto, frame, fundo ou marca d'água.

## Lote 1 concluído

1. Caramelo — vira-lata caramelo.
2. Luna — Shih-tzu.
3. Mingau — SRD branco.
4. Thor — Pinscher.
5. Mel — Golden Retriever.
6. Frajola — tuxedo/frajola.
7. Fred — Poodle.
8. Amora — Siamês.
9. Nina — Yorkshire.
10. Tigrinho — tabby/tigrado.

Cada sprite foi recortado por segmentação, normalizado para 512×512, convertido para RGBA e auditado para canal alfa. O renderer carrega automaticamente `art/pets/<id>.png`; pets ainda sem sprite permanecem no fallback vetorial, portanto o build não quebra durante a produção incremental.

## Animação runtime

Embora cada imagem-base seja estática, o renderer adiciona respiração, inclinação, squash/stretch emocional, vibração de tontura, tint molhado, escurecimento triste, entrada com antecipação, bounce feliz, coração, espuma, pelos, perfume e estrelas. Porte pequeno/grande continua derivado da raça.

## Lote 2 concluído

11. Bob — Bulldog francês.
12. Neve — Angorá.
13. Sol — Border Collie.
14. Café — Bombaim.
15. Jade — Spitz Alemão.
16. Pitanga — Abissínio.
17. Bento — Beagle.
18. Azul — Azul Russo.
19. Paçoca — Dachshund.
20. Lua — Maine Coon.

## Fila restante

A ferramenta de geração disponível limita cada turno a dez imagens. Restam 30 sprites, organizados em três lotes de dez, sem redução de escopo:

- Lote 3: Kiko, Sushi, Cacau, Juma, Tupã, Aurora, Gaia, Nox, Rio, Estrela.
- Lote 4: Pipoca, Zeca, Belinha, Duke, Lola, Nico, Maya, Otto, Kiara, Apolo.
- Lote 5: Mimi, Yuki, Olívia, Simba, Lilo, Zara, Cosmo, Íris, Odin, Cléo.

Cada lote deve repetir recorte, validação RGBA, revisão de raça, teste de carregamento, documentação e commit.
