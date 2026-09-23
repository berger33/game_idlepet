# Auditoria de integração visual — cenário, HUD e resultado

## Evidência do teste no Godot 4.7.2

A captura mostrou três falhas objetivas:

1. O cartão de resultado não reservava altura para sua ação, portanto `CONTINUAR` ficava fora da área visível e a experiência parecia travada.
2. Um PanelContainer branco ocupava toda a base e rompia a ilusão de cenário.
3. A prateleira era desenhada por código sobre uma arte que já tinha perspectiva e iluminação próprias; utensílios e ambiente não pareciam pertencer à mesma imagem.

## Correções

- Resultado ampliado e reorganizado, com ações internas sempre visíveis.
- Ações: `CONTINUAR` funcional e `DOBRAR PONTUAÇÃO • EM BREVE` visível/desabilitada até integração real do rewarded ad.
- Rodapé branco removido por completo.
- Instrução e cards de melhoria agora flutuam sobre a arte com transparência, borda e sombra.
- Missões, Pets, Mapa e Ajustes movidos para o topo como quatro ícones circulares com tooltip, animação, som, haptic e sparkle.
- Cenários de banho e tosa recriados com prateleiras físicas vazias, perspectiva e sombra coerentes.
- Código não desenha mais madeira/prateleiras: somente os objetos interativos são compostos sobre os nichos da arte.
- Background agora usa sua altura integral 9:16, eliminando estiramento vertical após a remoção do rodapé.
- Utensílios vetoriais receberam silhueta, contorno, sombra, highlight e detalhes próprios.
- Pet recebeu sombra de contato, contorno derivado da pelagem, highlight, volume corporal e escala por grupo de raça; banheira/mesa permanecem legíveis.

## Contrato de interação

- Elementos de navegação são controles reais.
- Utensílios têm feedback de retirada da prateleira, som e haptic.
- Objetos decorativos do fundo não recebem aparência de HUD.
- A ação futura de anúncio está explicitamente marcada como indisponível e não simula recompensa.
- Todo resultado oferece uma saída funcional dentro do próprio modal.

## Verificação manual necessária

No Godot 4.7.2, concluir um serviço e confirmar que os dois botões aparecem. Clicar em Continuar deve fechar o modal e trazer o próximo cliente. Confirmar alinhamento dos cinco utensílios nas prateleiras em banho, tosa, secagem, perfume e estilo.
