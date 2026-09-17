# PetShop Tycoon: Do Banho à Rede

Vertical slice em **Godot 4.x**, portrait e offline-first. Atenda cães e gatos em banho ou tosa, controle o gesto na faixa Perfect, faça carinho, construa afeto, receba reviews/XP/moedas, complete missões e evolua por uma carreira modelada em 61,85 horas ativas. O slice possui 30 pets, 120 níveis, feedback universal de clique, cenários ilustrados próprios, pets/VFX vetoriais e áudio procedural.

## Rodar
1. Instale Godot 4.3+ com renderer Compatibility.
2. Importe `project.godot` e execute F6/F5; a cena inicial é `scenes/main/Main.tscn`.
3. Clique no botão rosa **1. SERVIR CARAMELO**; depois segure e esfregue sobre o pet até a barra entrar na faixa verde.
4. Finalize o serviço, receba moedas/XP e use **PRÓXIMO CLIENTE**. Missões, Coleção, Mapa e Ajustes ficam no bottom sheet.
5. Save fica em `user://save.dat`, com três backups e migração sequencial até v5.

No Godot 4.7, se o player embutido estiver muito baixo, use os três pontos acima da prévia, desative **Embed Game/Incorporar jogo** e execute novamente em janela separada. O CTA principal também foi elevado para continuar visível no modo embutido.

CLI quando Godot estiver disponível:
```bash
godot --path . --editor
# valida import/parse
godot --headless --path . --editor --quit
# validação estrutural e dados
python3 tools/validate_project.py
# testes de domínio no próprio Godot
godot --headless --path . --script tests/run_godot_tests.gd
# simuladores
python3 tools/economy_sim.py --csv docs/balance_initial.csv
python3 tools/career_sim.py
```

## Android
O preset Android ativo foi removido para que o projeto abra sem erros em computadores que ainda não possuem Android SDK. O template está preservado em `docs/export_presets.android.template.cfg`.

Quando for exportar: instale os export templates e o Android SDK/JDK suportado pelo seu Godot, configure **Editor Settings → Export → Android**, copie o template para `export_presets.cfg` e substitua `com.seunome.petshoptycoon` somente após definir o package definitivo. Configure a keystore fora do Git e use Play App Signing. O template usa target 36; confirme a exigência vigente da loja.

Ads, Billing e Firebase exigem contas/configuração do publisher e aparelho; veja `docs/SDK_INTEGRATIONS.md`. Nunca coloque keystore, senha ou IDs de produção hardcoded.

## Estrutura
- `autoload/`: estado, economia, save, analytics, áudio, config, tempo, haptics.
- `core/`: domínio testável e policies.
- `scenes/`: apresentação executável.
- `data/`: catálogos JSON/localização.
- `docs/`: produto, técnica, arte, UX, dados e release.
- `tools/`: simulador de economia sem dependências.

## Status
Milestone **early vertical slice implementada; validação runtime/device e playtest pendentes**. A lista integral de prontidão está em `docs/READINESS_AUDIT.md`. Não escalar conteúdo antes do gate humano descrito em `docs/ROADMAP.md`.
