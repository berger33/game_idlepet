# Game Design Document — PetShop Tycoon

**Versão 1.0 de fundação** · Documento vivo · Owner: Game Director

## 1. North Star

Fantasia: começar improvisado com um cachorro e transformar cuidado cotidiano em uma rede veterinária brasileira acolhedora. O verbo emocional é **cuidar**; o verbo sistêmico é **priorizar**; a recompensa é **ver transformar**. Frase de sessão: “só mais um banho”.

North-star metric: **serviços satisfatórios por jogador ativo por dia**, guardrail por taxa de pets abandonados, anúncios por sessão e crash-free users. Monetização jamais é north star.

## 2. Público, plataforma e contexto

Mobile portrait, Android primeiro e iOS-ready. Jogadores 16–45, com foco casual brasileiro e sessões interrompíveis. Controle deve funcionar com um polegar; leitura principal independe de texto. Sessão típica 4–8 min; ações significativas a cada 20–40 s; retorno oferece valor sem punição.

## 3. Promessas do produto

1. Pets têm personalidade visível e memória de atendimento.
2. Cada gasto muda cenário, capacidade ou expressão, não apenas número.
3. Skill melhora resultado, mas automação respeita tempo do casual.
4. Brasil é reconhecível por afeto, arquitetura, nomes e rotina — sem estereótipo.
5. Compra é clara, reversível onde a plataforma permite e nunca necessária.

## 4. Loop em camadas

- **5 s:** selecionar/arrastar pet, gesto do serviço, resposta imediata.
- **30 s:** pedido → alocação → minijogo → qualidade → review/recompensa.
- **3 min:** administrar fila, estações, especialidades e combo.
- **30 min:** evento, missão e decisão de investimento.
- **24 h:** cofre offline, daily, retorno dos pets.
- **7 dias:** semana, coleção, evento e prestígio potencial.
- **28 dias:** passe/temporada cosmética e narrativa leve.
- **30–90 dias:** cidade, rede, pesquisa e meta colecionável.

## 5. Playable Core — banho

### Estados
`cliente_chega → esperando → banho_ativo → resultado → saída → próximo`.

O jogador toca Servir, esfrega Caramelo diretamente. Distância de gesto enche espuma; cronômetro cria tensão; faixa 82–96% gera Perfect; 62–81% gera Good; abaixo disso, excesso ou timeout falha sem punição econômica no onboarding. Feedback: pet molha, espuma cresce, bolhas seguem dedo, áudio granular, barra muda verde, estrelas, haptic, moedas e review.

### Design de erro
Erro informa causa e ação correta em uma frase. Primeiras três falhas não removem moeda nem cliente. Após tutorial, erro severo quebra combo; cliente só sai se paciência zerar na camada de fila. Não usar vergonha, contagem enganosa ou venda de revive durante aprendizado.

## 6. Serviços

Cada serviço combina entrada simples e uma variável dominável:

| Serviço | Entrada | Skill | Base s | Papel |
|---|---|---:|---:|---|
| Banho simples | esfregar circular | dosar espuma | 3–6 | onboarding |
| Banho premium | 3 timing taps | ritmo | 5 | combo |
| Tosa higiênica | linhas seguras | precisão | 4 | throughput |
| Tosa artística | trace livre | criatividade | 8 | clipe |
| Hidratação | timer + massagem | planejamento | 6 | station scheduling |
| Unhas | 4 taps | precisão | 4 | risco/recompensa |
| Ouvido | arraste lento | controle | 5 | variedade |
| Vacinação | alvo móvel | timing | 6 | XP clínico |
| Consulta | ligar sintomas | dedução | 10 | decisão |
| Cirurgia | sequência multimodal | mastery | 15 | late-game |

Automação por groomer produz Good; Perfect automático requer investimento alto e não supera habilidade ativa. Assim idle e skill coexistem.

## 7. Pets, clientes e paciência

Pet é composição de corpo, pelagem, orelha, cauda, expressão e acessório. Dados separam raça e personalidade. Personalidade altera animação e tolerância, não cria “raça ruim”. Retornos guardam afinidade e histórico resumido.

Paciência comunica em três estágios: confortável (verde/idle), inquieto (âmbar/vocalização curta), crítico (vermelho/tenta sair). Cliente especial altera pedido, não obscurece regra. Famílias ocupam fila com reserva atômica para não separar grupo acidentalmente.

## 8. Qualidade, satisfação e review

Qualidade do minijogo: Fail, Good, Perfect. Satisfação final:

`clamp(50 + qualidade + groomer + decoração + combo - espera, 0, 100)`.

Sugestão inicial: Perfect +30, Good +16, Fail −18; groomer até +12; decoração até +10; espera −0,6/s após tolerância. Review: 1 estrela <30, 2 <50, 3 <70, 4 <90, 5 ≥90, com pequena variação determinística por pet. Reviews desbloqueiam VIP, mas reputação baixa reduz apenas bônus de fluxo, nunca paralisa.

