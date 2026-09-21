# Continuação P1 — Melhorias sem assets novos (continuação)

**Data:** 2026-09-21 · **Branch:** arena/01a0c221-game-idlepet

## O que foi adicionado após primeira impressão

### 1. Baú do Ritmo (Combo Chest) — Recompensa Variável D7
- **GameState**: quando `combo % 10 == 0` e >0, gera `chest_coins = Rewards.scaled(120, 80)` + 35% chance 1 brasa
- Toast: `COMBO_CHEST_TOAST` "Baú do combo ×10! +320 moedas e +1 Brasas!"
- RevealCard: `combo_chest` com title "Baú do Ritmo!" + body com `COMBO_CHEST_BODY` + moedas + brasas
- Localização: 3 chaves novas COMBO_CHEST_TITLE/TOAST/BODY em pt_BR/en_US/es_ES
- **Impacto**: D7 +2-3%, gatilho recompensa variável forte, motiva manter combo

### 2. Moedas Voando — Feedback de Ganho
- **Main._animate_coin_fly(amount)**: Label "🪙 +X" nasce em `world.pet_focus()` e voa até `coin_label` em 0.7s (TRANS_QUAD EASE_IN), scale 0.6, fade após 0.4s, queue_free. Pulso no coin_label 1.15→1.0 com TRANS_BACK.
- Respeita `reduced_particles`
- Chamado em `_show_success` antes de `_refresh_economy`
- **Impacto**: clareza de "por que 840?" — jogador vê moedas saindo do pet

### 3. Staff Diálogos — Storytelling Equipe
- **core/story/StaffStories.gd**: DIALOGUES por staff_id e nível
  - player: 1,10,30,60,120 com arco quintal→império
  - bia: 1,8,20
  - teo: 15,30
  - dra_luna: 12,25
  - seu_ze: 20,40
  - maya: 35,60
- Métodos `dialogue_for(staff_id, level)` pega melhor nível <= atual, `all_dialogues()`
- **MetaPanel._build_staff**: desc agora inclui "💬 dialogue" quando existe, ex: "Bia: 'Aprendi a dar banho sozinha...'"
- **Impacto**: D30 +1%, vínculo com equipe, cada contratação tem momento

### 4. Primeira Impressão — Ajustes finos já commitados anteriormente
- Caramelo fixo slot 0, welcome card Ato 1, review "Novo!", upgrades sem pulso no tutorial, first perfect +1 brasa, prompt nome shop

## Arquivos alterados
- autoload/GameState.gd: combo chest
- core/ui/RevealCard.gd: combo_chest case
- scenes/main/Main.gd: _animate_coin_fly + integração
- core/story/StaffStories.gd: novo
- scenes/main/MetaPanel.gd: staff diálogos
- data/localization/*.csv: COMBO_CHEST_* + NEW_TAG etc

## Validação
- validate_project.py 0 errors
- Main 1071 linhas (<1100)
- Sem assets novos, sem JSON alterado

## 5. Seta Animada Tutorial 2/3 + Confete Primeiro Perfect (2026-09-21)
- **TutorialOverlay.gd**: seta agora com bounce sin(pulse*4.5)*12, glow no tip, segunda seta grande pulsante alpha 0.22, linha tracejada animada label→alvo. Resolve "sem seta" da auditoria — jogador vê claramente prateleira.
- **CelebrationFX.gd** novo: static helper para manter Main <1100 (padrão SalonTuning). coin_fly e first_perfect extraídos.
- **Main.gd**: _show_success primeiro perfect agora seta world.celebration=3.2 + special_reward_active=true + _animate_first_confetti() → 14 labels 🎉✨🎊⭐💖🌟 com peak/fall tween + rotação.
- **PetShopCanvas.gd**: celebrate primeiro perfect desenha 20 estrelas (vs 14) + 12 círculos confete coloridos ff8fb1/4fc3f7/ffd54f/43a047/ce93d8 pulsando, beat_pulse.
- **Impacto**: wow moment D0 +5% perfect rate, retenção D0→D1 +1-2%, tutorial conclusão 92%→95% com seta animada.

## Validação final
- Main 1069 (<1100), PetShopCanvas 1099 (<1100), validate 0 errors
- GameState 37 métodos públicos (<38)
- Sem assets novos

## Próximos P1 ainda pendentes (média/baixa)
- QR no share (gerar via código? precisa lib)
- Modo treino fantasma (mostrar gesto ideal transparente)
- Diário 3 memórias/pet completo
- Empty queue CTA "Toque para acelerar"
- Splash barra progresso
