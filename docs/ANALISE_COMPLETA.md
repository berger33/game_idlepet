# PetShop Tycoon — Análise Completa de Arquitetura, Mecânicas e Retenção

**Data:** 2026-09-19 · **Branch analisada:** `arena/01a0b06c-game-idlepet` (todo o código do
jogo; a `main` continha apenas o README) · **Autor:** agente Arena.ai

---

## 1. Resumo executivo

O jogo é um idle/casual de petshop em Godot 4 com **fundação de engenharia acima da média
para um protótipo** (autoloads limpos, save robusto, economia em fórmulas puras, fachadas
honestas de ads/IAP/analytics) mas com **game design central morto por um bug de
implementação**: o banho completa sozinho como PERFEITO assim que o anel atinge 86% — a
camada de habilidade ("dosar a espuma e parar na faixa verde") é inexistente na prática.
Somado a zero decisões do jogador, ausência de áudio/fonte/UI reais e composição
arte-código descalibrada (o cachorro sentado na *borda* da banheira), o produto sente-se
"rápido, fácil e sem graça" — exatamente o relato do usuário.

Foram catalogados **48 defeitos** (15 críticos, 16 graves, 17 de engenharia/conteúdo),
todos com evidência de arquivo/linha. O plano de reestruturação (Seção 13) inverte a ordem
que o projeto errou: **feel primeiro, conteúdo depois**.

## 2. Escopo e metodologia

- 100% do código lido: ~3.200 linhas de GDScript (20 arquivos), 1 `.tscn` (12 linhas, 1 nó
  `Control`), 14 JSONs de dados, 3 CSVs de localização, 17 testes Python, 4 ferramentas,
  ~1.550 linhas de docs de sessões anteriores.
- Testes, simuladores de economia/carreira e `tools/validate_project.py` executados.
- Simulação Monte-Carlo do core loop (2.000+ banhos) para provar o bug de skill.
- Composição visual verificada offline com `tools/compose_preview.py` (replica o render do
  `PetShopCanvas` com as mesmas coordenadas/escalas).
- **Não verificado em runtime Godot**: o engine não está disponível neste sandbox (CDN de
  releases bloqueado, SSL exit 35) — mesma limitação das sessões anteriores. CI headless
  adicionado (Seção 15) para cobrir esse gap no GitHub.

## 3. Estado do repositório

| Item | Estado |
|---|---|
| `main` | Só o README (1 commit). Todo o produto vive em branches `arena/*`. |
| `arena/01a0b06c-…` | 36 commits, 345 arquivos — o jogo inteiro. |
| `.import` de assets | Inexistentes → projeto nunca foi aberto no editor Godot. |
| CI | Inexistente até esta sessão (Seção 15). |
| Testes | 17 Python **por grep no texto-fonte** (frágeis, não comportamentais). |

## 4. Arquitetura e engenharia

**Pontos fortes (preservar):**
- 16 autoloads com responsabilidades claras; `EventBus` tipado; `Economy` em fórmulas puras;
  `BathService` como máquina de estados testável.
- Save v6: atômico, XOR+SHA256, 3 backups, migrações v0→v6. Melhor subsistema do projeto.
- `RemoteConfig` com defaults clampados; `Analytics` offline-first (JSONL, buffer 500);
  fachadas de Ads/IAP honestas (`provider_ready=false` → nada fake para o jogador).

**Anti-patterns:**
- **1 cena, 1 canvas**: `Main.tscn` = 1 nó `Control`; toda a UI gerada em código
  (`Main.gd` 890 linhas, `PetShopCanvas._draw` 832 linhas), posições absolutas hardcoded,
  sem tema, sem containers responsivos, sem state machine de fluxo (flags soltas).
- `queue_redraw()` a 60 fps com redesenho integral de 1080×1920 + alocação de `Dictionary`
  por bolha (cap 42) — risco de performance em Android de entrada.
- 12 dos 14 JSONs de dados **mortos em runtime** (só `pets.json` e `career_track.json` são
  lidos). Testes que greppam o próprio fonte (encorajam congelar bugs — vide Seção 15).

## 5. Inventário de mecânicas (o que roda de verdade)

- **Core loop**: cliente chega (rotação determinística `services_completed % n` — sem fila,
  sem escolha) → arrasta ferramenta → esfrega (distância acumulada) → resultado → moedas/XP.
