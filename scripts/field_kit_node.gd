class_name FieldKitNode
extends InteractableMapNode

signal opened


func _ready() -> void:
	action_label = "OPEN FIELD KIT"
	detail_text = "Recovered from the outbreak carrier"
	super._ready()


func _perform_interaction(_player: PlayerController) -> void:
	consume()
	opened.emit()
	queue_free()
