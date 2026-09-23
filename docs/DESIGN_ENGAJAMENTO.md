# DESIGN_ENGAJAMENTO — transformar a ação de cuidar em jogo

Data: 2026-09-20 · Complementa `docs/RETENTION_MECHANICS_AUDIT.md` (meta/retenção) e
`docs/EXPERIENCE_ROADMAP.md`. Foco exclusivo: **o loop de 10 segundos** — o que o
jogador FAZ entre selecionar o cartão e ver o resultado.

## 1. Diagnóstico (verificado no código)

O loop real hoje: escolher cartão da fila → arrastar a ferramenta certa →
**esfregar/segurar até a zona verde do aro de dosagem** → soltar → resultado
(`Main._move_pointer/_end_pointer`, `BathService.rub/finish`).

Por que repete (raízes, não sintomas):

1. **Todos os 5 serviços são o mesmo gesto.** `GESTURES` só troca eixo/modo/
   distância (`Main.gd:_configure_current_service`) — banho, tosa, secagem,
   perfume e laço diferem no sprite, não na mecânica. Dominou um, dominou todos.
2. **Pet não muda a ação.** Um siamês lendário joga exatamente como o caramelo
   nv1. `temperament`, `species` e `preferred_service` existem no catálogo e não
   afetam gesto nenhum; `patience` só estica o cronômetro.
3. **Zero decisões durante o serviço.** A única "escolha" é quando soltar.
4. **A fila não é um jogo.** Os cartões não mostram os trade-offs (VIP,
   paciência, raridade, pedido) — escolher o próximo é apertar qualquer botão.
5. **Progressão é numérica.** Upgrades (`bath_upgrade`, `tool_upgrade` 30 níveis)
   multiplicam renda; nenhum muda COMO se joga.
6. **Estados são decoração.** dirty/wet/messy/dizzy/sad/happy são visuais; o
   "dizzy" não é consequência de errar, o "happy" não reage ao acerto em jogo.

## 2. Propostas — Onda 1: cada ação é diferente (ataca 1, 2, 6)

### A1. Identidade de gesto por serviço (`BathService` v2)
O aro de dosagem fica como assinatura do **banho**; os outros serviços ganham
mecânica própria, todas construídas sobre o par `rub()/tick()` que já existe:

| Serviço | Mecânica | Já existe no código |
|---|---|---|
| Banho | Esfregar + dosar (atual) | `fill_mode=rub`, janela 0.82–0.96 |
| Tosa | **Seguir a seta**: 3 traçados na direção indicada (↑/↓/↔ muda por pet); tráfego na direção errada não pontua | `axis` vertical/horizontal já filtra `rub()` |
| Secagem | **Manter na zona**: o bocal precisa acompanhar um círculo que deriva pelo corpo do pet (pet inquieto = círculo mais rápido) | `fill_mode=hold` + `hold_rate` já seguram por contato |
| Perfume | **Ritmo**: 3 borrifadas no pulso do anel (toque quando o aro brilha); borrifar fora do pulso desperdiça | `hold_rate` + anel de progresso do canvas |
| Laço | **Encaixe de precisão**: soltar o laço sobre a marca no pescoço (zona que encolhe com a raridade) | drop final já é o release; só precisa de alvo + tolerância |

*Por que prende:* variedade dentro da própria sessão (a fila alterna serviços) e
domínio motor real — o jogador melhora VISIVELMENTE ao repetir, que é o que falta
num loop só de dosagem.

### A2. Temperamento e espécie mudam o jogo (ataca 2)
Usar os campos que já estão em `pets.json`:
- `temperament` **agitado** → aro/seta/círculo tremem ~8% (janela efetiva menor);
  **calmo** → janela perfeita +25%; **brincalhão** → às vezes pula 1 (interrompe
  o gesto por 0,4s com reação `happy_air` já existente).
- `species=cat` em banho → janela menor (gato odeia água), mas em tosa/laço
  janela maior; cão grande (`sprite 445`) → traçados mais longos (mais pontos de
  contato), pequeno (`330`) → círculo de secagem mais rápido.
- Resultado por escrito no cartão da fila: "agitado · paga +20%".

*Por que prende:* 50 pets deixam de ser skins — o jogador APRENDE os bichos
("siamese agitado eu faço laço, banho não") e a fila vira leitura de mão.