- **5 serviços** = o mesmo gesto com números diferentes (recompensa 12/20/24/30/38;
  distância 1350/1550/1250/1050/900; desbloqueio lv 1/3/5/7/10).
- **Carinho**: tocar no pet → frase + corações; afeição 0–50 → ×1,25 de recompensa no teto.
- **Economia**: moedas; upgrade de estação (25×1,18^n, +7,5% comp., cap 120) e de utensílio
  (×1,24/nível, +4%, cap 30); combo (+2,5%/stack, cap 20).
- **Progressão**: XP 10/15; curva 50+25(n−1); 120 níveis ≈ 14.000 serviços ≈ 62 h ativas;
  50 pets travados por nível; carreira em 10 tiers (só texto/toast).
- **Meta**: login diário 7 dias; 3 missões diárias; evento semanal (só seg/ter aplicados);
  10 conquistas (IDs crus na UI); cofre offline (~54 moedas no early game — irrisório).
- **Staff**: só "Bia" (auto-contratada após 8 serviços, +2 moedas/5 s) — dos 6 do JSON.
- **Moedas mortas**: Brasas (sem onde gastar), franchise_tokens, prestígio (sem sistema).
- **Áudio**: 100% seno procedural (bipe 760 Hz = "bolha"; música = acorde em loop de 8 s).
- **Save/analytics/remote-config**: sólidos (Seção 4).

## 6. GDD × Implementado (matriz resumida)

| Promessa do GDD | Estado |
|---|---|
| Tutorial com spotlight | ✗ (flag `tutorial_complete` existe, fluxo não) |
| Paciência em 3 estágios | ✗ (campo `patience` no JSON, nunca lido — **ligado agora, Seção 15**) |
| Fila de 3 clientes com escolha | ✗ (rotação forçada) |
| Serviços com skills distintos | ✗ (5 skins do mesmo gesto) |
| Faixa 82–96% = Perfect, dosagem manual | ✗→**✓ agora** (Seção 15) |
| Prestígio, decoração com marcos visuais | ✗ |
| 80 conquistas / 120 pets | 10 / 50 (33 sem arte de estados) |
| i18n PT/ES/EN | ✗ (3 CSVs-stub de 6 chaves, nunca carregados) |
| Save robusto, analytics ético, remote config | ✓ |

## 7. Retenção e mecanismos "hipnóticos" (leitura honesta)

**Existentes (fracos):** streak de login (sem freeze), coleção (lista de texto, sem grid),
evento semanal nominal, cofre offline irrisório, juice procedural barato.

**Mortos por design:** recompensa variável (Perfect garantido = dopamina sem variação),
near-miss (o aro sugere timing mas não há risco), combo que nunca quebra, review sempre 5,0.

**Ausentes (padrão comercial):** sem decisões, sem perda/risco, sem social/compartilhamento,
sem pass/season, sem push com deep link, sem "só mais um banho" (sessão sem alvo/pressão).

**Leitura ética:** retenção comercial saudável nasce de *fun + progresso visível*, não de
manipulação; o plano prioriza variabilidade legítima (dicas com odds publicadas, clientes
VIP, riscos reais) e rejeita dark patterns agressivos (já estabelecido nas sessões anteriores).

## 8. UX/UI — as queixas do usuário, confirmadas

1. **"Rápido e fácil"** → auto-complete em 86% tornava todo banho PERFEITO em ~2–4 s
   (simulação: 2.000/2.000 perfeitos). **Corrigido (Seção 15).**
2. **"Cachorro fora da banheira"** → pet desenhado como decalque flat sobre cena
   isométrica, centro em (540, 840): cabeça acima da borda distante, banheira vazia à
   frente, sem oclusão. **Corrigido por recalibração de composição (Seção 15).**
3. **"Ícones bagunçados"** → glifos Unicode (★ ♥ ⌂ ⚙) como botões; `⌂` (U+2302) fora da
   fonte padrão vira □ em vários dispositivos; sem fonte empacotada. **Corrigido
   (ícones PNG + DejaVu empacotada, Seção 15).**
4. **"Telas bagunçadas"** → missões/coleção/mapa/ajustes são blocos de texto puro num
   painel, vazando IDs crus (`player`, `first_bath`…); toasts cobriam a navegação
   (y 120–198 × nav 155–237). **Parcialmente corrigido (nomes + toast reposicionado).**

## 9. Catálogo de defeitos (48)

