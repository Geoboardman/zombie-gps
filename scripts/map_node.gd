class_name MapNode
extends Area3D

# Base for anything the player walks up to and interacts with just by
# proximity (shops) or by proximity + an explicit action (boss altars).
# Subclasses override _on_player_entered / _on_player_exited.

func _ready() -> void:
	add_to_group("map_pois") # lets CompassHUD find every node without caring what kind it is
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var player := body as PlayerController
	if player != null:
		_on_player_entered(player)


func _on_body_exited(body: Node3D) -> void:
	var player := body as PlayerController
	if player != null:
		_on_player_exited(player)


func _on_player_entered(_player: PlayerController) -> void:
	pass # override in subclasses


func _on_player_exited(_player: PlayerController) -> void:
	pass # override in subclasses
