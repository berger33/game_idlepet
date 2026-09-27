# Auditoria Universal (2ª passada) — PetShop Tycoon: Do Banho à Rede
**Data:** 27/09/2026 · **Branch:** `arena/01a0e514-game-idlepet` · **Base:** main @ `c0c15e1` (merge PR #9)
**Relação com a auditoria anterior:** complementa `AUDITORIA_UNIVERSAL_2026-09-27.md` (B1–B5 + P1–P3). Aquela
passada revalidou contratos e corrigiu 5 bugs de save/ads/localização/sinal. Esta passada foi além do estático:
**provou em execução** o comportamento do QR gerado pelo jogo, o do operador `%` do Godot sobre as strings de
localização e o estado real do build (tamanho dos assets, CI, Pages).

## 0) Resumo executivo

O projeto segue sólido (CI verde nos dois jobs, 59 scripts sem erro de parse/lint, 69 testes Python, 0 refs
`res://` quebradas, save v14 íntegro). **Mas esta passada encontrou 3 bugs reais + 1 classe de bug que os
testes existentes não pegavam — todos corrigidos nesta branch, com testes de regressão:**

| # | Bug | Severidade | Impacto |
|---|---|---|---|
| **B6** | **QR gerado pelo jogo é ilegível** (4 defeitos independentes no `QRCodeArt.gd`) | 🔴 Alta | Share/conquista com QR "escaneável" que nenhum leitor lê — canal viral do plano Nota10 não funciona |
| **B7** | Strings de localização formatadas com `%` inválido (`PRESTIGE_DONE`, `RESEARCH_EFFECT_combo_protection`) | 🟠 Média | Toast de prestígio e linha da pesquisa "Escudo de Combo" quebram (erro de runtime nos 3 idiomas) |
| **B8** | 3 ganhos de brasas sem `currency_changed` (afeto/pet, afeto/parquinho, conquista) | 🟡 Baixa | Contador de brasas da loja fica defasado até um rebuild |
| **B9** | Botão de rewarded da loja sempre habilitado sem provider | 🟢 Baixa | Botão "clicável" que nunca recompensa (deveria estar desabilitado) |

O achado central é o **B6**: a implementação de QR (Nota10 P1-10) nunca funcionou. A documentação do próprio repo
(`docs/AUDITORIA_NOTA10_RESULTADO.md`) afirma "QR real escaneável" e cita validação manual — a validação nunca
aconteceu, e nenhuma checagem de CI olha para a matriz gerada.

## 1) Metodologia (o que foi verificado nesta passada)

| Checagem | Ferramenta | Resultado |
|---|---|---|
| Parse GDScript (59 arquivos) | `gdparse` / `gdlint` | ✅ 0 problemas |
| Erros de parse no contexto do Godot 4 | `tools/gd_static_check.py` | ✅ 59 arquivos, 0 achados |
| Estrutura do projeto + dados + JSON | `tools/validate_project.py` | ✅ 0 erros, 0 warnings |
| Testes de dados/economia/UI (Python) | `python -m unittest discover -s tests` | ✅ 69/69 (68 + o teste novo de formatação) |
| Animações dos 50 pets / SFX / BGM / estantes | `verify_pet_animations`, `gen_sfx --check`, `gen_bgm --check`, `gen_shelf_art --qa` | ✅ 500 PNGs, 63 SFX, 3 BGM, 0 erros |
| Simulação econômica | `tools/economy_sim.py`, `tools/career_sim.py` | ✅ upgrades 1→20 em 20,53 min; nível 120 em ~61,9 h ativas (53,6 h "expert") |
| **QR: matriz de referência ISO/IEC 18004** | port fiel do `QRCodeArt.gd` para Python + **leitor QR próprio** (v1–v4, ECC L) + `python-qrcode` + OpenCV `QRCodeDetector` | ❌ matriz do jogo difere da referência em até 38% dos módulos e não decodifica; ✅ versão corrigida bate 100% e decodifica |
| **Formatação `%` do Godot** | leitura do `String::sprintf` em `godot/core/string/ustring.cpp` (4.4) + varredura dos 102 sites `Loc.t("K") % …` | ❌ 2 chaves formatadas de forma inválida → corrigidas; ✅ regra nova no teste |
| Sinais do EventBus emitidos vs conectados | script próprio | 13 sinais, 6 emitidos **sem nenhum listener** (API morta — ver P1) |
| Tamanho do build | inventário dos assets versionados | ⚠️ 851 PNGs = **261 MB** de arte (ver P1) |
| Estado do fluxo de entrega | `gh run list` / `gh workflow list` / `gh api .../pages` | ✅ CI verde na main (`36356902095`, jobs static + runtime); ❌ Pages nunca publicado (workflow existe, 0 runs, API 404) |

> O binário Godot não pôde ser baixado neste ambiente (CDN bloqueado), então a validação de runtime continua
> concentrada no job `runtime` da CI — que roda a suíte Godot headless a cada push, agora incluindo os testes
> de regressão desta auditoria. A validação do QR foi feita com decodificador independente, não com o próprio
> código do jogo gerando e lendo a si mesmo.

## 2) 🐛 Bugs reais encontrados (e corrigidos nesta branch)

### B6 — 🔴 QR do jogo é ilegível (4 defeitos somados)
- **Onde:** `core/ui/QRCodeArt.gd` (`_ensure_gf`, `_generate_real_matrix`); consumido por
  `autoload/ShareManager.gd:227` (cartão de banho) e `:318` (cartão de conquista).
- **Defeitos:**
  1. **Tabelas GF(256) corrompidas** — o laço rodava 256 iterações e a última gravava `_gf_log[1] = 255`
     (α^255 = 1 = α^0). Resultado: `gf_mul(1, x) ≠ x` e **todo o Reed–Solomon errado** (os codewords de ECC
     diferiam da referência já nos primeiros bytes).
  2. **Zigzag com laços trocados** — o padrão percorre *linhas* (coluna do par como laço interno); o código
     percorria o par de colunas por fora e as linhas por dentro, entregando os bits de dados na ordem errada.
  3. **Módulos reservados liberados** — as áreas de format info eram marcadas `-2` e um bloco "de reset"
     devolvia tudo a `-1` antes do placement, então **bits de dados invadiam o format info** (e deslocavam a
     fila de bits).
  4. **Format info transposto** — a primeira cópia dos 15 bits era escrita na horizontal onde o padrão exige
     vertical (e vice-versa), deixando o campo ilegível para qualquer leitor.
- **Evidência (executada):** port fiel do arquivo para Python + **leitor QR próprio escrito a partir do padrão**
  (validado contra matrizes de referência: `python-qrcode` v2 mask=1 e v3 mask=0 decodificam). Matriz do jogo:
  - `https://p.tycoon/a/first_bath` → 184/625 módulos errados, leitor responde "format info inválido", OpenCV não detecta;
  - `https://p.tycoon/p/caramelo?s=5&sh=PetShop` → 290/841 módulos errados;
  - `https://petshoptycoon.example.com/p/caramelo?s=5&sh=PetShop` → 413/1089 módulos errados.
  Com **as 4 correções**, a matriz fica **idêntica à referência** (0 diferenças, máscara 0, ECC L) e decodifica
  no leitor próprio **e no OpenCV** (`detectAndDecode`) nos 3 payloads. Cada correção isolada ainda falha — as
  quatro são necessárias.
- **Fix:** os 4 pontos ajustados em `QRCodeArt.gd` (+ comentários explicando cada um).
- **Regressão:** `tests/DomainTests.gd::_test_regressoes_auditoria_2026_09_27_v2()` compara a matriz gerada com
  um **vetor de referência de 25 linhas** (v2, ECC L, máscara 0) embutido no teste; roda no job `runtime` da CI.
- **Consequência de produto:** enquanto isso não existia, o QR era decoração. O canal "viral" (compartilhar com
  QR que leva ao link) não funcionava — vale conferir a copy de marketing que promete isso.

### B7 — 🟠 Localização formatada com `%` inválido (2 chaves, 3 idiomas)
- **Como o Godot se comporta** (`String::sprintf`, lido no fonte 4.4): `%` desconhecido → devolve
  `"unsupported format character"`; sobra de argumentos → `"not all arguments converted during string
  formatting"`; `%%` é o escape correto. O operador `%` do GDScript propaga esse erro como erro de runtime.
- **(a) `PRESTIGE_DONE`** — `"Franquia nível %d! +10% de R$ por nível"` tem `%` literal **sem escape** e é usada
  com o operador em `scenes/main/MetaPanel.gd:854` (toast do prestígio). O parser vê `% d` e aborta.
  **Fix:** `+10%%` nas 3 tabelas (`pt_BR`, `en_US`, `es_ES`).
- **(b) `RESEARCH_EFFECT_combo_protection`** — `"proteção de combo"` **não tem placeholder**, mas
  `core/progression/Research.gd::effect_text()` aplica `% percent` em toda chave de efeito → erro
  `"not all arguments converted…"` na linha do nó **"Escudo de Combo"** (`data/research.json`: `combo_protection: 1.0`).
  **Fix:** formatar somente quando o texto contém `%`.
- **Regressão:** novo teste Python (`LocalizationFormatTests`) varre os **102 sites** `Loc.t("chave literal") % …`
  do repositório e confere, nas 3 tabelas, contagem de placeholders × argumentos e ausência de `%` sem escape.
  Antes do fix ele acusa exatamente essas 2 chaves; depois, passa. Roda no job `static` da CI.
- **Nota:** a varredura anterior (`loc_args.py`, instrumento de auditoria) também apontou
  `CONTEST_RESULT_BODY` e `COLLECTION_SUMMARY`, mas eram **artefatos do analisador** (vírgula final no array).
  Ambos estão corretos no código.

### B8 — 🟡 Brasas ganhas sem sinal de moeda (3 pontos)
- **Onde:** `autoload/GameState.gd` — marco de afeto do pet tocado (`register_pet_interaction`, 5/20/50),
  marco de afeto no parquinho (cruza 5) e recompensa de conquista (`_unlock_achievement`).
- **Impacto:** o contador de brasas da loja (única tela que mostra brasas) podia ficar defasado até um rebuild.
- **Fix:** `EventBus.currency_changed.emit(&"embers", float(embers))` nos 3 pontos (mesmo padrão dos outros 16 sites).

### B9 — 🟢 Botão de rewarded anunciado mas inerte
- **Onde:** `scenes/main/MetaPanel.gd` (linha do "+1 brasa"), que passava `enabled = true`.
- **Impacto:** sem adapter/provider `AdsManager.request_rewarded()` sempre devolve `false`; o botão parecia
  disponível e só devolvia o toast de indisponível.
- **Fix:** `enabled = AdsManager.is_rewarded_available()` (a API já existia e não era usada).

### Não-bugs verificados (para não voltar à lista)
- `WEEKLY_LAST_DAY` existe nas 3 tabelas **com 3 placeholders** — o `% [0, 7, horas]` de `LiveOps.gd` está certo
  (a string PT hardcoded no `else` é código morto defensivo).
- `EVENT_7`/`EVENT_DESC_7` não existem porque `weekday()` é clampado em 0..6 — não é chave faltando.
- `RESEARCH_EFFECT_*`, `VOCATION_*`, `MISSION_METRIC_*`, `SHARE_SERVICE_*` (com `to_upper()`) estão todas presentes.
- Os 4 fixes do QR não mudam a API (`generate_image`, `make_texture_rect`) nem o tamanho do cartão.

## 3) ✅ Conformidades confirmadas

- **Save:** `SAVE_VERSION=14`, escrita atômica + 3 backups, envelope SHA-256/XOR, migração v0→v14 sem lacunas,
  clamp de offline 48 h, sanitização completa no load; regressões B1/B2 da auditoria anterior seguem verdes.
- **Economia:** curvas monotônicas (`economy_sim`), nível 120 em ~62 h ativas; prestígio a partir de 44k
  acumulados; offline com teto; combo/proteção; maestria por ferramenta.
- **Conteúdo:** 50 pets × 500 animações coerentes (`verify_pet_animations`), 63 SFX + 3 BGM versionados e
  determinísticos, 43 cosméticos, 15 nós de pesquisa, 606 chaves × 3 idiomas com paridade total.
- **Contratos:** nenhum emit de sinal com aridade errada; nenhuma referência `res://` quebrada (44 refs);
  `AdsPolicy` persistida; ledger de IAP idempotente.
- **CI:** `main` verde no merge do PR #9 — job estático (44 s) + Godot 4.7.2 headless (1 m 22 s: import, smoke
  de 120 frames, testes de domínio, `smoke_interact`, análise estática no parser real).

