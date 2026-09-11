class_name SupplyCacheNode
extends InteractableMapNode

signal collected

@export var gold_reward := 35
@export var heal_amount := 20

func _ready() -> void:
	action_label = "SEARCH CACHE"
	detail_text = "+%d gold and medical supplies" % gold_reward
	super._ready()


func _perform_interaction(player: PlayerController) -> void:
	consume()
	player.add_currency(gold_reward)
	player.health.heal(heal_amount)
	collected.emit()
	queue_free()
