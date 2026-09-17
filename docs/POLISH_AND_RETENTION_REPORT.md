# Consolidação de Progressão, Retenção e Polish

**Data:** 17/09/2026 · **Escopo:** early vertical slice offline

## Diretriz ética

A solicitação de deixar pessoas “viciadas e presas” foi traduzida em **engajamento voluntário saudável**. Não foram introduzidos dark patterns, punição desproporcional, pressão de compra, stamina artificial, popup agressivo ou recompensa enganosa. A retenção deve vir de domínio, expressão, carinho pelos pets e progresso claro.

## Auditoria do loop anterior

Pontos fortes: ação imediatamente compreensível, Perfect por habilidade, feedback multissensorial, save/offline e metas iniciais. Fragilidades encontradas: cenário procedural ainda com aspecto de protótipo; banho e tosa dividiam a mesma estação visual; pets não tinham diferença de cor; ausência de BGM; pouca celebração de nível; upgrade quase só numérico; progressão sem nível de jogador; alocações visuais desnecessárias no draw.

## Melhorias consolidadas

### Arte e apresentação

- Dois cenários finais coerentes e exclusivos para o slice: banho e mesa de tosa.
- Direção visual única: contorno carvão, creme, rosa shampoo, azul água, verde pet e madeira quente.
- Cenários sem texto rasterizado; título é desenhado/localizável em runtime.
- Caramelo, Luna e Thor agora têm paletas próprias no personagem procedural.
- Entrada lateral com easing, idle, reação molhada, alegria, língua, blush, estrelas, espuma e pelos.
- Fila e nível da estação integrados ao mundo, reduzindo dependência de menus abstratos.
- Upgrade aparece visualmente como badge dourado de estação.
- Caixas desenhadas no gameplay são cacheadas para evitar alocação por frame.

### Áudio e juice

- Loop musical procedural leve, harmônico e livre de licença externa.
- SFX distintos para tap, espuma, moeda, Perfect, review e erro.
- Haptic success/error/light respeita configuração.
- Combo ≥5 ganha apresentação “BANHO QUENTE” e telemetria de marco.

### Progressão

- Save v4 com migração sequencial v0→v1→v2→v3→v4 e afeto individual por pet.
- Nível de jogador e XP: Good concede 10 XP, Perfect 15 XP.
- Próximo nível: `50 + (nível−1)×25`; level-up concede `20 + nível×5` moedas. A carreira de 120 níveis oferece 61,85 h médias e 53,60 h no cenário especialista modelado.
- Marcos continuam espaçados: primeiro upgrade em 2–3 serviços, Luna no nível 2, primeiro gato no nível 4, Bia após 8 serviços e Pet Shop de Bairro no nível 8.
- Bia cria produção ativa passiva após contratação; offline continua a 50% e cap progressivo.
- Daily login, três missões, coleção, conquistas, evento semanal e mapa dão metas de segundos, minutos e retorno.

### Ritmo esperado

| Momento | Recompensa/novidade |
|---:|---|
| 0–20 s | primeiro serviço e reação do pet |
| 30–60 s | primeiro upgrade/conquista |
| 1–3 min | primeiro level-up e variação de pet |
| 2–5 min | tosa e cenário novo |
| 5–9 min | coleção em crescimento e missão próxima |
| 8–15 min | Bia e automação |
| 15–30 min | Pet Shop de Bairro/evento/metas |
| retorno | cofre offline + daily sem bloquear jogo |

Esses tempos são hipóteses. Devem ser confirmados por telemetria p50/p90 e cinco testes observados; aumentar retenção não justifica manipular dificuldade sem dados.

## Validação técnica executada

- `gdformat` aplicado aos scripts.
- `gdlint` concluído sem problemas; isso valida parsing/estilo, não substitui runtime Godot.
- Testes Python de schemas, IDs e pacing aprovados.
- JSONs válidos e `git diff --check` limpo.
- Imagens verificadas como PNG 768×1376; tamanho conjunto aproximado de 3,3 MB comprimido.
- Download do editor Godot e das fontes OFL falhou por SSL nos hosts externos; não foi escondido nem substituído por fonte sem licença.

## QA visual ainda obrigatório em máquina/aparelho

1. Importar no Godot 4.3+ e confirmar crop dos dois cenários em 1080×1920, 720×1280 e safe areas.
2. Verificar legibilidade do fallback font; empacotar Baloo 2/Nunito/Fredoka com OFL quando o download estiver disponível.
3. Profile GL Compatibility em Android low/mid/high.
4. Ouvir o loop por 10 minutos em alto-falante e fone; ajustar fadiga/volume.
5. Fazer 5 playtests sem instrução verbal e registrar time-to-serve, fail e first Perfect.
6. Capturar screenshot e vídeo reais; não produzir store art antes desse gate.

## Próximos ajustes orientados por dados

- Se fail do primeiro banho >10%: ampliar Perfect para 78–96% no tutorial e mostrar trilha do gesto.
- Se primeiro upgrade p50 >90 s: custo inicial 20; se <25 s, custo 30.
- Se sessão p50 <4 min com baixo fail: antecipar coleção/missão visual, não anúncio.
- Se Bia leva >20 min: mover unlock para 6 serviços; se <8 min, manter 8 e reforçar transformação.
- Se música causa mute >35%: reduzir lead em 3 dB e introduzir variação B.

## Estado de release

A apresentação do slice foi consolidada, mas publicação comercial continua bloqueada pelos itens externos e de conteúdo em `READINESS_AUDIT.md`: runtime/device QA, fontes licenciadas, SDKs com contas, package/keystore, consentimento, arte/animação em escala, billing validation e soft launch.