## 4) 📈 Melhorias recomendadas (priorizadas)

### P1 — curto prazo
1. **Tamanho do build: 261 MB só de arte.** 851 PNGs (810 em 512×512) + 9,2 MB de áudio (3 BGM WAV de 1,76 MB).
   Medição direta: reencodar os PNGs como **WebP q≈0,85** cai para ~26 MB (~10×) sem diferença visível em tela;
   no Godot isso é `Projeto → Configurações → Import Defaults → Texture → Compress/Mode = Lossy` (ou VRAM
   Compressed/ETC2 para os 500 frames de pet no mobile, que também corta a VRAM). Sem isso, Android/Web ficam
   pesados de baixar e instalar — hoje o `.aab`/PCK herdaria praticamente os 261 MB.
2. **Strings pt-BR hardcoded fora do `Loc`** (o sistema de localização é completo, mas ~20 pontos o ignoram):
   `RushTuning.proof_text()` (a chave `PROOF_SOCIAL_LIVE` **já existe nos 3 idiomas** e é ignorada),
   linha de rewarded e linhas de IAP da loja (`MetaPanel.gd` ~768/771/775–786), `DailySpin` (labels de
   recompensa), `Goals.gd:56` (prefixo kids), `Main.gd` ~266/271 (instruções), ~565 (prova social do review),
   ~571 ("💬 … acabou de avaliar"), 589/1015 ("ⓘ Ver história"), ~800 (upsell), 1128–1142 (tooltips do rush),
   `ParkFlow.gd` 308–310 (fallback de dica), `PetShopCanvas.gd:325` (breed default), `SalonPanels.gd:58`,
   `Contest.gd` 22–24 (nomes dos rivais), `GameState.gd` ~909 (toast de franquia), `ChapterStories`/`StaffStories`
   (só PT, enquanto `PetStories` tem EN). Um teste do tipo "sem literais pt em `_button/_pill`" ajuda a travar.
