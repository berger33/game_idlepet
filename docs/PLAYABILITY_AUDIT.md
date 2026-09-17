# Auditoria de Jogabilidade após Teste Visual

**Evidência:** captura fornecida pelo usuário no Godot 4.7.2.

## Diagnóstico

O jogo não estava limitado tecnicamente a clicar no cachorro: o fluxo de serviço existia, mas o CTA `SERVIR` ficava no bottom sheet em `y=1350` e era cortado pelo player embutido do editor. Isso tornava o loop principal invisível. Como o cachorro continuava aceitando carinho, a única interação descoberta pelo jogador parecia ser clicar infinitamente no pet.

Também havia um chip `FILA 2` puramente ilustrativo. Ele sugeria um sistema interativo inexistente naquele slice e aumentava a sensação de protótipo/confusão. O carinho mostrava um contador crescente, mas não orientava o jogador de volta ao atendimento. A recompensa de serviço mostrava moedas/estrelas sem explicitar XP, escondendo a progressão de carreira.

## Correções aplicadas

1. Bottom sheet passou a usar anchors/offsets determinísticos, sem combinar anchor inferior com `position.y` absoluto.
2. Sheet foi elevado para que o CTA apareça inclusive no player embutido de baixa altura.
3. `SERVIR` é o primeiro componente do sheet, antes de instrução, progresso, upgrade e navegação.
4. Primeiro CTA agora diz `1. SERVIR CARAMELO` e pulsa suavemente até ser usado.
5. Após três carinhos no primeiro pet, a instrução muda para `Caramelo está pronto! Toque em SERVIR`.
6. Contador de carinho comunica limite `x/50`; carinho continua afetivo, mas não finge ser o core loop.
7. O falso chip `FILA 2` foi removido. Nenhum elemento com aparência clicável permanece sem ação.
8. Resultado de serviço mostra explicitamente `+10/+15 XP`, além das moedas e estrelas.
9. O fluxo visível passa a ser: servir → gesto → faixa verde → finalizar → recompensa/XP → próximo → upgrade/metas.

## Progressão real disponível no build

- Primeiro serviço: moedas, XP, review e conquista.
- Primeiro upgrade: normalmente disponível após o primeiro atendimento graças à conquista inicial.
- Nível 2: Luna; nível 4: primeiro gato; nível 8: estabelecimento de bairro.
- Oitavo serviço: Bia e produção automática.
- 30 pets, afeto individual, dez conquistas, três dailies, login, eventos e 120 níveis.
- Mapa, coleção, missões e ajustes acessíveis pelo sheet.

## Teste manual esperado

1. Abrir o jogo: botão rosa `1. SERVIR CARAMELO` deve estar visível sem rolar/redimensionar.
2. Tocar no pet três vezes: mensagem deve apontar para `SERVIR`.
3. Clicar em `SERVIR`: barra/timer aparecem e instrução pede gesto.
4. Esfregar até verde e finalizar: resultado mostra moedas e XP.
5. Clicar `PRÓXIMO CLIENTE`: novo pedido entra.
6. Comprar `MELHORAR ESTAÇÃO`: custo cai, nível/ganho sobem e selo aparece no cenário.
7. Abrir Missões/Coleção/Mapa para observar progresso persistente.

## Limite de escopo ainda explícito

A fila completa com pets simultâneos, drag pet→estação e múltiplos groomers visuais continua sendo um sistema posterior; por isso o indicador falso foi removido em vez de manter uma promessa sem mecânica. O slice atual agora comunica honestamente e torna acessível tudo que de fato funciona.
