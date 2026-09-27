# Auditoria Universal — PetShop Tycoon: Do Banho à Rede
**Data:** 27/09/2026 · **Branch:** `arena/01a0e504-game-idlepet` · **Base:** main @ `72e8d45`

## 0) Resumo executivo

O projeto está **sólido**: CI verde (lint + 68 testes Python + validação estrutural + runtime Godot 4.7.2 headless), 59 scripts GDScript sem erro de parse/lint, 0 referências `res://` quebradas, 0 sinais com assinatura incompatível, localização completa em 3 idiomas e save com migração v0→v14 íntegra.

Ainda assim, esta auditoria encontrou **5 bugs reais** (1 de perda de progresso, 1 de compliance de ads, 3 de contrato de sinal + 1 de localização) — **todos corrigidos nesta branch, com testes de regressão**. As seções 3–5 listam melhorias e passos pendentes priorizados.

## 1) Metodologia (o que foi verificado)

| Checagem | Ferramenta | Resultado |
|---|---|---|
| Parse GDScript (59 arquivos) | `gdparse` (gdtoolkit) | ✅ 0 erros |
| Lint GDScript | `gdlint` com `.gdlintrc` do repo | ✅ 0 problemas |
| Erros de parse específicos Godot 4 | `tools/gd_static_check.py` | ✅ 0 achados |
| Estrutura do projeto + dados | `tools/validate_project.py` | ✅ 0 erros, 0 warnings |
| Testes de dados/economia/contratos UI | `python3 -m unittest discover tests` | ✅ 68/68 (com numpy) |
| Referências `res://` em `.gd`/`.tscn` | script próprio de xref | ✅ 0 quebradas |
| Sinais conectados vs declarados | script próprio | ✅ 0 órfãos |
| Assinaturas de handlers de sinal | script próprio | ✅ 0 incompatíveis |
| Chaves `Loc.t()` vs CSVs (pt/en/es) | script próprio | 1 faltante → corrigida |
| Consistência dos CSVs de localização | parser CSV | 1 linha corrompida → corrigida |
| JSON de `data/` | parser | ✅ todos válidos |
| Simetria `to_dictionary`/`apply_dictionary` | diff de chaves | 1 chave perdida → corrigida |
| Padrões de risco (div/zero, `randi()%0`, await, dead refs) | grep dirigido | ✅ guardas presentes |

> O binário Godot 4.7.2 não pôde ser baixado neste ambiente (CDN de release bloqueado); a validação runtime continua coberta pelo job `runtime` da CI, que roda a cada push.

## 2) 🐛 Bugs reais encontrados (e corrigidos nesta branch)

### B1 — 🔴 Perda de cosméticos equipados a cada reinício
- **Onde:** `autoload/GameState.gd` — `to_dictionary()` escrevia `"active_cosmetics"`, mas `apply_dictionary()` nunca lia a chave.
- **Impacto:** todo load (boot, import de código, migração) zerava os acessórios equipados do pet silenciosamente.
- **Fix:** restauração sanitizada em `apply_dictionary` (só sobrevive cosmético possuído em `unlocked_cosmetics`) + teste de regressão com round-trip completo.

### B2 — 🟠 Política de anúncios nunca persistida (compliance)
- **Onde:** `autoload/AdsManager.gd` — a `AdsPolicy` era carregada do save no boot, mas `to_dictionary()` nunca voltava para `GameState.ads_policy`.
- **Impacto:** cap diário de rewarded (8/dia), cooldown de 180s, contagem de sessões e proteção pós-compra **zeravam a cada boot** — o limite ético de ads anunciado nos docs não era aplicável de verdade.
- **Fix:** `_persist_policy()` chamado após rewarded/interstitial/compra + testes de regressão.

### B3 — 🟡 Sinal `currency_changed` emitido com moeda errada (5 pontos)
- **Onde:** `GameState.gd` (compra de cosmético, pass day, baú de combo), `DailySpin.gd`, `Main.gd` (bônus do primeiro perfect), `MetaPanel.gd` (`_grant_ember`).
- **Impacto:** após ganhar/gastar **embers**, o evento emitido era `&"coins"`. Hoje o HUD ignora o parâmetro (bug latente), mas o contrato do `EventBus` fica quebrado para qualquer listener futuro (Analytics, badges, loja).
- **Fix:** todos os 6 pontos agora emitem `&"embers", float(embers)`; grep de verificação final anexado ao commit.