## 9. Combo e decisões

Perfect incrementa combo; Good conserva apenas com pesquisa; fail severo/pet perdido quebra. Recompensa monetária cresce 2,5% por stack até 20 para evitar explosão; marcos 2/3/5/10/20/50 alteram apresentação. Combo entre sessões é “protegido” por janela curta ou conquista; não cobrar para preservar durante falha técnica.

Decisões a cada 20–40 s: qual pet, estação, groomer, upgrade, missão ou evento. Se jogador fica sem decisão por >45 s, diretor de ritmo oferece pedido, manutenção ou coleta — não popup comercial.

## 10. Funcionários

NPC: identidade, silhueta, especialidade, nível 1–20, uma passiva clara e raridade. Contratação usa moeda ganha e trilha determinística; “gacha leve” deve publicar chances, proteção contra duplicata e alternativa por fragmentos. Nenhum funcionário de poder é exclusivo pago. Duplicata converte em fragmentos com valor estável.

## 11. Estações e capacidade

Recepção inicia 3; marcos 5/8/12/20. Estação possui throughput, qualidade e manutenção. Upgrade sempre manifesta visual em 1, 5, 10 e 20. Gargalo deve ser identificável pela fila e animação. Banheira, secadora e tosa formam primeira rede de fluxo.

## 12. Progressão física

Quintal → bairro → clínica pequena → moderna → centro → hospital → regional → nacional → instituto → império. Cada tier introduz no máximo um sistema principal antes de recombinar. Transição preserva coleção e permite visitar cenário anterior. Cidade é capítulo visual/musical e modificador leve, não reskin de preços.

## 13. Prestígio

Disponível quando a próxima camada já foi compreendida e total_coins ≥1M. Tokens = `floor(sqrt(total_coins / 1e6))`. Preview mostra exatamente o que reseta/mantém e ganho projetado; exige confirmação de duas etapas sem urgência. Mantém coleção, cosméticos, conquistas e compras. Primeira aposentadoria tem vinheta e objetivo imediatamente alcançável em <60 s.

## 14. Economia

Moedas alimentam operação; Brasas compram cosmético/conveniência transparente; Tokens compram meta permanente. Faucets: serviços, missões, cofre, evento, conquistas. Sinks: estações, staff, decoração, pesquisa. Cada sink deve produzir expressão visual ou nova decisão. Curvas e metas estão em `ECONOMY.md`; configuração nunca depende só do cliente para item pago.

## 15. Offline

No retorno: calcular por relógio com rollback clamp, limitar cap, mostrar intervalo e fórmula resumida. Base é 50% do rate automatizado elegível. Rewarded opcional dobra uma vez, com botão de coleta normal igualmente destacado. Nada expira enquanto popup está aberto. Eventos baixados usam janela assinada/cache futuro.

## 16. Retenção

- Daily 7 dias permite recuperar 1 dia por ciclo sem compra; dia 7 pet raro também obtível em coleção.
- 3 missões diárias + épica usam ações variadas, sem exigir anúncio/IAP.
- Semanais acumulam e evitam tarefa impossível por unlock.
- Passe 30 níveis/28 dias: trilha grátis relevante; premium retroativo; sem penalizar compra tardia.
- Streak não usa ameaça agressiva; freeze é ganhável.
- Push opt-in, máximo 2/dia, quiet hours locais, deep link honesto.
- Eventos sazonais voltam no futuro; “exclusivo” significa edição, não nunca mais.

## 17. Coleções e conquistas

Catálogo 120 pets em ondas, 60 groomers, 200 itens e 80 conquistas planejados; MVP 10/6/20+/30+. Silhuetas revelam origem e condição. Conquista mede comportamento saudável (experimentar, cuidar, dominar), não tempo bruto artificial. Recompensas reclamáveis em lote e idempotentes.

## 18. LiveOps

Agenda semanal local é previsível; sazonal vem de configuração verificada. Evento deve declarar início/fim, modificadores, elegibilidade, fallback offline e conversão de moeda ao terminar. Não publicar evento sem kill switch. Conteúdo novo passa por linter de dados, simulação e smoke test.

## 19. Momentos clipáveis

Oito momentos: espuma ×50, antes/depois, lendário, rede, prestígio, cofre, contratação rara, descoberta. Regra: jogo continua compreensível sem gravar; captura é opt-in; sem áudio/microfone externo por padrão; legenda é editável; consentimento antes de MediaProjection. O diretor de câmera mantém safe zones 9:16 e duração 6–12 s.

## 20. Monetização ética

