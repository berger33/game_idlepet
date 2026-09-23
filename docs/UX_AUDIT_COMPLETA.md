# Auditoria Completa de UX e Interface — PetShop Tycoon

Data: 2026-09-21 · Branch `arena/01a0c221-game-idlepet` · Base `e6b035f`
Escopo: toda a experiência jogável offline, do primeiro toque ao prestígio, em portrait 1080×1920, Godot 4.7.2 Compatibility.

## Metodologia
- Leitura de código: `scenes/main/Main.gd` (1077 linhas), `MetaPanel.gd` (876), `PetShopCanvas.gd` (1081), `GestureArt.gd`, `SalonTuning.gd`, `SalonPanels.gd`, `TutorialFlow/Overlay`, `AudioManager`, `SessionFeedback`, `Goals`, `Missions`, `GameState`, `ContentDB`, `StationArt`, `ChapterArt`, `PetCosmeticsArt`.
- Fluxos manuais simulados via `tools/validate_project.py` e `tests/test_data_and_economy.py` (59 testes).
- Heurísticas: Nielsen + Game UX (clareza de objetivo, feedback imediato, controle, prevenção de erro, reconhecimento vs memorização, estética, acessibilidade, retenção).

---

## 1. First Time User Experience (FTUE) — CRÍTICO

### O que existe
- Tutorial em 3 passos: fila → prateleira → pet, com spotlight (4 retângulos dim) e borda pulsante `ffd54f`.
- Skip sempre visível.
- Mini-tutorial por serviço novo via `services_taught` em settings.
- Offline card e comeback no `_ready`.

### Problemas
1. **Spotlight corta texto**: label fixa em `y = r.end.y +20` pode sair da tela se alvo for baixo (pet a 1160). Sem safe-area.
2. **Sem seta indicadora**: retângulo amarelo não aponta direção; jogador de primeira vez não entende “arrastar”.
3. **Texto denso**: “2/3 · Pegue o sabonete e leve até Caramelo” sem ícone do sabonete; reconhecimento exige leitura.
4. **Skip pequeno e no rodapé**: botão 300×64 em y=1830 pode ficar sob notch/gesto do Android.
5. **Primeiro pet sem contexto**: nome “Caramelo” aparece antes de qualquer vínculo; falta micro-narrativa “Seu primeiro cliente chegou!”.

### Recomendações (P0)
- Label do tutorial deve reposicionar para cima se `r.end.y > 1400`, e usar safe_top.
- Adicionar ícone do utensílio + seta animada no `TutorialOverlay`.
- Skip mover para 45, 155+safe_top ao lado dos nav icons, com fundo mais contrastado.
- Primeiro cliente: toast “🐾 Caramelo, vira-lata caramelo, está nervoso — banho paga +0%” antes do passo 1.

---

## 2. Core Loop e HUD — ALTO

### Estrutura atual
```
Top bar: [Moedas][★ média][NV% combo][Pico][Evento]
Fila: 3 cartões [Nome][Serviço][Temperamento + ●●●][Barra paciência]
Centro: pet + estação + gesto + VFX + aro de dosagem no utensílio
Rodapé flutuante: instrução + botão upgrades (86×86 canto sup dir)
```

### Pontos fortes
- Aro de dosagem no utensílio = assinatura, sem HUD intrusivo.
- Barra de paciência no topo (270,128) fina mas visível.
- Beat pulse ancorado no áudio real (`AudioManager.beat_phase()`).

### Problemas
1. **Top bar lotada**: 4-5 pills 280+235+300+210 = 1025px em 990px container + separação 18 → overflow em telas menores / fonte grande.
2. **Pills sem ícone**: moedas, review, combo são só texto; reconhecimento lento.
3. **Barra de paciência sem rótulo**: jogador não sabe que é tempo; cor muda mas sem texto “Paciência”.
4. **Instrução genérica**: “Arraste o sabonete até Caramelo” sem mostrar qual sabonete é (ícone pequeno) e sem estado “solte para finalizar” quando no Perfect.
5. **Upgrades button escondido**: 86×86 em (952,150) — canto superior direito, mesma área de gesto? Em left-handed, prateleira vai para esquerda mas botão continua à direita → inconsistência.
6. **Goal label sobrepondo estação**: em safe_top grande, goal_row em 492+safe*0.5 pode colidir com level_box (70,500).

