# Auditoria de Interações, Pets e Carreira de 50 Horas

**Data:** 17/09/2026 · **Build alvo:** vertical slice offline consolidado

## Cobertura de interação

| Elemento clicável | Press | Release | Áudio | Haptic | Partícula | Resultado |
|---|---|---|---|---|---|---|
| Servir/Finalizar/Próximo | squash 94% | overshoot 102,5% | tap + resultado | leve/sucesso/erro | brilho + VFX pet | estado do serviço |
| Melhorar estação | squash | overshoot | tap + moeda | leve + sucesso | brilho + toast | nível/visual/renda |
| Momento | squash | overshoot | tap | leve | brilho + toast | analytics marker |
| Missões/Coleção/Mapa/Ajustes | squash | overshoot | tap | leve | brilho + modal pop | painel dedicado |
| Coletar recompensas | squash | overshoot | tap + moeda | leve | brilho + toast | grant idempotente |
| Voltar | squash | overshoot | tap | leve | brilho | fecha modal |
| Pet em espera | reação corporal | — | vocalização fofa | leve | três corações | fala + afeto |
| Pet durante banho/tosa | olhos/mood/cauda | ferramenta some | espuma/máquina | granular | bolhas/pelos/ferramenta | progresso |

Todos os `Button` são criados por uma única factory e ligados a `InteractionFX`; o teste automatizado impede a criação de um segundo caminho sem feedback. Botões desabilitados têm estado cinza e não emitem feedback enganoso. Modais bloqueiam toques no pet atrás deles.

## Reações do pet

- Entrada lateral com easing e idle respirando.
- Cauda com ritmo diferente em estado feliz.
- Cães têm orelhas caídas; gatos têm orelhas triangulares, bigodes e cauda felina.
- Banho altera cor do pelo; Perfect abre sorriso/língua; falha mostra tristeza sem sofrimento.
- Esfregar alterna foco, piscada, entusiasmo e olhos tontos por excesso.
- Carinho fora do serviço gera fala conforme temperamento, corações, som e haptic.
- Afeto é salvo por pet. Marcos 5/20/50 concedem Brasas ganháveis; até 50 carinhos geram bônus máximo de 25% no atendimento daquele pet.

## Catálogo e cadência

O catálogo jogável passou de 10 para **30 pets**: 15 cães e 15 gatos, do nível 1 ao 120. Inclui vira-lata caramelo, Shih-tzu, Pinscher, Golden, Poodle, Yorkshire, Bulldog francês, Border Collie, Spitz, Beagle, Dachshund, Labrador, Samoieda; SRD branco, frajola, Siamês, tigrado, Angorá, Bombaim, Abissínio, Azul Russo, Maine Coon, Bobtail Japonês, Bengal, Ragdoll, Sphynx e Khao Manee. Cada entrada possui raça, espécie, raridade, temperamento, cidade, paciência, tip, serviço preferido e paleta.

Desbloqueios são distribuídos em níveis 1, 2, 4, 6 e depois a cada 3–8 níveis. Isso oferece novidade muito cedo sem despejar sistemas e mantém metas de coleção até o nível 120.

## Modelo verificável de 50+ horas

Carreira: 120 níveis. XP para sair do nível `L`:

```text
xp(L) = 50 + (L - 1) × 25
```

Hipóteses conservadoras do simulador:

- 60% Perfect/40% Good = 13 XP por serviço;
- 14,5 segundos médios por serviço;
- 10% de tempo adicional em upgrade, coleção, missões e mapa;
- nenhum anúncio, espera artificial ou compra incluído.

Resultado para nível 120: **181.475 XP, 13.960 serviços e 61,85 horas ativas estimadas**. Mesmo um jogador com 100% Perfect permanece em **53,60 horas** sob a mesma cadência. O CSV completo por nível está em `docs/career_50h.csv`, gerado por `tools/career_sim.py`; o teste automatizado falha se o cenário médio cair abaixo de 60 horas ou o especialista abaixo de 50.

## Marcos macro

| Nível | Capítulo |
|---:|---|
| 1 | Banheiro de Quintal |
| 8 | Pet Shop de Bairro |
| 18 | Clínica Pequena |
| 30 | Clínica Moderna |
| 45 | Centro Veterinário |
| 62 | Hospital Animal |
| 80 | Rede Regional |
| 98 | Rede Nacional |
| 110 | Instituto de Pesquisa |
| 120 | Império Pet Brasil |

O mapa usa os mesmos dados do simulador, evitando divergência entre documento e jogo. Upgrade principal aceita 120 níveis com marcos visuais catalogados.

## Retenção sem manipulação

A duração é progressão modelada, não garantia de compulsão ou de retenção real. Retenção depende de playtest e cohorts. Foram usados: novidade antecipada, metas legíveis, habilidade, vínculo individual com pets, coleção, retorno offline, missão e transformação. Não foram usados energia, perda de pet por ausência, streak punitivo, anúncio forçado ou preço disfarçado.

## Critérios de validação em aparelho

1. Todo botão deve mostrar squash, brilho, som e haptic em uma única ativação, sem áudio duplicado.
2. Tocar o pet em espera deve sempre produzir reação em até 100 ms.
3. Arraste deve exibir ferramenta sob o dedo e escondê-la ao soltar/cancelar.
4. Gato deve ser reconhecível sem texto em teste de cinco segundos.
5. Modal aberto não pode acionar pet ou estação atrás dele.
6. Nível/XP e desbloqueio devem sobreviver ao save v4 e migrações anteriores.
7. Medir p50 real de serviço e atualizar apenas as hipóteses do simulador, preservando piso de 50 horas com conteúdo, não grind vazio.
