# Álbum & Concurso Semanal — Capa da Revista Pets (2026-09-22)

> **Ideia 2 entregue:** toda foto 📸 perfeita no Parquinho vira memória colecionável; no sábado o bairro elege a **Capa da Revista**. Sem servidor, sem gacha, só share local — fecha o loop D7/D30 do Parquinho.

## Loop
1. **Foto perfeita → álbum:** `GameState.park_complete("photo", true, true)` chama `park_add_photo({pets, date, ts, coins})`. Máx 50 fotos ( LIFO, save enxuto). Qualquer perfect de `photo` entra; `ball/treat` perfect dá afeto mas não entra no álbum (mantém foto como skill).
2. **Álbum (`MetaPanel > Álbum`):**
   - Nav `📖 Álbum` (ícone reuse `collection.png`) libera no nível 2 (mesmo do Parquinho). Badge `★` pulsante quando `park_can_claim_contest()` = true.
   - Cabeçalho: `🏆 Troféus: N` + descrição curta.
   - Linha `SEMANA ATUAL`: `Fotos esta semana: total (perfeitas perfects)` + botão `COLETAR CAPA` (verde quando sábado + ≥1 perfect na semana e ainda não coletado) → `park_claim_contest()` → `+R$ 200 (Rewards.for_kind weekly_chest)` + `+3 brasas` + `+1 troféu` + achievement `park_contest_win`.
   - Hint dinâmica: fora de sábado → “Concurso abre no sábado — continue fotografando!”; sábado sem perfect → “Faça 1 foto 📸 perfeita hoje!”.
   - Grid 3 colunas, 18 mais recentes primeiro: card `240×90` thumb (primeiro pet), nomes, data, `⭐ PERFEITA` rosa, botão `COMPARTILHAR` copia legenda `Minha capa em 2026-09-22 com Caramelo, Bento, Mel! #PetShopTycoon` + toast `SHARE_SAVED_GALLERY`.
   - Footer dica: “1 perfect já vale troféu”.
3. **Acesso rápido:** no Parquinho, painel de escolha tem `📖 Ver Álbum (N)` → fecha parquinho e abre `meta.open(&"album")`.
4. **Share:** Reusa `DisplayServer.clipboard_set` + toast existente (não exige `ShareManager` novas permissões).

## Persistência (`autoload/GameState.gd`, SAVE_VERSION 12)
```gdscript
park_photos: Array[Dictionary] = []  # {pets: Array[String], date: String, perfect: bool, activity: String, ts: int, coins: int}
park_contest_claimed_week: String = ""  # _week_key da última entrega
park_trophies: int = 0
```
- `to_dictionary()` serializa os 3; `apply_dictionary()` chama `_safe_photos_array` (valida `pets` contra catálogo, ts>0, limita 50, ignora entradas corrompidas).
- `_week_key()` = segunda-feira unix (mesma das missões semanais). `park_is_saturday()` = `weekday == 6` (Godot `Time.get_datetime_dict_from_system().weekday`).
- `park_photos_this_week()` filtra por `p_week == _week_key()`.
- `park_can_claim_contest()` = `claimed_week != week` && `is_saturday` && `perfects_this_week ≥1`.
- `park_claim_contest()` grava `claimed_week`, `park_trophies +=1`, dá coins/embers, `Analytics.track("park_contest_claimed")`.

## UI Detalhe (`scenes/main/MetaPanel.gd`)
- `_rebuild` match adiciona `&"album"` → `_build_album()`.
- `_build_album()` usa `_info_row` para cabeçalhos e `GridContainer` 3 colunas para fotos. `StyleFactory.box` rosa para perfect, cinza para boa. Botão disabled cinza quando não é sábado.
- `Main.gd`:
  - `NAV_ICONS["album"]` reuse `collection.png`; `nav_unlocks["album"]=2`; nav building guarda `album_button`.
  - `_process` → `D1Retention`-style badge pulsante `★` no `album_button` quando `park_can_claim_contest()`.
  - `_setup_park` → `album_btn` dentro do painel de escolha do Parquinho.

## Localização (528→544 chaves, paridade pt/en/es)
`NAV_ALBUM`, `ALBUM_TITLE`, `ALBUM_TROPHIES`, `ALBUM_CONTEST_DESC`, `ALBUM_WEEK`, `ALBUM_WEEK_PROGRESS`, `ALBUM_CLAIM/CLAIMED/CLAIM_TOAST`, `ALBUM_SATURDAY_HINT/NEED`, `ALBUM_EMPTY`, `ALBUM_GRID_TITLE`, `ALBUM_SHARE/SHARE_CAPTION`, `ALBUM_FOOTER`.

## Balance & LiveOps
- **Sem inflação:** troféu é cosmético simbólico (`park_trophies` contador) + `R$ 200 + 3 brasas` 1×/semana max. Não compete com banho (`R$ 52` base) nem com `weekly_chest` (`R$ 200+3` também 1×/semana) — dobra o motivo para logar no sábado.
- **Sem build:** ajustar `park_cooldown_seconds` (2h) para sábado curto via `RemoteConfig` aumenta fotos disponíveis para o concurso.
- **Métrica:** sessões sábado, `park_photos_this_week.perfects`, `park_trophies`, share clipboard.

## Teste manual
1. No Parquinho escolha 📸, espere barra verde ≥72% e toque FOTO até `⭐ Perfeito!` → toast + `R$`. Repita até 2 fotos.
2. Abra `Álbum` (nav 📖 ou botão no Parquinho) → grid mostra fotos, `Fotos esta semana: 2 (perfeitas 2)`, `COLETAR CAPA` cinza se não é sábado.
3. Force sábado: `OS.set_time` não existe; para teste, edite `GameState.park_is_saturday()` retornar `true` ou mude data do sistema para sábado → badge `★` no nav + botão verde → `COLETAR CAPA` → `+200 R$ +3 brasas` + `Troféus: 1` + achievement.
4. `python3 tools/validate_project.py` → `0E/0W`, `wc -l data/localization/*.csv` → `544` cada.