**CRÍTICOS (design/funcionalidade)**
1. Camada de skill morta: auto-complete em ≥86% ⇒ sempre Perfect (`Main._rub` + `_finish_bath`).
2. `good`/`too_soon`/`overwashed` inalcançáveis; UI e texto dessas saídas = código morto.
3. Zero decisões: pet e serviço por rotação (`_dismiss_result`/`_new_client`).
4. Pet sem oclusão sobre a cena → "fora da banheira" (`SERVICE_PET_POSITIONS`).
5. Combo nunca quebra (Perfect garantido) ⇒ escalada falsa.
6. Review sempre 5,0 (`register_review` só via perfect/good, good inalcançável).
7. Sem tutorial (flag morta).
8. 33/50 pets sem arte de estados ⇒ sistema dirty/wet/sad inexistente para 66% da coleção.
9. Áudio 100% seno procedural — "sem graça" emocional.
10. Sem fonte empacotada (default do engine).
11. Menus = blocos de texto com IDs crus.
12. CTA morto "DOBRAR PONTUAÇÃO • EM BREVE" em todo resultado.
13. Brasas/franchise_tokens/prestígio sem sistema; cosméticos sem efeito.
14. Ajustes exibem volume sem controle.
15. Sem loja (catálogo IAP existe, UI não).

**GRAVES (UX/visual)**
16. Ícones Unicode dependentes de fonte (tofu). 17. Prateleira mostra as 5 ferramentas em
todas as salas. 18. Toasts sobre a navegação. 19. Pill composto "NV.1 0% • ×1".
20. Hit-radius fixo 245 independente do sprite (330/390/445). 21. Soltar drag sobre botão
dispara o botão (sem trava de gesto). 22. Título da sala desenhado sobre a ilustração.
23. Badge da estação em (70, 500) fixo. 24. Toast da Bia "+5% banho" ≠ implementação
(+2 moedas/5 s) ≠ staff.json (`bath_speed 0.05`). 25. `patience`/`preferred_service`/
`base_tip`/`city` = campos mortos. 26. 5/7 eventos semanais mortos (`LiveOps` só seg/ter).
27. 5/6 staff não contratáveis. 28. Cofre offline irrisório e ≠ docs ("50% do rate").
29. Recompensa dia-7 (pet Mel) pode redundar com unlock de nível, sem compensação.
30. Early game plano: 5 serviços em ~25 min; resto = repetir o gesto 14.000×.
31. Endgame absurdo: estação 120 = 1,7×10¹⁰ moedas; renda ×5.900. 32. Sem punição de
falha além de retry (ok no onboarding, vazio depois).

**ENGENHARIA/CONTEÚDO**
33. 1 cena/12 linhas; UI 100% em código. 34. Sem `.import` ⇒ nunca aberto no editor.
35. Testes por grep (congelam bugs). 36. Runtime Godot nunca validado. 37. Produto fora da
`main`. 38. Analytics: arquivo cresce sem rotação; reescreve buffer a cada flush.
39. Save: versão > atual ⇒ save descartado em silêncio. 40. 76 MB de PNG sem compressão/
atlas; export Web inclui tudo. 41. `active_play_seconds` conta com menus abertos.
42. Sem crash reporting/pause. 43. Duas definições de carreira conflitantes
(`career_track` × `establishments.json` morto). 44. `economy_curves.json` conflita com
defaults do `RemoteConfig`. 45. Só 3/6 missões do `daily_missions.json`. 46. Localização
não carregada. 47. `queue_redraw()`/frame + alocações por bolha. 48. Sem i18n runtime.

## 10–12. Arte, áudio, performance e economia (números)

- Arte: estilo flat-cartoon **bom** (fundos 768×1376, pets 512 RGBA recortados corretamente —
  o "fundo cinza" é só o viewer compondo transparência). Problema é **integração**
  (perspectiva isométrica × sprite flat, sem oclusão) e **volume** (PNG sem compressão).
- Níveis → tempo: lv 10 (todos os serviços) ≈ 25 min; lv 20 ≈ 95 min; lv 120 ≈ 62 h do
  **mesmo gesto**.
- Simulação original do skill: 2.000/2.000 perfeitos em ~4 s ⇒ confirma "rápido e fácil".

## 13. Plano de reestruturação (fases, com gates)