3. **Sinais emitidos sem consumidor (6):** `pet_arrived`, `review_received`, `upgrade_purchased`,
   `service_progress` (emite a cada evento de arrasto durante o serviço — o alvo natural seria a barra/HUD),
   `save_completed` e `settings_changed` (emitido 6×, inclusive por `AudioManager`). Nenhum tem `.connect(` em
   `.gd`/`.tscn`. Ou consumir (ex.: `settings_changed` para atualizar o áudio da loja, `save_completed` no
   indicador de save), ou remover — hoje é contrato sem dono.
4. **Código morto/engano:** `AdsManager._on_currency_changed` vazio; o ramo `.ogg` de `AudioManager._load_voice`
   cria o stream e dá `continue` (nunca carrega OGG) e o fallback `.wav` entrega bytes de RIFF para
   `AudioStreamWAV.data` (que espera PCM cru → sairia ruído) — os assets versionados são `.mp3`/`.wav` importados,
   então o caminho de bytes raramente roda, mas é uma armadilha. O bloco "zigzag simplificado" do QR foi removido
   nesta passada (era código morto que atrapalhava o diagnóstico).

### P2 — médio prazo
5. **Validação em aparelho real** (frame time, memória, aquecimento) segue como maior risco: a arte é procedural
   por frame e agora há 261 MB de texturas para carregar/mostrar; a CI headless não mede nada disso.