### Recomendações (P0/P1)
- Top bar: usar `FlowContainer` ou reduzir para 3 pills principais (moedas, combo, evento) e mover review para dentro do card de resultado / meta panel. Adicionar ícones PNG (coin, star, combo).
- Barra paciência: adicionar ícone ⏳ + texto “PACIENTE” à esquerda, altura 18→22 para acessibilidade, e tooltip ao tocar.
- Instrução: quando `progress >= target_min && <= target_max`, trocar para “✓ SOLTE PARA PERFEITO!” verde pulsante + haptic leve.
- Upgrades: mover para (170,150) em left-handed, e adicionar badge numérico “2” com quantidade de upgrades acessíveis.
- Goal: ancorar abaixo da fila, não fixo em 492, usando `queue_row.position.y + queue_row.size.y + 12`.

---

## 3. Fila de Clientes — ALTO

### Atual
- 3 cartões Button 320×175, com nome, serviço, info (temperamento + ●), barra.
- Borda colorida por raridade, VIP = “VIP ” prefix, visitante = “✦”.
- Paciência drena com pesquisa, rush, mood_buff.
- Cliente sai sem reputação (corrigido).

### Problemas
1. **●●● incompreensível**: “Paga” com círculos não tem affordance; jogador novo não associa a moedas.
2. **Info truncada**: fonte 20px para “agitado  ●●●” em 320px largura → em pt-BR “Ansioso” pode quebrar.
3. **Barra fina (10px)**: difícil ver de longe; sem contraste em fundo claro.
4. **Estado vazio “· · ·”**: parece bug, não “chegando”. Sem animação.
5. **Sem comparação rápida**: 3 cartões iguais visualmente, mesmo com borda diferente; falta hierarquia “melhor escolha”.
6. **Toque acidental**: cartão inteiro é Button, mas barra de paciência também recebe input? `MOUSE_FILTER_STOP` ok, mas falta feedback de disabled (modulate 0.45 pouco).

### Recomendações
- Substituir ● por “$” ou ícone de moeda pequeno + número “+20%”.
- Aumentar barra para 14px, com fundo escuro 0.3 e borda arredondada.
- Vazio: “Chegando…” + ícone de patinhas andando + shimmer.
- Adicionar ordenação visual: cartão com maior pagamento tem leve escala 1.03 ou brilho.
- Disabled: além de alpha, aplicar `Color(263238,0.3)` overlay + ícone cadeado.

---

## 4. Gestos de Serviço — MÉDIO (já auditado, melhorias aplicadas em a9709e9)

- Banho, tosa, secagem, perfume, laço agora têm identidade.
- Feedback tátil por traço/zona/borrifada implementado.
- Ainda falta: **tutorial de gesto não mostra demonstração fantasma** — setas estáticas não ensinam direção do arrasto.
- **Perfume hold 0.32s** ótimo para acessibilidade, mas sem UI indicando “segure”.
- **Drop zone 80px** ainda pequena em telas grandes com dedo grosso; assistência motora aumenta para 104px mas deveria ser 120px.

---

## 5. Resultado e Recompensa — ALTO

### Atual
- Panel 860×720 em (110,430), título 72px, detalhe 39px, 2 botões.
- Celebração com estrelas se perfect ou combo>=5.
- Share 9:16 com marca, galeria/navigator.share.

### Problemas
1. **Hierarquia de botão**: primary “✓ CONTINUAR” e share mesmo peso visual (ambos 105/88 altura). Share deveria ser secundário.
2. **Detalhe denso**: “★★★★★\n+840 moedas • +15 XP\n+20% gorjeta\nVIP ×2\nBuddy” em 39px sem ícones → parede de texto.
3. **Sem barra de XP**: jogador não vê progresso para próximo nível no momento de maior dopamina.
4. **Sem feedback de coleção**: novo pet desbloqueado aparece como toast separado, não no resultado.
5. **Painel cobre pet**: resultado em 430y cobre pet feliz; deveria estar mais abaixo (700y) para ver celebração.
6. **Upsell panel idêntico**: mesmo tamanho/cor, mas decisão de aceitar/recusar sem mostrar recompensa extra exata.