### A3. Estados como consequência (ataca 6)
- Errar por exagero (`overwashed`) → pet `dizzy` por 3s e a próxima etapa começa
  com a janela estreitada (recuperação se acertar).
- Perfect consecutivo → pet vai para `happy_squash` e a paciência da FILA toda
  desacelera 10% por 3 clientes (o salão fica "em ritmo").
- Soltar cedo demais → `sad` + direito a 1 retomada (já existe retomada acima do
  piso 0.62 — formalizar com o estado visual).

*Por que prende:* feedback emocional imediato liga erro/acerto à arte que já
temos (500 sprites de estado!) — o jogo "reage" em vez de só pontuar.

## 3. Propostas — Onda 2: decisões entre ações (ataca 3, 4)

### B1. Fila com trade-offs explícitos
Cartões mostram: raça + pagamento (raridade), risco (paciência como barra),
"pedido especial" (ícone). Ex.: *VIP golden, paciência curta, paga ×2* vs
*vira-lata tranquilo, pede tosa+perfume*. Cliente sai da fila → os demais
"perdem a paciência mais devagar" se o atendimento foi perfeito (ver A3).
Escolher vira gestão de risco com informação que JÁ existe no `queue` dict.

### B2. Pedidos especiais (upsell)
30–40% dos clientes pede um extra ao finalizar ("e um perfume?"): aceitar
estende o combo de etapas com bônus de gorjeta, recusar não pune. Usa
`preferred_service` do catálogo e dá identidade aos pets (`MetaPanel` já mostra
preferidos). Micro-decisão por cliente, custo baixíssimo.

### B3. Hora do pico (rush)
A cada ~4 min de jogo ativo, 45s de "pico do bairro": fila recarrega rápido,
combo não zera em "good", gorjeta ×2. Cria picos de sessão — o oposto de
repetição — usando `LiveOps` (mesma infra de eventos, com dosador remoto).

## 4. Propostas — Onda 3: progressão que muda o jogo (ataca 5)

### C1. Upgrades de gameplay (marcos 10/20/30 das ferramentas)
Alguns níveis de `tool_upgrade` destravam efeitos que alteram a ação em vez de
só multiplicar: "sabonete espumante +30% de janela perfeita" (nv10), "secador
turbo: 3 pulsos rápidos substituem o hold" (nv20), "laço de precisão: marca
maior" (nv10), "banheira dupla: 2 pets simultâneos" (nv30, o grandão).
Visual: aro do utensíário muda para prata/ouro nos marcos (tint nas artes
atuais — sem asset novo).

### C2. Maestria por ferramenta
Contador de usos com selos (100/500/2000) e micro-bônus. Dá sentido à repetição
em si e aos analytics (`tool_used` já existe? senão, 1 evento).

### C3. Carinho entre serviços (recompensa o toque)
`_react_to_pet_touch` já existe: 1 carinho rápido = +1 ponto de afeto com burst
de corações (afeto já multiplica renda até +25%). Recompensa o impulso que o
jogador já tem (tocar no bicho) e conecta com o buddy.

## 5. Ordem sugerida (impacto × esforço)

| # | Proposta | Impacto | Esforço | Depende de |
|---|---|---|---|---|
| 1 | A3 estados-consequência | Alto | **Baixo** (estados + multiplicadores prontos) | — |
| 2 | B1 fila com trade-offs | Alto | **Baixo** (UI do que já existe no dict) | — |
| 3 | A2 temperamento/espécie | Alto | Médio (dados prontos, wiring) | A1 parcial |
| 4 | A1 gestos por serviço | Muito alto | Médio (extensões no BathService) | — |
| 5 | B2 pedidos especiais | Médio | Médio | B1 |
| 6 | C1 upgrades de gameplay | Alto | Médio-alto | A1 |
| 7 | B3 hora do pico | Médio | Médio | — |
| 8 | C2/C3 maestria/carinho | Médio | Baixo | — |

Recomendo entregar 1+2 primeiro (uma sessão cada, sem tocar no BathService),
depois 3+4 juntos (a "Onda 1" completa), depois o resto.

## 6. Status de implementação (2026-09-20) — AS 3 ONDAS ENTREGUES

