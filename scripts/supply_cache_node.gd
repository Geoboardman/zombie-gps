class_name SupplyCacheNode
extends MapNode

signal collected

@export var gold_reward := 35
@export var heal_amount := 20

var _consumed := false


func _ready() -> void:
	super._ready()


func _on_player_entered(player: PlayerController) -> void:
	if _consumed:
		return
	_consumed = true
	player.add_currency(gold_reward)
	player.health.heal(heal_amount)
	collected.emit()
	queue_free()