6. **Playtests humanos (5+)** do gesto: nenhum dado de diversão existe; nenhuma métrica substitui isso.
7. **Robustez do parser de localização (`Loc.gd`):** ele corta no primeiro `,` e só desquoteia quando o valor
   começa *e* termina com `"` — os CSVs atuais passam, mas qualquer edição futura com vírgula interna fora de
   aspas volta a truncar texto silenciosamente (o bug B5 da auditoria anterior). Trocar por parser CSV real ou
   travar em teste.
8. **Testes de runtime faltantes:** `SaveManager` (export/import code), `ParkService` (janelas de foto/petisco)
   e agora **share** (o QR já tem vetor; falta um teste de integração do cartão).

### P3 — produto/loja (bloqueadores externos)
9. Conta Play/Firebase/AdMob, SKUs, keystore fora do Git, package definitivo, política de privacidade revisada
   (ver `docs/READINESS_AUDIT.md`) — nada mudou desde 23/09.
10. **GitHub Pages nunca publicado:** o workflow `web-pages.yml` existe (dispatch manual ou tag `v*`), mas tem
    **0 execuções** e a API de Pages do repositório devolve 404 — habilitar Pages e disparar, depois validar o
    build servido (iframe, áudio com gesto, save em IndexedDB).
11. **Higiene de CI (novo):** o GitHub já avisa depreciação — `actions/checkout@v4`, `actions/cache@v4`,
    `actions/setup-python@v5` rodando em Node 24 force-upgrade, e o label `ubuntu-latest` migra para Ubuntu 26
    em 19/10/2026. Vale subir as actions e fixar a imagem antes que quebre sozinho.