### B4 — 🟡 Chave de localização inexistente em release
- **Onde:** `Loc.t("IAP_STORE_UNAVAILABLE")` em `autoload/IAPManager.gd:79` — chave ausente dos 3 CSVs.
- **Impacto:** em build release, o toast mostraria a chave crua `IAP_STORE_UNAVAILABLE` ao jogador.
- **Fix:** chave adicionada em pt_BR/en_US/es_ES.

### B5 — 🟢 CSV pt_BR com linha de 3 colunas
- **Onde:** `data/localization/pt_BR.csv:536` (`KIDS_MODE_ACTIVE`) — vírgula sem aspas.
- **Impacto:** o parser custom do `Loc` tolerava, mas qualquer importador CSV padrão (Godot, ferramentas, planilhas) truncaria o texto.
- **Fix:** valor entre aspas; verificação por parser CSV confirma 0 linhas inconsistentes.

### Testes de regressão
`tests/DomainTests.gd` ganhou `_test_regressoes_auditoria_2026_09_27()`: round-trip de `active_cosmetics` (incluindo descarte de item não possuído) e persistência da AdsPolicy após rewarded/compra. Rodam no job runtime da CI (Godot headless com autoloads reais).

## 3) ✅ Conformidades confirmadas (evidências)

- **Save/persistência:** escrita atômica temp+rename, 3 backups rotativos, SHA-256 + XOR de ofuscação, migração sequencial v0→v14 sem lacunas, rejeição de versão futura (anti-rollback), `SAVE_VERSION=14` coerente com `to_dictionary`.
- **Sanitização de load:** todos os campos numéricos clampados, arrays validados contra catálogo (`_valid_pet_array`, `_valid_research_array` com validação topológica de pré-requisitos — item M3 da auditoria de 23/09 já implementado), settings sanitizadas com clamp de fonte/volume.
- **Anti-abuso de tempo:** `TimeManager` clampeia offline a 48h e sinaliza relógio voltado; `DailySpin` tem guard de rollback (M4 implementado); streak diário com freeze e janela de 60h.
- **Ads/IAP éticos:** rewarded com cap+cooldown+kill-switch; interstitial só após 3 sessões e 20 min, nunca após compra recente; IAP release retorna indisponível sem provider (com a chave agora existente); ledger idempotente.
- **LGPD/analytics:** sem consentimento nada é persistido; fila apagada ao revogar; eventos com nome limitado a 40 chars.
- **Localização:** 606 chaves × 3 idiomas, todas as chaves dinâmicas (`EVENT_%d`, `SEASON_*`, `RARITY_*`, `ACH_*`…) com cobertura verificada; fallback pt_BR no `Loc.t`.
- **Acessibilidade:** contraste WCAG AA comentado nas cores, `font_scale`, `kids_mode` com gestos facilitados e HUD simplificado, modo canhoto (parcial — ver M2 abaixo), colorblind, reduced particles, eco mode.
- **Itens da auditoria 2026-09-23:** M1 (ícone do parque) ✅ feito, M3 ✅, M4 ✅, B2 (corte em word boundary) ✅.

## 4) 📈 Melhorias recomendadas (priorizadas)

### P1 — curto prazo (sem risco de save)
1. **Casas vazias em `core/`** — 19 diretórios só com `.gitkeep` (`achievements/`, `economy/`, `pets/`, `save/`…). O domínio real vive em `autoload/` + `core/gameplay` + `core/progression`. Ou mover os sistemas para suas casas (ex.: `Economy.gd`→`core/economy/`), ou remover os diretórios-fantasma para o mapa do repo refletir a realidade.
2. **Dead code no `AdsManager._ready`** — bloco `if GameState.has_method("ads_policy_dict"): pass # futuro` e `_on_currency_changed` vazio; remover ou ligar ao fluxo real (a persistência agora acontece via `_persist_policy`).
3. **`Loc.has_method("t")` defensivo** em `GameState.gd` (~linha 989): `Loc` é autoload com `t()` garantido; o fallback hardcoded em pt-BR nunca roda e duplica texto. Remover o ternário.
4. **`Analytics.flush_offline` sobrescreve a fila** em vez de acumular lotes anteriores. Para o adapter offline atual é aceitável, mas quando o Firebase real entrar o flush deve *append* + truncar só o que foi entregue (contrato já documentado no arquivo).
5. **Testes Godot faltantes:** cobertura runtime para `SaveManager` round-trip completo (export/import code), `ParkService` (janela de foto/treat) e `Rewards.for_kind` — hoje cobertos só indiretamente.

