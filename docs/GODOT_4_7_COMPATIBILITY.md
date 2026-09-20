# Compatibilidade Godot 4.7.2

## Erros reproduzidos pelo usuário

1. `PetShopCanvas.draw_ellipse()` colidia com um método nativo novo de `CanvasItem` no Godot 4.7.2. Como warnings são tratados como erro, a dependência de `Main.gd` não compilava.
2. O preset Web não declarava `include_filter` e `exclude_filter`, chaves exigidas pela leitura de presets nessa versão.
3. O preset Android ativo fazia o editor procurar `build-tools` mesmo em uma máquina configurada apenas para testar no Windows.
4. `ContentDB.gd` declarava `var staff` (catálogo, linha 15) e `func staff(id)` (lookup, linha 76): `Function "staff" has the same name as a previously declared variable` — erro de parse que impede a inicialização. O Godot 4.3 (usado pelo CI até então) tolerava a colisão, por isso o CI não reportava.
5. `AudioManager.gd` declarava `func _energy_loop()` duas vezes (definição duplicada idêntica, linhas 163/187) — mesma classe de erro de parse na versão 4.7.2.
6. `PetCosmeticsArt.gd` chamava as primitivas de desenho (`draw_colored_polygon`, `draw_line`, `draw_circle`, `draw_arc`) sem o prefixo `shop.` dentro de funções `static` de uma classe `RefCounted` — `Function "..." not found in base self` (16 ocorrências). O arquivo também chamava `_bath_foam_color()` (que só existe no PetShopCanvas) e `draw_styleshop._box(...)`, identificador inexistente.
7. `Main.gd` chamava `_show_comeback()` no `_ready` e conectava `_on_share_pressed` no botão de compartilhar sem declarar nenhum dos dois métodos — chamadas órfãs de um squash de históricos paralelos (commit 4676406).
8. `Main.gd` conectava os botões de navegação a `meta.open.bind(...)` dentro de `_build_interface()` antes do `MetaPanel` ser instanciado (linhas 847 vs 877): `Invalid access to property or key 'open' on a base object of type 'Nil'` — a construção da interface abortava no meio (painéis restantes não criados) sem alterar o exit code, por isso o smoke test não reportava.
9. Warnings de análise no editor 4.7.2: shadowing de `rotation` (propriedade de Control) e `ready` (signal de Node) por variáveis locais; parâmetro `wrap` com nome de built-in; locais sombreando funções da própria classe (`beat_phase`, iterator `pet`); divisão inteira implícita (`GameState`, `SaveManager`); `unused_signal` em todos os sinais do `EventBus`.

## Correções

