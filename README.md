# PetShop Tycoon: Do Banho à Rede

Early vertical slice em **Godot 4.x**, portrait e offline-first. Atenda pets em banho ou tosa, controle o gesto na faixa Perfect, receba reviews/moedas, faça upgrades, complete missões, amplie coleção e desbloqueie produção idle. Toda arte e SFX atuais são procedurais e sem dependência externa.

## Rodar
1. Instale Godot 4.3+ com renderer Compatibility.
2. Importe `project.godot` e execute F6/F5; a cena inicial é `scenes/main/Main.tscn`.
3. Mouse: segure e esfregue sobre o pet. Touch: arraste sobre o pet.
4. Use MISSÕES, COLEÇÃO, MAPA e AJUSTES no rodapé; tosa surge no ciclo de clientes.
5. Save fica em `user://save.dat`, com três backups e migração v1→v2.

CLI quando Godot estiver disponível:
```bash
godot --path . --editor
# valida import/parse
godot --headless --path . --editor --quit
# simulador
python3 tools/economy_sim.py --csv docs/balance_initial.csv
```

## Android
Instale export templates e Android SDK/JDK suportados pela sua versão Godot. Em `export_presets.cfg`, substitua `com.seunome.petshoptycoon` **somente após definir publisher/package definitivo**. Configure keystore fora do Git e use Play App Signing. Exporte AAB pelo editor. Target 36 está configurado, mas confirme exigência vigente da loja.

Ads, Billing e Firebase exigem contas/configuração do publisher e aparelho; veja `docs/SDK_INTEGRATIONS.md`. Nunca coloque keystore, senha ou IDs de produção hardcoded. O preset é estrutura, não alegação de AAB assinado.

## Estrutura
- `autoload/`: estado, economia, save, analytics, áudio, config, tempo, haptics.
- `core/`: domínio testável e policies.
- `scenes/`: apresentação executável.
- `data/`: catálogos JSON/localização.
- `docs/`: produto, técnica, arte, UX, dados e release.
- `tools/`: simulador de economia sem dependências.

## Status
Milestone **early vertical slice implementada; validação runtime/device e playtest pendentes**. A lista integral de prontidão está em `docs/READINESS_AUDIT.md`. Não escalar conteúdo antes do gate humano descrito em `docs/ROADMAP.md`.
