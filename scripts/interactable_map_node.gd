class_name InteractableMapNode
extends MapNode

## Proximity only makes an interaction available. The player must explicitly
## tap the shared context button before anything is consumed or changed.

@export var action_label := "INTERACT"
@export var detail_text := ""

var player_in_range: PlayerController
var _consumed := false


func _on_player_entered(player: PlayerController) -> void:
	player_in_range = player
	add_to_group("available_interactables")


func _on_player_exited(_player: PlayerController) -> void:
	player_in_range = null
	remove_from_group("available_interactables")


func interact() -> void:
	if _consumed or player_in_range == null:
		return
	_perform_interaction(player_in_range)


func consume() -> void:
	_consumed = true
	remove_from_group("available_interactables")


func get_action_label() -> String:
	return action_label


func get_detail_text() -> String:
	return detail_text


func _perform_interaction(_player: PlayerController) -> void:
	pass
