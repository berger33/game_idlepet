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

Cada sprite foi recortado por segmentação, normalizado para 512×512, convertido para RGBA e auditado para canal alfa. O renderer carrega automaticamente `art/pets/<id>.png`. Durante a produção incremental, o fallback vetorial evitou quebra do build; com os cinco lotes concluídos, ele atua somente como defesa de integridade.

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

## Lote 3 concluído

21. Kiko — Pug.
22. Sushi — Bobtail Japonês.
23. Cacau — Labrador chocolate.
24. Juma — Bengal.
25. Tupã — Lobo-guará guardião.
26. Aurora — Ragdoll.
27. Gaia — Samoieda.
28. Nox — Sphynx.
29. Rio — Savannah.
30. Estrela — Khao Manee.

## Lote 4 concluído

31. Pipoca — Welsh Corgi.
32. Zeca — Schnauzer miniatura.
33. Belinha — Maltês.
34. Duke — Husky Siberiano.
35. Lola — Boxer.
36. Nico — Pastor Australiano.
37. Maya — Akita Inu.
38. Otto — Basset Hound.
39. Kiara — Doberman.
40. Apolo — Boiadeiro Bernês.

## Lote 5 concluído

41. Mimi — Persa.
42. Yuki — Scottish Fold.
43. Olívia — Calico.
44. Simba — Norueguês da Floresta.
45. Lilo — Munchkin.
46. Zara — Oriental Shorthair.
47. Cosmo — Sagrado da Birmânia.
48. Íris — Cornish Rex.
49. Odin — Nebelung.
50. Cléo — Mau Egípcio.

## Coleção concluída

Os cinco lotes passaram por geração original, recorte, normalização 512×512, conversão RGBA, revisão visual de raça, teste de carregamento, validação e documentação. Os 50 IDs do catálogo agora possuem arte comercial própria. O fallback vetorial permanece apenas como defesa caso um recurso futuro esteja ausente ou corrompido.
