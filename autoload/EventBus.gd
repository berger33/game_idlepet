extends Node
## Barramento tipado: sistemas não dependem de cenas concretas.
## Os sinais são API cross-class: emitidos e conectados por outros scripts
## (Gameplay/Main/autoloads), por isso o aviso unused_signal — que só enxerga
## a própria classe — é suprimido na região de declaração abaixo.

@warning_ignore_start("unused_signal")
## Higiene (auditoria v2): sinais sem NENHUM consumidor foram removidos —
## emitidos em vão eram contrato sem dono. Se um consumidor aparecer, o sinal
## volta aqui; tests/test_data_and_economy.py falha se ficar órfão de novo.
signal currency_changed(currency: StringName, amount: float)
signal service_started(service_id: StringName)
signal service_completed(service_id: StringName, quality: StringName, reward: float)
signal service_failed(service_id: StringName, reason: StringName)
signal combo_changed(value: int)
signal toast_requested(message: String, color: Color)
## Momento de revelação (cartão modal, ver RevealCard): "pet" | "chapter" |
## "achievement" | "service" | "cosmetic"; payload depende do tipo.
signal reveal_requested(kind: StringName, payload: Dictionary)
signal settings_changed
@warning_ignore_restore("unused_signal")