### P2 — médio prazo (vertical slice → MVP)
6. **Validação em aparelho real** continua como maior risco: perfil de frame/memória com a arte procedural por-frame (253 MB de arte, geometria recalculada em `PetShopCanvas`/`ParkCanvas`), temperatura e loading. Documentado desde o início, ainda pendente.
7. **Playtests humanos (5+)** do gesto de banho — nenhum dado de diversão existe ainda; métricas não são fabricáveis por código.
8. **M2 remanescente (auditoria 23/09):** modo canhoto espelha só prateleira/botões; fila e top bar mantêm posição. Decidir: completar ou documentar como escopo.
9. **BGM por tier** existe (`bgm_quintal/clinica/imperio`) mas o master/licenciamento final segue pendente; SFX já são definitivos (gerados e versionados).
10. **Captura MP4 9:16** do botão "Momento" em aparelho — hoje informa que é Vertical Slice; decidir fallback antes do marketing.

### P3 — produto/loja (bloqueadores externos, sem ação de código)
11. Conta Play Console/Firebase/AdMob do publisher, SKUs em test track, keystore fora do Git, package definitivo (`com.seunome.petshoptycoon` ainda placeholder), política de privacidade revisada, Data Safety preenchido, assets de loja. Tudo já mapeado em `docs/READINESS_AUDIT.md` — nenhum item mudou de status desde 23/09.

## 5) ⏳ Passos pendentes objetivos (checklist)

- [ ] **GitHub Pages nunca publicado:** o workflow `web-pages.yml` existe mas **nunca rodou** (0 runs) e o Pages está desativado no repo (API 404). O doc "Release Web completo" é aspiracional — habilitar Pages em Settings e disparar o workflow (ou criar tag `v*`), e então validar o build servido (iframe, áudio com gesto, save em IndexedDB).
- [ ] Rodar `godot --headless --path . res://tests/domain_tests.tscn` localmente ao menos 1× num desktop com GPU (CI cobre headless; smoke visual 6-passos de `tools/smoke_interact.gd` segue sem registro de execução humana).
- [ ] Confirmar em dispositivo: haptics (`Input.vibrate_handheld` só roda em mobile), deep link `--section=`, notificações locais via adapter Android.
- [ ] Executar/validar export Android com o template `docs/export_presets.android.template.cfg` (target 36 — confirmar exigência atual da Play).
- [ ] Definir dono para a revisão jurídica de `PRIVACY_POLICY.md`/`TERMS_OF_SERVICE.md` (drafts prontos).
- [ ] Decisão de conteúdo: não escalar além dos 50 pets antes do gate de playtest (recomendação estável do roadmap).

## 6) Estado final desta branch

| Arquivo | Mudança |
|---|---|
| `autoload/GameState.gd` | B1 restauração de `active_cosmetics`; B3 em 3 pontos de embers |
| `autoload/AdsManager.gd` | B2 `_persist_policy()` em rewarded/interstitial/compra |
| `core/progression/DailySpin.gd` | B3 emit correto de embers |
| `scenes/main/Main.gd` | B3 emit correto de embers (bônus 1º perfect) |
| `scenes/main/MetaPanel.gd` | B3 emit correto de embers (`_grant_ember`) |
| `data/localization/*.csv` (3) | B4 `IAP_STORE_UNAVAILABLE`; B5 linha 536 quotada |
| `tests/DomainTests.gd` | testes de regressão B1/B2 |

**Validação pós-fix:** `gdparse` ✅ · `gdlint` ✅ · `gd_static_check` ✅ (59 arq.) · `validate_project` ✅ (0E/0W) · `unittest` ✅ (68/68). O job runtime da CI revalida no Godot 4.7.2 a cada push.

*Auditoria sem wipe e sem bump de `SAVE_VERSION`: todos os fixes são compatíveis com saves v14 existentes.*