- Helper renomeado de `draw_ellipse` para `_draw_pet_ellipse`; todas as chamadas foram migradas.
- Preset Web consolidado como único preset ativo, com chaves completas.
- Preset Android movido para `docs/export_presets.android.template.cfg`; ele só deve ser ativado depois de instalar/configurar Android SDK e JDK.
- Teste de regressão verifica nome do helper, filtros obrigatórios e ausência de Android no preset ativo.
- Variável de catálogo renomeada de `staff` para `staff_members` (ContentDB: declaração + atribuição + iteração; MetaPanel ×1); o acessor `func staff(id)` foi mantido, consistente com `pet(id)`/`cosmetic(id)`/`pass_day()`. Nota de processo: o primeiro rename ficou PELA METADE (a atribuição/iteração no `_ready` continuaram `staff`), o que fazia `staff` resolver para o método — `Cannot assign a new value to a constant` e `Unable to iterate on value of type Callable` — e deixava o catálogo de funcionários vazio em runtime sem quebrar o exit code do smoke test. Detectado pelo novo harness de análise do CI e corrigido; teste de regressão agora exige o rename completo.
- Duplicata de `_energy_loop` removida (cópias byte a byte idênticas; a segunda era código morto que virou erro de parse).
- `PetCosmeticsArt.gd`: todas as primitivas de desenho agora usam `shop.` (o canvas recebido por parâmetro, como já fazia com `shake_phase`/`_box`); `_bath_foam_color()` corrigido para `bath_foam_color(shop)` (a static da própria classe); `draw_styleshop._box(...)` corrigido para `shop.draw_style_box(shop._box(...))`, o mesmo padrão que o canvas usa para painéis.
- `Main.gd` recebeu os dois hooks ausentes em `core/ui/SessionFeedback.gd` (novo helper `static` no padrão PetCosmeticsArt/style_factory, mantendo o Main sob o limite de 1000 linhas do gdlint), reconstruídos a partir dos sistemas que já existiam: `show_comeback(main)` chama `GameState.check_return_bonus()` (bônus de retorno ≥ 48h, antes sem nenhum caller) e mostra toast + chime `comeback` + haptics; `on_share_pressed(main)` toca o chime `share_saved`, aplica haptics e mostra o caminho do PNG salvo pelo ShareManager (contrato documentado da classe: no desktop o toast diz que o arquivo ficou salvo, sem prometer rede social). O Main chama `SessionFeedback.show_comeback(self)` no `_ready` e conecta `SessionFeedback.on_share_pressed.bind(self)` ao botão de compartilhar.
- Novo teste `test_no_gdscript_name_collisions` varre **todos** os `.gd` do projeto por declarações duplicadas de nome (var/const/signal/enum/func/static func) — guarda permanente para a classe inteira de erro, independente da versão do Godot do CI.
- Novo teste `test_no_orphan_private_method_references` varre todos os `.gd` por chamadas/handlers `_privados` sem declaração no arquivo (a classe do `_show_comeback`/`_on_share_pressed`).
- O job de runtime do CI foi migrado de Godot 4.3 para **4.7.2**, a versão alvo do projeto: `--headless --import` + smoke test agora validam o parse na mesma versão que o usuário executa.
- `Main.gd`: navegação mediada por `SessionFeedback.open_meta(main, section, origin)` — o acesso ao painel acontece no clique, quando o `MetaPanel` já existe; teste de regressão proíbe `meta.open.bind` no Main.
- Warnings do item 9: locais renomeadas (`rotation`→`spin` ×2 no PetShopCanvas, `ready`→`mission_ready` no GameState, `beat_phase`→`beat_frac` no AudioManager, iterator `pet`→`pet_entry` no ContentDB, parâmetro `wrap`→`wrap_text` no MetaPanel); divisões inteiras explícitas via `floori(...)` (GameState `gap_hours`, migração v2→v3 do SaveManager — semântica de truncamento preservada); `@warning_ignore(unused_signal)` sinal a sinal no `EventBus` (todos os 11 têm consumo cross-class real, de 1 a 21 usos).
- O smoke test do CI agora **falha se a saída contiver `SCRIPT ERROR`** — erros de script em runtime não alteram o exit code do Godot; sem isso a cena podia quebrar no meio do `_ready` e o passo "passava".
- O CI também executa `tools/check_scripts.gd` (análise em **contexto de projeto completo**, com autoloads registrados — igual ao editor) sobre **todos** os scripts no 4.7.2 — o import/smoke sozinhos não falham com erro de script — com autoteste que garante que o detector enxerga colisões de nome. (O `--check-only` por script isolado foi avaliado e descartado: não resolve identificadores de autoload fora do contexto do projeto.)

## Validação esperada no Windows

Feche e abra o projeto novamente. O editor deve reimportar os scripts. Pressione F6. Para limpar diagnóstico antigo, use **Project → Reload Current Project** ou feche o Godot e remova somente a pasta `.godot` dentro do projeto; ela é cache e será recriada.

O erro `Unable to open Android 'build-tools' directory` só é relevante para export Android. Com o preset ativo corrigido, ele não deve ser provocado pelo projeto. Se continuar aparecendo, há um caminho Android inválido salvo globalmente no editor: abra **Editor Settings → Export → Android** e limpe/corrija os caminhos. Isso não impede executar o jogo no Windows.