12. **Docs:** corrigir as afirmações que esta auditoria provou falsas (QR "escaneável" no
    `AUDITORIA_NOTA10_RESULTADO.md`; a tabela do README/auditorias dizendo "0 sinais órfãos" quando existem 6
    emitidos sem listener). Documentação otimista é um risco de auditoria.

## 5) ⏳ Passos pendentes objetivos (checklist)

- [ ] **Rodar a CI desta branch** e confirmar os 2 jobs verdes (o job `runtime` executa os 3 testes novos:
      vetor do QR, `PRESTIGE_DONE` e `effect_text`).
- [ ] Decidir sobre a **compressão de arte** (P1-1): medir o `.aab`/PCK antes/depois, validar em aparelho médio.
- [ ] Mutirão de **i18n** (P1-2): remover os ~20 literais pt-BR; opcionalmente travar com teste.
- [ ] Limpar **sinais/código mortos** (P1-3/4).
- [ ] **GitHub Pages:** habilitar + disparar `web-pages.yml` + validar (herdado da auditoria anterior).
- [ ] **Aparelho real:** haptics, deep link `--section=`, notificações locais, frame time/memória (herdado).
- [ ] **Android:** validar export com `docs/export_presets.android.template.cfg` (target 36) (herdado).
- [ ] **Jurídico:** dono para revisar `PRIVACY_POLICY.md`/`TERMS_OF_SERVICE.md` (herdado).
- [ ] **Playtest** ≥5 pessoas antes de escalar conteúdo (herdado; segue sendo o gate de conteúdo).
- [ ] Subir actions/versões de CI antes de 19/10/2026 (novo).

## 6) Estado final desta branch

| Arquivo | Mudança |
|---|---|
| `core/ui/QRCodeArt.gd` | B6: tabelas GF(256), zigzag, módulos reservados e format info (4 correções) |
| `data/localization/{pt_BR,en_US,es_ES}.csv` | B7a: `PRESTIGE_DONE` com `%%` |
| `core/progression/Research.gd` | B7b: `effect_text` só formata quem tem placeholder |
| `autoload/GameState.gd` | B8: `currency_changed(&"embers")` nos 3 ganhos de brasas |
| `scenes/main/MetaPanel.gd` | B9: linha de rewarded desabilitada sem provider |
| `tests/DomainTests.gd` | regressão do QR (vetor de referência) + 2 checagens de localização |
| `tests/test_data_and_economy.py` | `LocalizationFormatTests`: placeholders × argumentos e `%` sem escape em todos os sites |

**Validação local:** `gdparse` ✅ · `gdlint` ✅ (59 arquivos) · `gd_static_check` ✅ · `validate_project` ✅
(0E/0W) · `unittest` ✅ 69/69 · QA de assets ✅ (500 PNGs, 63 SFX, 3 BGM, estantes).
**Validação de runtime:** delegada ao job `runtime` da CI (Godot 4.7.2 headless), que passa a cobrir o QR.