Todas as propostas A1–C3 estão implementadas e cobertas por QA programático
(33 testes de contrato + smoke de interação com simulação dos 4 modos novos).

### Onda 1 — Gesto com identidade (A1 + A2 + A3)
- `BathService` v2: 5 modos (`rub`, `stroke`, `zone`, `pulse`, `drop`) +
  temperamento (`shake_amplitude` para agitados, `hop_interval` para
  brincalhões — o pulinho pausa o gesto 0,4s).
- Banho = esfregar clássico; tosa = traçado direcionado por setas
  (sequência determinística por pet); secagem = acompanhar o círculo que
  deriva (lissajous, raças pequenas derivam mais); perfume = 3 borrifadas
  quando o anel dourado acende (janela 0,95–1,0: 3 = perfect, 2 = good);
  laço = encaixe de precisão na marca do pescoço.
- Temperamento (pets.json): agitado +0,03 de janela e tremor de UI; calmo
  −0,05; brincalhão pulinhos. Gato: banho +0,02, tosa/laço −0,04.
- Estados-consequência: overwash → pet tonto (wobble) + próxima janela
  estreitada até um acerto; timeout → pet triste; 2 perfects seguidos →
  buff "salão no ritmo" (fila −10% de paciência por 3 clientes).
- UI de gesto desenhada em `GestureArt.gd` (setas, círculo, anel rítmico,
  marca tracejada + crosshair) com jitter para agitados.

### Onda 2 — Decisão na fila e no caixa (B1 + B2 + B3)
- Fila: 3ª linha por cartão com temperamento + pagamento (●/●●/●●●) e
  borda colorida por raridade (cinza/verde/azul/roxa/dourada).
- Pedido especial (upsell): 35% dos clientes (RemoteConfig `upsell_chance`)
  pedem um 2º serviço — preferência do pet priorizada; painel de decisão
  antes do resultado; aceitar abre o 2º atendimento com gorjeta ×1,4
  (`upsell_tip_mult`); recusar segue direto pro resultado.
- Pico do bairro: a cada 240s (RemoteConfig), 45s com gorjetas ×2, recarga
  da fila 0,35s (vs 1,1s), paciência ×0,5, "good" não quebra o combo e
  vinheta dourada pulsante na cena + pill "PICO ×2 — Xs" no topo.

### Onda 3 — Progresso que muda o jogo (C1 + C2 + C3)
- Marcos de gameplay: sabonete nv10 (janela +30%), tosa nv10 (passos
  −15%), secador nv20 (drift −30% + hold +50%), laço nv10 (marca +40%),
  banheira nv30 = **banheira dupla**: o buddy é renderizado em paralelo
  em `GestureArt.draw_buddy` e o atendimento paga **+40%** (sem 2º gesto —
  transparência: o bônus não exige interação extra, é recompensa do marco).
- Maestria (C2): usos por ferramenta persistidos no save (v9, migração
  encadeada), selos em 100/500/2000 (+2% de pagamento cada, até +6%),
  toast de marco + aro prata (nv10)/ouro (nv20) no utensílio da cena.
- Carinho (C3): teto de 5 afetos por cliente (RemoteConfig
  `petting_max_per_client`); acima disso o pet reage ("já está banhado de
  carinho!") sem afeto — o toque continua vivo, sem farm infinito.

### Arquitetura resultante
Main.gd continua o orquestrador (1072 linhas, limite 1100 mantido); a lógica
de domínio saiu para módulos estáticos no padrão StationArt/GestureArt:
- `core/gameplay/SalonTuning.gd` — gestos, temperamento, marcos, recompensa,
  cliente da fila, hints (dados de design centralizados).
- `core/gameplay/SalonPanels.gd` — construção de painéis/cartões da UI.
- `scenes/main/TutorialFlow.gd` — roteiro do tutorial (3 passos).
- `core/gameplay/GestureArt.gd` — UI de gesto + buddy da banheira dupla.
Eventos de analytics novos: `rush_started`, `upsell_offered/accepted/
declined`, `tool_milestone`, `mood_buff`. Chaves RemoteConfig novas: 6
(vidas úteis de tuning sem build). QA: smoke_interact step6 simula stroke/
zone/pulse/drop ponteiro a ponteiro (determinístico, sem autoload).
