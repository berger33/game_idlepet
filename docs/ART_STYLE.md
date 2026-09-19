# Art & Motion Style Bible

## Identidade
“Clínica acolhedora encontra brinquedo de banho”: 2D vetorial cartoon pseudo-isométrico, volumes macios, materiais limpos, luz brasileira quente. Silhueta e emoção vencem detalhe. Não copiar jogo de referência; referências servem a legibilidade, ritmo e acabamento.

## Paleta
Rosa shampoo `#FF8FB1`, azul água `#4FC3F7`, verde pet `#7ED957`, creme `#FFF3E0`, madeira `#8D6E63`, clínica `#B0BEC5`, carvão `#263238`, raro `#FFD54F`. Branco nunca puro em grandes áreas; sombras usam carvão/marrom com 12–24% alpha. Perigo `#EF5350`, sempre acompanhado por ícone/forma.

## Forma e linha
Raio de UI 24–52 px a 1080p. Personagem: cabeça 35–42% da altura, olhos no terço médio, patas grandes. Outline seletivo 4–8 px em carvão colorido, não preto. Props têm topo visível e base estável; silhueta compreensível em 96 px.

## Luz e sombra
Fonte principal superior-esquerda, quente; sombra de contato oval, fria e suave; máximo 3 tons por material. Highlights em água/olhos, sem gradiente plástico excessivo. Raridade usa luz e ritmo, não arco-íris permanente.

## Pets modulares
Camadas: sombra → corpo → pelagem → cabeça/orelhas → olhos/boca → acessório → água/espuma. Expressões: feliz, ansioso, irritado, medroso, calmo; nunca sofrimento gráfico. Produção por pet: idle 4, banho 4, tosa 4, happy/sad e entradas/saída via rig quando possível. Caramelo: `#C98B5B`, focinho `#F1C49F`, orelha `#9C623F`.

## Groomers
Rig comum, 4,5–5 cabeças de altura, mãos amplificadas para leitura. Cabelo/pele/roupa/acessório modulares. Diversidade brasileira natural de tons, cabelos, corpos e idades. Raridade altera acabamento/acessório/pose, nunca valor humano.

## Cenários
Cada estabelecimento preserva eixo de circulação e linguagem de estações. Upgrade físico acrescenta peça, acabamento ou animação. Cidades mudam luz, vegetação, arquitetura e áudio; evitar “fantasia turística” comprimida. Placas usam português correto e pouco texto.

## UI e tipografia
Baloo 2 títulos, Nunito corpo, Fredoka números, todas OFL e empacotadas no VS. Até lá fallback é aceitável só no Core. Ícones arredondados, stroke óptico único. Botão primário sólido; secundário outline; rewarded inclui símbolo de vídeo e benefício, nunca cor do CTA gratuito.

## Motion — 12 princípios aplicados
Botão squash 0,15 s; antecipação 80–120 ms; pet olha antes de mover; arcos em cauda/água; overlap em orelha; slow-in/out em UI; exagero reservado a Perfect; staging limpa HUD; timing pet 8–12 fps estilizado e UI 60 fps; secondary motion sem bloquear; appeal por pose; volume consistente em squash. Reduced motion remove zoom/shake, mantém estado.

## VFX
Bolha: 0,5–1,2 s, 3 tamanhos; moeda: arco para HUD com máximo 12 sprites; Perfect: estrela+anel+texto; lendário: foco de 3 s pulável. Pool obrigatório no VS. LOW reduz 70% partículas, remove sombra dinâmica; gameplay idêntico.

## Proibido
Hiper-realismo, low-poly cru, outline preto uniforme, gradiente neon aleatório, anatomia inconsistente, seis estilos de ícone, texto gerado dentro de imagem, bandeira como decoração onipresente, caricatura regional, partículas cobrindo alvo, animação dolorosa ou assustadora.

## QA visual
Revisar em 1080×1920, 720×1280 e miniatura 48 px; grayscale/3 tipos de daltonismo; silhouette test; contraste; safe areas; screenshot sem debug. Um art lead aprova cada batch contra prancha mestre antes de atlas.