*Auditoria sem bump de `SAVE_VERSION` e sem mudança de formato de save: compatível com saves v14 existentes.*

---

# Execução dos passos pendentes (mesma data, PR #10)

Depois do relatório acima, os itens acionáveis foram **executados** nesta branch. A execução revelou mais 2 bugs
reais (B10 e B11) — ambos corrigidos e cobertos por teste.

## 8) Bugs novos revelados pela execução

### B10 — 🟠 Idioma salvo nunca era aplicado no boot
- **Onde:** `autoload/Loc.gd` + ordem dos autoloads do `project.godot`.
- **Causa:** o `Loc` lê `GameState.settings["language"]` no próprio `_ready`, mas o `SaveManager` (que carrega o
  save e faz `settings.merge(...)`) roda **depois**. Resultado: quem salvava EN/ES voltava a jogar em pt-BR até
  abrir Ajustes e trocar de idioma de novo — bug silencioso de retenção para público não-BR.
- **Fix:** `GameState.apply_dictionary` emite `settings_changed` depois de sanitizar os settings e o `Loc`
  sincroniza o idioma nesse gancho (validando contra `LANGS`, para não aceitar lixo de save editado).
- **Regressão:** `DomainTests::_test_regressoes_auditoria_v3` (load com `language=en_US` → `Loc.lang == "en_US"`).

### B11 — 🔴 QR: 5º defeito — o **desenho** não tinha zona de silêncio
- **Achado:** a matriz corrigida (B6) ainda não bastava. O teste de **decodificação da imagem final**
  (`QRCodeArt.generate_image`) mostrou que o desenho começava no pixel 0, **sem os 4 módulos de zona de
  silêncio** exigidos pelo padrão, e usava `pixel_size / size` sem considerar a margem. Com o OpenCV:
  `atual (220 px, sem margem) → não decodifica`; `com 4 módulos de margem → decodifica` (3 payloads, com a URL
  lida correta). Além disso o cartão encolhia 220 → 200 no `TextureRect` (fator 0,909 não inteiro): isso borra
  os módulos e é o pior caso para leitor de celular.
- **Fix:** `generate_image` desenha `(lado + 8) * célula` com margem de 4 módulos e célula inteira; os dois
  cartões do `ShareManager` passaram a dimensionar o quadro e o `TextureRect` a partir do lado real da imagem
  (1:1, sem reescalar).
- **Regressão:** `DomainTests::_test_regressoes_auditoria_v3` — 4 módulos de margem branca, célula ≥ 5 px,
  comparação **módulo a módulo** contra a matriz e verificação de que os dois cartões usam o lado real.

> Lição registrada: validar só a matriz não provava nada sobre o que o jogador vê. A regra desta auditoria é
> **decodificar a imagem final**, não o modelo intermediário.

## 9) Itens executados

| Item do checklist | Status | Evidência |
|---|---|---|
| Rodar a CI da branch | ✅ | 2 jobs verdes; artefato `web-build` (45,07 MB) em cada push |
| Compressão da arte (P1-1) | ✅ | `[importer_defaults]` Lossy WebP q=0,85 + sem mipmaps; `tools/compress_art.py` mede 248,8 MB → 30,2 MB (8,2×) |
| Mutirão de i18n (P1-2) | ✅ | 38 chaves novas ×3 idiomas (paridade 644/644) e ~25 literais pt-BR migrados (HUD, história, kids, roleta, loja, parque) |
| Sinais/código mortos (P1-3/4) | ✅ | 5 sinais sem consumidor removidos; `AdsManager._on_currency_changed` e o ramo OGG/WAV cru do `AudioManager` limpos; volumes reaplicados em `settings_changed` |
| Parser de localização (P2-7) | ✅ | `Loc.parse_csv` RFC 4180 com teste de vírgula entre aspas, aspas escapadas e `\n`; equivalência comprovada nas 644 chaves |
| Testes de runtime faltantes (P2-8) | ✅ | `SaveManager` (código de transferência, incl. adulteração) e `ParkService` (bola/petisco/foto, expiração, dicas) |
| GitHub Pages (P1/P3-10) | ⛔ **bloqueado** | Token do sandbox sem permissão de admin (HTTP 403 no dispatch e na API de Pages) — ver §10 |
| Validação em aparelho real (P2-5/6) | ⛔ humano | Frame time/memória/haptics, deep link e notificações exigem aparelho |
| Export Android (P3-9) | ⛔ humano | Precisa do SDK/keystore e da conta Play |
| Jurídico e playtest (P3) | ⛔ humano | Revisão de privacidade/termos e ≥5 playtests |
| Higiene de CI (P3-11) | ✅ | `checkout@v7`, `cache@v6`, `setup-python@v7`, `upload/deploy-pages@v5`, runner fixado em `ubuntu-24.04` — 0 annotations (antes: avisos de Node 20 e de migração para Ubuntu 26) |
| Docs otimistas (P3-12) | ✅ | correção no `AUDITORIA_NOTA10_RESULTADO.md` + este relatório |