- **Fase 0 (1–2 sem)** — fundação e feel: merge/PR para main + CI headless; reconstruir o
  skill (finalizar manual, janela real, risco de passar); recalibrar composição das
  estações; ícones/fonte reais; remover CTA morto; toasts; nomes na coleção; perf básico.
- **Fase 1 (2–3 sem)** — loop com decisão: fila de 3 clientes com paciência visível, gestos
  distintos por serviço, clientes VIP, dicas variáveis com odds publicadas, tutorial
  spotlight.
- **Fase 2 (3–4 sem)** — UI real: telas `.tscn` (grid de coleção, missões com claim
  individual, staff contratável, loja com adapters de ads/IAP, sliders reais), tema,
  i18n via TranslationServer.
- **Fase 3 (2–3 sem)** — retenção: streak com freeze ganhável, pass 28 dias, comeback,
  push deep link, 7/7 eventos com kill switch, compartilhamento antes/depois.
- **Fase 4 (2–3 sem)** — conteúdo/economia: ligar ou apagar os JSONs mortos, rebalance via
  simulador (alvos: primeiro perfect <20 s; lv 10 ≈ 15 min), arte de estados dos 33 pets,
  música/SFX reais.
- **Fase 5** — lançamento: legal/keystore/privacy/Data Safety, Firebase (analytics/crash/
  remote config), ASO, soft launch BR com gates (D1 > 40%, tutorial > 85%, crash-free > 99%).

## 14. Quick wins de maior percepção (semana 1)

1. Skill manual com janela real · 2. Pet dentro da estação · 3. Ícones PNG + fonte OFL ·
4. Remover "EM BREVE" · 5. Nomes em vez de IDs · 6. Reposicionar toasts · 7. CI + merge.

---

## 15. Status de implementação — Fase 0 (sessão 2026-09-19)

Executado e verificado (gdlint limpo, 17/17 testes, `validate_project` 0 erros):

1. **Skill real (C1/C2)** — `BathService.GOOD_FLOOR = 0.62`; auto-complete removido de
   `_rub`; **soltar a ferramenta finaliza** (`_end_pointer` → `_finish_bath` quando
   progress ≥ 0.62; abaixo disso retoma a esfregada sem punir); janelas vêm do
   `RemoteConfig` (0.82–0.96 = Perfect, 0.62–0.82 = Good, >0.96 = Overwashed); paciência do
   pet modula o tempo (`×0.6–1.25`); aro agora mostra a **faixa verde fixa** e colore o
   preenchimento por zona (âmbar/verde/vermelho); **barra de paciência** no topo.
   Simulação pós-fix: novato 66% perfect/11% good/14% over/8% timeout × atento 88/4/8/1 —
   qualidade agora varia com habilidade; todos os desfechos alcançáveis.
2. **Composição das estações (C4)** — recalibrado via `tools/compose_preview.py`
   (replica o render offline; lê as posições do código): banho (520, 1040), tosa
   (560, 1090), secagem (450, 1190), perfume (560, 1075), estilo (570, 1300). Validação
   visual: pet assentado **dentro/sobre** a estação real nas 5 salas — sem arte nova.
3. **Ícones + fonte (C9/C10 de UI)** — `tools/gen_ui_icons.py` gera 4 ícones PNG 64 px
   (estrela/coração/casa/engrenagem) usados via `Button.icon`; **DejaVu Sans (Regular+
   Bold) empacotada** em `art/fonts/` com licença; `project.godot` define
   `gui/theme/custom_font`; canvas usa `UI_TITLE_FONT` nos títulos.
4. **Higiene de UI** — CTA "EM BREVE" removido (teste atualizado para `assertNotIn`,
   impedindo regressão); toasts movidos para y 240–304 (fora da navegação 155–237);
   coleção exibe **nomes** (ContentDB agora carrega `staff.json` e `achievements.json` —
   2 dos 12 arquivos mortos ligados à UI); toast da Bia coerente com a implementação.
5. **CI (E5)** — `.github/workflows/ci.yml`: lint gdlint do projeto inteiro, testes
   Python, `validate_project`, e **runtime Godot 4.3 headless** (`--import` + smoke de
   120 frames) — fecha o gap de "nunca rodou em lugar nenhum".

**Em aberto (próximas fases):** fila/clientes com escolha (Fase 1), telas `.tscn` reais
(Fase 2), áudio licenciado/composto (Fase 4 — requer aquisição de assets fora do sandbox),
merge na `main` via PR (a abrir pelo usuário, que detém a decisão de merge).
