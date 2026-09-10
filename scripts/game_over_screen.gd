class_name GameOverScreen
extends Control

# Listens for the player's death and pauses the entire scene tree --
# every default-mode node (zombies, spawners, abilities, HUD polling,
# all of it) automatically stops running the instant the tree pauses, so
# this one script fixes "everything keeps running after death" without
# needing to individually touch every other system.
#
# This node explicitly opts OUT of the pause (process_mode = ALWAYS) so
# it keeps rendering and can still receive the Restart button press
# while everything else is frozen.

@export var player_path: NodePath


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var player := get_node(player_path) as PlayerController
	player.health.died.connect(_on_player_died)

	var restart_button := get_node("CenterContainer/VBoxContainer/RestartButton") as Button
	restart_button.pressed.connect(_on_restart_pressed)


func _on_player_died() -> void:
	visible = true
	get_tree().paused = true


func _on_restart_pressed() -> void:
	# Unpause BEFORE reloading -- SceneTree.paused isn't automatically
	# cleared by reload_current_scene(), so skipping this would reload
	# straight into a frozen game.
	get_tree().paused = false
	get_tree().reload_current_scene()