### 9.1 O canal "jogue agora" agora é verificado a cada push
O workflow `web-pages.yml` existia mas nunca rodou e dependia de clique manual. O job `runtime` da CI passou a
**exportar o preset "Web Preview"** com os templates em cache, falhar se o `index.html` não sair, e publicar o
build como artefato baixável (`web-build`, 14 dias). Ou seja: o export deixou de ser uma promessa e virou fato
verificado — o que falta é apenas a publicação (que exige admin do repositório).

### 9.2 Travas novas contra regressão (todas rodando na CI)
- **QR:** vetor de referência 25×25 (matriz ISO/IEC 18004) **e** render (margem, célula inteira, módulo a módulo).
- **Localização:** placeholders × argumentos nos 102 sites `Loc.t("chave") % …` e `%` sem escape.
- **i18n:** scanner que falha se voltar texto pt-BR direto em chamada de UI.
- **Arquitetura:** scanner que falha se um sinal do `EventBus` ficar sem consumidor.
- **Entrega:** preset "Web Preview" amarrado ao workflow + runner fixado + defaults de importação de arte.

## 10) Pendências que dependem de você (com o passo exato)

1. **Publicar o GitHub Pages** (única pendência técnica restante do roadmap de entrega):
   `Settings → Pages → Source: GitHub Actions` e depois `Actions → "Web (jogue agora)" → Run workflow`
   (a tag `v*` também dispara). Enquanto isso não acontece, baixe o jogo já exportado em
   `Actions → CI → último run → Artifacts → web-build` (basta servir a pasta com um servidor estático).
2. **QA em aparelho real** (frame time, memória, haptics, deep link `--section=`, notificações locais).
3. **Playtest com ≥5 pessoas** — segue sendo o gate para escalar conteúdo.
4. **Android**: validar o export com `docs/export_presets.android.template.cfg` (SDK + keystore fora do Git).
5. **Jurídico**: revisar `PRIVACY_POLICY.md`/`TERMS_OF_SERVICE.md` e o texto de consentimento de analytics.

## 11) Estado final da branch

| Commit | Conteúdo |
|---|---|
| `9112171` | Auditoria v2: 4 defeitos do QR (matriz), `PRESTIGE_DONE`, `Research.effect_text`, brasas, rewarded, docs |
| `459f1fa` | Execução dos pendentes: idioma no boot, parser CSV, i18n (38 chaves ×3), sinais/código mortos, `[importer_defaults]`, `tools/compress_art.py`, actions v7/v6/v7/v5 + runner fixo |
| `194fe5c` | CI exporta o build Web e publica artefato a cada push |
| `5d643d9` | QR 5º defeito (render/zona de silêncio) + testes de save/park/render |
| `c8c12d0` | Annotations de falha nos testes de domínio |
| `ea3fe96` | Correção das expectativas do teste de transferência |

**Validação final:** `unittest` 74/74 ✅ · `gdlint` ✅ · `gd_static_check` ✅ · `validate_project` 0E/0W ✅ ·
QA de assets ✅ · **CI: 2 jobs verdes, 0 annotations** · artefato `web-build` de 45,07 MB gerado.
Sem bump de `SAVE_VERSION` (compatível com saves v14).
