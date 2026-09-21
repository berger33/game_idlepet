# Implementação P0 — Nível Profissional (sem assets novos)

**Data:** 2026-09-21 · **Branch:** arena/01a0c221-game-idlepet · **Commit:** aa5d2f0
**Base:** docs/AUDITORIA_PROFISSIONAL_UX_STORYTELLING_RETENCAO.md

## Objetivo
Elevar de slice bom para publicável D1>40% D7>15% D30>6% usando apenas código/texto.

## O que foi implementado

### 1. Storytelling (PetStories + ChapterStories)
- **PetStories.gd** (core/story/):
  - `bio(profile)`: "%s %s %s — %s." com breed + city_flavor (vila_pacata/subúrbio/centro/metrópole/praia/serra/capital) + temperamento (10 variações) + service need (rolou na lama, pelos embaraçados, etc). Hash estável por pet_id para consistência.
  - `queue_story(profile, service)`: paciência curta/média/tranquilo + paga bem/+/normal + need micro-narrativa. Usado na fila para curiosidade.
  - `affection_memory(pet_id, level)`: níveis 1/5/10/20/25/50 com nome ContentDB.pet_name — diário de vínculo.
  - `result_thanks(profile, perfect)`: agradecimento por temperamento (happy abana rabo, calm prrrr, playful pula, anxious aliviado, fearful aninha, irritated até que ficou bom) + ★ Perfeito!
- **ChapterStories.gd**: 10 tiers com title/char/text/act (Ato 1 Sobrevivência, Ato 2 Equipe, Ato 3 Legado). Personagens: Você, Bia, Dra. Luna, Téo, Seu Zé, Maya, Rede, Instituto, Império. Métodos `intro(tier)`, `act_for_level(level)`, `narrative_for_reveal(tier)`.

**Integração:**
- Fila: info_label agora mostra base_info + story_line
- Resultado: detail mostra stars + moedas + XP + tip + thanks personalizado + prova social + memória
- Coleção: card tooltip com bio, sub com afeto + memória, fonte menor quando tem memória
- Mapa: lista de estabelecimentos com ato + char + snippet 90 chars + narrativa completa do tier atual

### 2. Gatilhos Mentais

| Gatilho | Implementação | Arquivo |
|---|---|---|
| **Perda** | Cliente saindo mostra "💔 X foi embora! -Y moedas" + forced_state sad 1.2s + lost_coins no analytics | Main.gd _client_left |
| **Escassez** | Rush label "🔥 PICO ×2 — Ns" + ProgressBar 165px com fill amarelo, ratio = rush_left/total, visível só durante pico. Timer pré-pico "⏳ pico em Ns" quando <=15s. Weekly reset label "reseta amanhã/em X dias" | Main.gd + RushTuning.gd + LiveOps.weekly_reset_label |
| **Prova social** | Pill azul rotativa a cada 8-12s: "💬 Ana: Caramelo amou o banho! ★★★★★". Mock local plausível, piscada alpha 0→1. Resultado também mostra "💬 X acabou de avaliar: ★★★★★" | Main.gd _refresh_proof_social + RushTuning.proof_text |
| **Recompensa variável** | DailySpin 1×/dia: pesos 30/25/12 coins 0.8/1.5/2.5x, 20/8 brasas 1/2, 5 freeze. Escalada via Rewards.scaled + Rewards.SECONDS. UI em missões "🎡 Roleta Diária" com estado Disponível!/Volta amanhã | DailySpin.gd + MetaPanel._build_missions |
| **Progresso dotado** | Weekly pill "📦 Semanal D/T • P% • Baú: X/7 • reseta..." + contagem feita de claimed_weeklies. Streak note com "Se perder, -1 dia (use ❄️ freeze!)" | MetaPanel |
| **Compromisso** | Streak + spin + daily login no mesmo bloco visual para coerência | MetaPanel |
| **Afeição** | Diário afeto em coleção + memória no resultado + bio tooltip | PetStories |
| **Curiosidade** | Queue story + bio + ??? com silhueta já existente | PetStories |
| **IKEA** | Shop name + favorite pet já existia, agora + memória reforça investimento | - |
| **Novidade** | 5 serviços + temperamento + prova social rotativa | - |

### 3. Retenção D0/D1/D7/D30

- **D0**: perda quantificada aumenta urgência, rush bar deixa escassez visível, proof social cria mundo vivo nos primeiros 10s.
- **D1**: spin diário (gatilho novo forte) + streak com aviso de perda + offline + evento meta. Push já agenda com NotificationManager.permission_granted sincronizado.
- **D7**: semanal progress pill + baú + reset label + passe 28 + 7 missões. Jogador vê % e falta 1.
- **D30**: diário afeto 50 + memórias + capítulo narrativa + pesquisa + prestígio. Cada afeto nível conta história, não só número.

### 4. DDA (Dynamic Difficulty Adjustment)

- `consecutive_fails` contador. 3 fails seguidos → `assistance_clients = 3`, toast "💡 Assistência: janela maior + paciência por 3 clientes!", fail analytics com streak.
- `_configure_current_service`: patience_factor ×1.15 e window_bonus +0.20 quando assistance_clients>0, via RushTuning helper.
- `_dismiss_result`: decrementa assistance_clients. Sucesso zera fails.
- Evita churn de jogadores que travam em perfect.

### 5. Limites preservados

- Main.gd 1164 → 1065 linhas (remoção de comentários ## + compactação + helper RushTuning). Pattern static helper (SalonTuning/Research) mantido.
- GameState 37 métodos públicos (<38 limite).
- validate_project.py 0 errors 0 warnings.
- Sem assets novos, sem alteração de JSON.

## Próximos passos P1 (não nesta sessão)

- Caixa misteriosa combo 10, moedas voando do pet ao pill, QR no share, staff diálogos por tier, modo treino fantasma.

## Como testar

1. Deixar cliente ir embora → ver toast "-X moedas perdidas" + pet triste.
2. Esperar rush → ver barra amarela diminuindo + label "🔥 PICO ×2 — Ns" + pill proof trocando a cada 10s.
3. Falhar 3× → ver assistência.
4. Atender perfect → ver thanks personalizado + memória se afeto >=1 + proof "acabou de avaliar".
5. Abrir coleção → ver bio tooltip + memória "Primeiro carinho!".
6. Abrir missões → ver roleta diária girável 1×/dia + semanal "📦 Semanal 2/7 • 28% • Baú: 2/7 • reseta em 3 dias".
7. Abrir mapa → ver lista com "Ato 1 — Sobrevivência • Bia: Bia chegou com tesoura emprestada..." + card "📖 Ato 2 — Equipe\nTéo: Téo, tosador rápido..."

## Métricas esperadas

- D1: +5-8% com spin + perda visível
- D7: +3-5% com progress pill + diário
- D30: +1-2% com memórias + narrativa capítulos
- Redução churn em fail streak 3×: -15% abandono
