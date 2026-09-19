# Compatibilidade Godot 4.7.2

## Erros reproduzidos pelo usuário

1. `PetShopCanvas.draw_ellipse()` colidia com um método nativo novo de `CanvasItem` no Godot 4.7.2. Como warnings são tratados como erro, a dependência de `Main.gd` não compilava.
2. O preset Web não declarava `include_filter` e `exclude_filter`, chaves exigidas pela leitura de presets nessa versão.
3. O preset Android ativo fazia o editor procurar `build-tools` mesmo em uma máquina configurada apenas para testar no Windows.
4. `ContentDB.gd` declarava `var staff` (catálogo, linha 15) e `func staff(id)` (lookup, linha 76): `Function "staff" has the same name as a previously declared variable` — erro de parse que impede a inicialização. O Godot 4.3 (usado pelo CI até então) tolerava a colisão, por isso o CI não reportava.
5. `AudioManager.gd` declarava `func _energy_loop()` duas vezes (definição duplicada idêntica, linhas 163/187) — mesma classe de erro de parse na versão 4.7.2.

## Correções

- Helper renomeado de `draw_ellipse` para `_draw_pet_ellipse`; todas as chamadas foram migradas.
- Preset Web consolidado como único preset ativo, com chaves completas.
- Preset Android movido para `docs/export_presets.android.template.cfg`; ele só deve ser ativado depois de instalar/configurar Android SDK e JDK.
- Teste de regressão verifica nome do helper, filtros obrigatórios e ausência de Android no preset ativo.
- Variável de catálogo renomeada de `staff` para `staff_members` (ContentDB ×3, MetaPanel ×1); o acessor `func staff(id)` foi mantido, consistente com `pet(id)`/`cosmetic(id)`/`pass_day()`.
- Duplicata de `_energy_loop` removida (cópias byte a byte idênticas; a segunda era código morto que virou erro de parse).
- Novo teste `test_no_gdscript_name_collisions` varre **todos** os `.gd` do projeto por declarações duplicadas de nome (var/const/signal/enum/func/static func) — guarda permanente para a classe inteira de erro, independente da versão do Godot do CI.
- O job de runtime do CI foi migrado de Godot 4.3 para **4.7.2**, a versão alvo do projeto: `--headless --import` + smoke test agora validam o parse na mesma versão que o usuário executa.

## Validação esperada no Windows

Feche e abra o projeto novamente. O editor deve reimportar os scripts. Pressione F6. Para limpar diagnóstico antigo, use **Project → Reload Current Project** ou feche o Godot e remova somente a pasta `.godot` dentro do projeto; ela é cache e será recriada.

O erro `Unable to open Android 'build-tools' directory` só é relevante para export Android. Com o preset ativo corrigido, ele não deve ser provocado pelo projeto. Se continuar aparecendo, há um caminho Android inválido salvo globalmente no editor: abra **Editor Settings → Export → Android** e limpe/corrija os caminhos. Isso não impede executar o jogo no Windows.
