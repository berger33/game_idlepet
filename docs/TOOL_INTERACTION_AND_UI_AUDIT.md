# Auditoria e reconstrução — utensílios, progressão e interface

## Direção aprovada

O carinho permanece como toque direto no animal. Toda ação profissional usa um objeto físico do cenário: o jogador pega o utensílio na prateleira, arrasta até o pet e executa o gesto mantendo o objeto sobre o corpo. Não existe mais barra horizontal de progresso.

## Loop implementado

1. O pedido informa o cuidado e a prateleira exibe os itens.
2. Toque/clique e arraste o item correto.
3. Ao alcançar o pet, o atendimento começa sem um botão intermediário.
4. Um aro circular acompanha o utensílio e preenche conforme o gesto.
5. O pet, partículas e som respondem durante todo o movimento.
6. Ao completar o aro, o resultado é automático; o botão verde de confirmação fica dentro do cartão de resultado.
7. Soltar o utensílio o devolve visualmente à prateleira, preservando progresso parcial.

Item errado gera orientação, som suave de erro e nenhuma penalidade. Itens bloqueados mostram o nível, mas não capturam input.

## Utensílios e telas

| Nível | Utensílio | Ação | Tela própria | Áudio |
|---:|---|---|---|---|
| 1 | Sabonete | Ensaboar | Banho do Bairro | bolhas |
| 3 | Máquina | Tosa | Tosa do Bairro | motor de lâmina |
| 5 | Secador | Secar | Secagem Aconchegante | fluxo de ar |
| 7 | Perfume | Perfumar | Spa Perfumado | spray/chime |
| 10 | Lacinho | Estilizar | Ateliê de Laços | sinos brilhantes |

As telas entram automaticamente no ciclo assim que o nível correspondente é alcançado. O level-up tem som, haptic e aviso de desbloqueio.

## Economia e upgrades

- Bônus da estação caiu de 15% para 7,5% por nível, exatamente metade do crescimento anterior.
- Estação informa nível, bônus acumulado, próximo incremento e custo.
- Cada utensílio possui 30 níveis próprios, custo crescente e +4% de rendimento por nível.
- O botão do utensílio acompanha o pedido atual, permitindo melhorar sabão, máquina, secador, perfume e laço.
- Save avançado para v6 com migração v5→v6 e sanitização dos cinco níveis.

## Conteúdo

O catálogo foi ampliado de 30 para 50 pets:

- 25 cães, incluindo Corgi, Schnauzer, Maltês, Husky, Boxer, Pastor Australiano, Akita, Basset, Doberman e Boiadeiro Bernês.
- 25 gatos, incluindo Persa, Scottish Fold, Calico, Norueguês, Munchkin, Oriental, Birmanês, Cornish Rex, Nebelung e Mau Egípcio.

Todos possuem ID, raça, nível, espécie, raridade, temperamento, cidade, paciência, tip, serviço e paleta.

## Interface

- Indicadores falsos e CTA de início foram removidos; o objeto no cenário é a interação.
- Prateleira é desenhada como parte da sala, com suportes, objetos e silhuetas bloqueadas.
- Menus agora abrem sobre cenário ilustrado escurecido, com animação de escala/fade, cartão translúcido, ícones, áudio e feedback universal.
- Resultado contém sua própria confirmação; não depende de um rodapé cortado.
- Cinco fundos ilustrados próprios cobrem todo o ciclo de ferramentas.

## Riscos externos

A sintaxe, dados, economia e contratos podem ser validados no repositório. O gesto, escala visual, mix de áudio e troca de salas precisam de uma rodada manual no Godot 4.7.2, pois não há executável Godot compatível no ambiente de automação.