### Recomendações (P0)
- Mover result_panel para y=600, altura 900→ permitir ver pet pulando.
- Adicionar XP bar fina abaixo do detalhe, com “NV.12 62% → 78%”.
- Detalhe: usar ícones + linhas: [coin icon] +840  [star] 5  [tip] +20%
- Share como link pequeno “📤 Compartilhar” abaixo, não botão grande.
- Upsell: mostrar “+140 moedas extras se aceitar” com cálculo real.

---

## 6. Painéis Meta (Missões, Coleção, Equipe, Melhorias, Loja, Mapa, Ajustes) — CRÍTICO

### Estrutura
- `MetaPanel` instancia `meta_screen.tscn`: Backdrop dim + Panel 80,290-1000,1240 + Scroll + Content.
- Cada seção rebuild limpa Content e adiciona info_rows via `INFO_ROW.tscn`.

### Problemas gerais
1. **Scroll sem indicador**: ScrollContainer sem barra visível; usuário não sabe que pode rolar (especialmente em coleção 50 pets).
2. **Close “↙” confuso**: ícone ↙ não é universal para fechar; deveria ser “✕” no canto sup dir.
3. **Panel fixo 950px altura**: em telas 16:9 com safe area, bottom 1240 pode ficar sob navegação gestual Android.
4. **Sem busca/filtro na coleção**: 50 pets em grid 4 colunas = 13 linhas, sem filtro por espécie/raridade.
5. **Info_row densa**: nome 28px + desc 24px + botão; em fonte grande (1.2) quebra layout.
6. **Sem empty state**: se sem missões, tela vazia sem “Volte amanhã”.

### Por seção

#### Missões
- Login diário + meta evento + diárias + passe + semanais tudo na mesma lista → sem agrupamento visual. Falta separadores “HOJE”, “SEMANA”, “PASSE”.
- Claim button sem confirmação; se clicar sem querer, perde animação.

#### Coleção
- Grid 4 colunas com cards 0.9/0.45 alpha, sem nome da raça visível quando bloqueado (“???”).
- Afeto “♥ 12/50” pequeno, sem barra.
- Conquistas listadas após pets, com mesmo info_row → confusão entre pet e conquista.
- Share conquista funciona mas sem preview.

#### Equipe
- Custo em moedas sem mostrar “+X% velocidade” claro; “VOCATION_GROOMER” traduzido mas sem tooltip do efeito numérico.
- Sem comparação “antes/depois”.

#### Melhorias
- Lista de 6 itens (estação + 5 ferramentas) sem agrupamento; custo e bônus na mesma linha → difícil comparar.
- Sem botão “Melhorar tudo” quando tem moedas.

#### Loja
- Cosméticos 23 itens + featured + tokens + rewarded + IAP offline tudo junto → scroll longo, sem categorias (Banheira, Parede, Acessório).
- Preço em moedas escalado mas sem mostrar “era 1200 → agora 840” (não mostra escalonamento).
- IAP “OFFLINE” com preço “R$” genérico → parece bug.

#### Mapa
- Texto corrido com “EVENTO: … CARREIRA: …” sem formatação, 28px em bloco único → parede de texto.
- Prestígio com preview “você volta a X” mas sem simulação visual de tempo.

#### Ajustes
- Sliders sem valor numérico ao lado (0.7 sem %).
- Toggles sem descrição do que muda (ex: “Modo daltônico” sem preview).
- Transferência por clipboard sem QR code; código longo pode falhar em Android.
- Idioma com botões “en_US” crus, sem bandeira/nome nativo.
- Shop name LineEdit 480px em HBox com label, sem botão salvar explícito (auto-save ok mas sem feedback).