Sem banner. Rewarded explícito, máximo 8/dia e 3 min. Interstitial apenas após 20 min, transição natural, nunca nas três primeiras sessões, após IAP ou rewarded; no máximo conforme remote config. “No Ads” remove interstitial, não esconde rewarded opcional. Loja exibe preço local da API, conteúdo e restauração. Não usar moeda para mascarar preço real em primeira compra.

## 21. Tutorial

Aprendizado por spotlight e affordance: (1) cliente balança pedido; (2) botão Servir pulsa; (3) dedo fantasma faz um círculo; (4) faixa fica verde; (5) moedas voam à banheira; (6) jogador escolhe upgrade. Texto total <35 palavras. Skip disponível após primeira ação; replay em Configurações. Eventos `tutorial_step` por nome estável.

## 22. UX e acessibilidade

Polegar alcança ações primárias no terço inferior; monetização nunca ocupa posição recém-usada por ação gratuita. Fonte escalável; não depender só de cor; Perfect tem forma/brilho/som; reduced motion/particles; haptic e áudio separados; alvos ≥48 dp. Modo daltônico troca códigos verde/vermelho por formas/check/exclamação.

## 23. Arte e áudio

Cartoon vetorial pseudo-isométrico, volumes arredondados, luz quente; detalhes em hierarquia. Caramelo é primeiro embaixador. Música lo-fi brasileira sutil por instrumentação, sem caricatura. SFX curtos têm famílias e variação de pitch limitada; vocalizações não incomodam em repetição. Regras completas em `ART_STYLE.md`.

## 24. Conteúdo brasileiro

Nomes afetivos e raças populares; vira-lata caramelo é protagonista, não piada. Cenários observam materiais, plantas, placas e luz local sem bandeiras excessivas. Revisão cultural por brasileiros de regiões distintas antes de Amazônia/Junina/Carnaval.

## 25. Difficulty & pacing

Primeiro Perfect deve ocorrer até segunda tentativa; primeiro upgrade até 3 serviços; estabelecimento 2 em 20–35 min ativos no MVP; primeira coleção em <4 min. Dificuldade cresce por combinação e prioridade, não por reduzir arbitrariamente janela de toque abaixo de acessibilidade. Fail rate alvo: tutorial <10%, early 10–20%, mastery challenge 25–35% opt-in.

## 26. Conteúdo MVP

2 estabelecimentos, 50 pets no slice atual (meta original: 10), 8 arquétipos de cliente, banho+tosa, 120 níveis do upgrade principal, 30 conquistas, 3 daily, 1 weekly, save/settings/tutorial, pt-BR, analytics/config/crash adapter, rewarded/interstitial controlado, Starter/No Ads. Conteúdo tem Definition of Done funcional+visual+áudio+analytics+teste+doc.

## 27. Soft launch

Fases: technical (50–200 dispositivos) → retention (1k–5k novos usuários/cohort) → monetization ethics → scale. D1 >40% e tutorial >85% são hipóteses/gates, não promessa. Segmentar por versão, source e hardware. Não otimizar compra antes de estabilidade, tutorial e D1.

## 28. KPIs e guardrails

D1/D3/D7/D14/D30, sessões/dia, duração, serviço/sessão, erro, upgrade, coleção, ad opt-in, conversion, ARPDAU/LTV. Guardrails: pet_left, ad fatigue, rage quit após popup, review store negativa, thermal warning, crash/ANR. Toda análise inclui intervalo e tamanho amostral.

## 29. Fora do escopo imediato

Multiplayer síncrono, chat, economia negociável, user-generated content público, cirurgia realista, câmera/microfone e backend custom completo. Ranking backend-lite só entra com antifraude e compliance. iOS está arquiteturalmente preparado, mas assinatura/teste é milestone próprio.

## 30. Definition of Done e gates

Feature pronta = regra data-driven, fluxo completo, feedback, fallback offline, acessibilidade, eventos analytics, testes, budget e doc. Playable Core não avança por quantidade: requer observação de ao menos 5 jogadores-alvo, compreensão em 10 s e duas iterações. Vertical Slice requer art/audio final de 1 estabelecimento e teste físico mid/low.

## 31. Hipóteses para validar

H1 esfregar+timing sustenta repetição; H2 pet expressivo eleva cuidado; H3 transformação física comunica valor; H4 cofre a 50% parece generoso; H5 clipes são desejados sem incentivo excessivo; H6 Brasil aumenta reconhecimento sem limitar exportação. Cada hipótese terá experimento e critério pré-registrado.

## 32. Backlog macro

**CRITICAL:** core feel/save; package/legal/plugins antes de release. **HIGH:** tosa, fila, upgrade físico, tutorial, performance, adapter SDK. **MEDIUM:** coleções/dailies/evento/passe/prestígio. **LOW no MVP:** ranking amplo, hospital, 120 pets, 8 cidades, temporadas completas. Prioridade baixa não significa cancelado; significa dependente de evidência.
