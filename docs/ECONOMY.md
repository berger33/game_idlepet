# Economia e Balanceamento Inicial

## Princípios
Upgrade cedo em 2–3 serviços, escolha em 20–40 s, sink com efeito visível, offline generoso mas inferior à interação, e progressão sem vender exclusividade. Números são hipótese e mudam apenas por experimento/cohort documentado.

## Fórmulas implementadas
- Serviço: `floor(base × 1.075^estação × (1 + utensílio×0.04) × qualidade × combo)`.
- O crescimento da estação foi reduzido de 15% para **7,5% por nível**; metade do bônus anterior.
- Quality: Good 1,15; Perfect 1,5.
- Estação: `ceil(25 × 1.18^level)`; utensílios: `ceil(base_item × 1.24^level)`, 30 níveis cada.
- Offline: `floor(rate/s × elapsed_clamped × 0.5 × (1 + prestige×0.05))`.
- Cap: `min(24h, 2h + prestige_level×1h)`.
- Prestige token: `floor(sqrt(total_coins / 1.000.000))`.

A fórmula de upgrade original (base 10) foi preservada no catálogo geral, mas o Playable Core usa 25 para que feedback inicial tenha 2–3 serviços e para testar intenção de retorno. Remote Config controla valor.

## Faucets/sinks
| Faucet | Cadência | Controle | Sink | Valor percebido |
|---|---|---|---|---|
| serviço | 10–30 s | skill/capacidade | estação | visual+throughput |
| gorjeta | variável | satisfação | staff | especialização |
| offline | retorno | 50%, cap | decoração | satisfação+expressão |
| missão | diário | limites | pesquisa | build permanente |
| evento | semanal | janela | cosmético | coleção |
| conquista | one-shot | idempotência | conveniência | escolha |

## Anti-explosão
Combo monetário cap 20, custos crescem acima da renda de uma única estação, tiers 4+ usam crescimento por segmento/log para número exibível, e moeda de evento converte em sink estável. Nunca aplicar cap invisível ao ganho pago; comunicar limite antes.

## Targets early game
Primeiro ganho <20 s, primeiro upgrade 2–3 serviços, nível 5 em 4–8 min, nível 10 em 15–25 min junto de novas decisões. O CSV `balance_initial.csv` é gerado por `python3 tools/economy_sim.py --csv docs/balance_initial.csv`, usando 55% Perfect e 14 s por serviço. Não inclui paralelismo/fila; é baseline conservadora.

## Telemetria para ajuste
TTFU (time to first upgrade), serviços/upgrade, saldo p50/p90, faucet/sink ratio, perfect rate, falha por motivo, sessão e retorno. Alertas: sink ratio <0,45 por 3 dias; p90 saldo >10× próximo sink; espera de upgrade >2 sessões early; rewarded responde por >25% do faucet.

## Experimentos
A: janela Perfect 82–96 vs 80–95; B: primeiro custo 25 vs 30; C: offline 50 vs 60%. Um experimento por camada, mínimo de amostra pré-definido, guardrail D1/fail/ad opt-out. Não alterar economia de pagadores retroativamente sem compensação.