### Recomendações (P0)
- Adicionar scrollbar visível custom ou fade no bottom indicando mais conteúdo.
- Close trocar para “✕” 84×84, posição fixa top-right do panel, com fundo PINK.
- Panel usar anchors + margin, não offset fixo, e respeitar safe area bottom.
- Coleção: adicionar filtros [Todos][Cães][Gatos][Lendários] como chips no topo.
- Missões: separadores com `StyleBoxFlat` colorido + título.
- Loja: abas [Destaque][Banheiras][Paredes][Acessórios] com `TabContainer` ou HBox de filtros.
- Ajustes: mostrar valor do slider “70%”, e preview de fonte ao lado.

---

## 7. Navegação e Arquitetura da Informação — MÉDIO

- Nav icons (missions, collection, staff, shop, map, settings) em HBox 45,155+safe_top, 82×82, com tooltip, sem label → primeira vez usuário não sabe o que é (ícone de coleção = pata? staff = chapéu?).
- Sem label permanente, só tooltip no hover (mobile não tem hover).
- Upgrades button separado da nav, mesmo sendo parte da progressão → 2 lugares para “melhorar”.
- Event pill “Hoje paga 2×” em 250px ao lado da nav, sem ícone, pode quebrar linha.

Recomendações:
- Adicionar labels curtas abaixo dos ícones em fonte 18, ou usar `TabBar` com ícone+texto.
- Mover upgrades para dentro da nav como 7º ícone com badge, ou manter mas com label “Melhorias”.

---

## 8. Visual e Arte — MÉDIO

- Fundos 5 por serviço, todos 9:16, mas sem variação por tier (mesmo quintal no nível 1 e 120, só nome da placa muda).
- StationArt evoluindo a cada 10 níveis (toalha/patinho/planta) — ótimo, mas sutil; precisa ser mais legível (ex: banheira muda de plástico para inox).
- Pet sprites 50 com 10 estados, mas sem sombra dinâmica quando pula (jump_height sem sombra que escala).
- Ferramentas PNG 116px, mas sem outline quando sobre fundo claro (ex: perfume claro sobre pet claro perde contraste).
- VFX com beat pulse ótimo, mas `effect_count = progress*18` gera até 18 círculos sobrepostos → overdraw e poluição visual no final.

---

## 9. Áudio, Haptics e Juice — BOM, com ajustes

- SFX por ação com identidade, pentatônica, pool 4 vozes, window chime — excelente.
- BGM relaxante restaurada (16s C/Am/F/G crossfade) — pedido do usuário, muito melhor para idle.
- Haptics em pickup, perfect, upgrade, pet happy — bom.
- Falta: **haptic em fail** é error (pesado) mas deveria ser light + som triste, não punição forte.
- **Volume sliders** sem preview sonoro ao soltar (deveria tocar SFX de teste).
- **Energia percussiva** entra no serviço mas sem fade visual correspondente (poderia pulsar borda).

---

## 10. Acessibilidade — PARCIAL

- Implementado: daltonismo (azul/laranja), assistência motora (janela +30%, tempo +25%, alvos maiores), fonte 0.8/1.0/1.2, mão esquerda (prateleira + ferramentas espelhadas), reduced_particles, eco_mode.
- Falta:
  - **Tamanho mínimo de toque**: queue cards 320×175 ok, mas nav icons 82×82 com separação 14 → área efetiva 96px, abaixo de 48dp? Em 1080p, 82px ≈ 48dp ok, mas com fonte grande precisa aumentar.
  - **Contraste**: texto “8d6e63” sobre branco 0.94 tem ratio ~3.5:1, abaixo de WCAG AA 4.5:1.
  - **Sem modo alto contraste**: fundo escuro opcional.
  - **Sem legenda para SFX**: jogador surdo perde chime da janela perfeita; precisa de vibração extra ou ícone visual “SOLTE!”.
  - **Left-handed incompleto**: upgrades button e queue_row não espelham.

---

## 11. Localização — BOM

