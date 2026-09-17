# Arquitetura de Cenas

## Atual
`Main.tscn` é uma raiz Control responsiva. `Main.gd` compõe HUD; `PetShopCanvas.gd` desenha mundo/pet; `BathService.gd` contém regra. A separação permite trocar arte procedural por Sprite2D/AnimationTree sem tocar economia/save.

## Vertical Slice
```text
Bootstrap.tscn
├─ SafeArea
│  └─ MainShell
│     ├─ SceneRouter
│     │  ├─ HomeWorld.tscn
│     │  └─ PetShop.tscn
│     │     ├─ Environment
│     │     ├─ CustomerQueue
│     │     ├─ Stations
│     │     │  ├─ BathStation.tscn
│     │     │  └─ GroomStation.tscn
│     │     ├─ StaffLayer
│     │     ├─ VFXPool
│     │     └─ GameplayHUD
│     ├─ ModalLayer
│     ├─ ToastLayer
│     └─ TransitionLayer
└─ DebugOverlay (debug only)
```

Cada estação expõe `can_accept`, `assign_order`, `cancel`, `serialize_runtime`; pedidos e pets são modelos, Nodes são apresentação pooled. HUD não referencia filhos de estação por path; reage a EventBus. Modal stack captura Back. Cinematics possuem skip e reduced motion.

## Streaming
Home e estabelecimento ativo residentes; coleção/mapa carregados threaded; atlas por cidade liberado após transição. Catálogo JSON validado antes de scene entry. Falha de asset/config retorna last-known-good, nunca tela vazia.