- 30 strings cravadas localizadas, `ContentDB.pet_name/staff_name/...` via CSV.
- 3 idiomas: pt_BR, en_US, es_ES, 545 linhas cada.
- Problemas:
  - Tool display names ainda hardcoded em pt-BR em `SalonTuning.tool_display_name` (“o sabonete”).
  - Faltam plurais e gênero em algumas chaves (“%d moedas” vs “1 moeda”).
  - Shop name placeholder não localizado.

---

## 12. Progressão e Economia — UX confusa

- Moedas escaladas à renda (Rewards.scaled) — bom para não morrer, mas jogador não entende por que missão paga 840 e não 100 (sem tooltip “baseado na sua renda”).
- Upgrades com custo exponencial `pow(1.24, level)` sem preview de “próximo custo” ou ROI.
- Prestígio com keep 25% e start Lv10 — ótimo, mas UI não mostra simulação “você voltará a este ponto em 12 min”.

---

## 13. Retenção, Offline, Notificações — BOM

- Offline card com minutos, moedas, staff share, evento, daily pendente + double por brasa/ad — excelente.
- Comeback 48h com freeze — bom.
- Notificações em memória + permission_granted sync — funciona, mas sem quiet hours configurável.

---

## 14. Compartilhamento e Viralizacão — BOM

- Share 9:16 SubViewport com pet antes/depois, nome/raça/estrelas, logo, legenda clipboard — ótimo.
- Web share + galeria — bom.
- Falta: **sem watermark com QR code** para download.

---

## 15. Estados vazios e Erros — MÉDIO

- Fila vazia “· · ·” — parece bug.
- Sem estado “sem moedas” com CTA para missões.
- Sem estado “sem pets desbloqueados além do inicial” com progresso.
- Erro de ferramenta errada com toast “Use o sabonete” mas sem seta apontando para prateleira correta.

---

## 16. Performance e Eco — BOM

- Reduced particles limita a 42 bolhas, eco_mode desliga VFX — bom.
- Mas `queue_redraw()` todo frame em PetShopCanvas mesmo sem mudança → desperdício; deveria ser `queue_redraw()` só quando dirty.

---

## 17. Monetização UI — FRACO (bloqueador externo, mas UI precisa ser honesta)

- IAP “OFFLINE” com “R$” genérico → parece quebrado. Deveria mostrar “Em breve” com ícone cadeado e descrição do benefício.
- Rewarded “▶” sem texto “Assistir vídeo” → sem contexto.
- Sem tela “Remover anúncios” clara.

---

## 18. Plataforma — MÉDIO

- Back button fecha painéis — ótimo.
- Safe area top implementada, mas bottom não (gesture navigation Android).
- Left-handed parcial.
- Sem suporte a teclado/controle (Godot permite, mas não mapeado).

---

## Prioridade de Correção (Impacto × Esforço)

### P0 — Fazer agora (sessão atual)
1. Tutorial label reposicionamento + ícone + seta + skip reposicionado
2. Top bar overflow → Flow ou 3 pills + ícones
3. Barra paciência com rótulo + altura 18→22
4. Instrução com estado Perfect pulsante
5. Fila vazia “Chegando…” + shimmer + barra mais alta
6. Result panel reposicionado + XP bar + hierarquia share
7. Meta panel close “✕”, scrollbar visível, safe area bottom
8. Ajustes sliders com % + preview SFX
9. Queue pay pips → “$” com tooltip
10. Upgrades badge com contador

### P1 — Próxima sessão
- Filtros coleção, abas loja, separadores missões
- Labels nav icons
- Left-handed completo
- Contraste WCAG
- Haptic fail leve + visual SOLTE para surdos

### P2 — Futuro
- QR share, simulação prestígio, busca coleção, “Melhorar tudo”

---

## Conclusão
O jogo está em **early vertical slice jogável acima da média**, com gestos distintos, feedback rico e retenção D0/D1 sólida. Os maiores gaps de UX são **navegação sem labels, top bar lotada, estados vazios confusos, resultado denso e meta panels sem affordance de scroll**. Todos são corrigíveis sem assets novos, apenas com layout, ícones e textos.

