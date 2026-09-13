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
var _player: PlayerController
var _research_label: Label
var _training_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_player = get_node(player_path) as PlayerController
	_player.health.died.connect(_on_player_died)
	var lost_label := get_node("CenterContainer/VBoxContainer/LostLabel") as Label
	lost_label.text = "%d carried gold will be lost" % _player.currency
	var content := get_node("CenterContainer/VBoxContainer") as VBoxContainer
	_research_label = Label.new()
	_research_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_research_label.add_theme_font_size_override("font_size", 19)
	_research_label.add_theme_color_override("font_color", Color(0.3, 0.92, 0.85))
	content.add_child(_research_label)
	_training_button = Button.new()
	_training_button.custom_minimum_size = Vector2(300.0, 50.0)
	_training_button.pressed.connect(_on_training_pressed)
	content.add_child(_training_button)

	var restart_button := get_node("CenterContainer/VBoxContainer/RestartButton") as Button
	restart_button.pressed.connect(_on_restart_pressed)
	content.move_child(restart_button, content.get_child_count() - 1)


func _on_player_died() -> void:
	var director := get_tree().current_scene.get_node_or_null("RunDirector") as RunDirector
	var district: int = director.district if director != null else 1
	var kills: int = director.zombies_defeated if director != null else 0
	var earned := RunProfile.research_earned(_player.currency, district, kills, false)
	RunProfile.record_defeat(_player.currency, district, kills)
	var lost_label := get_node("CenterContainer/VBoxContainer/LostLabel") as Label
	lost_label.text = "%d CARRIED GOLD LOST\n+%d RESEARCH EARNED" % [_player.currency, earned]
	_refresh_research()
	visible = true
	get_tree().paused = true


func _refresh_research() -> void:
	var profile := RunProfile.load_profile()
	var cost := RunProfile.training_cost(profile)
	_research_label.text = "RESEARCH: %d  •  STARTING HEALTH +%d" % [int(profile["research"]), int(profile["training_level"]) * 10]
	_training_button.text = "TRAINING +10 HEALTH  •  %d RESEARCH" % cost
	_training_button.disabled = int(profile["research"]) < cost


func _on_training_pressed() -> void:
	if RunProfile.purchase_training():
		_refresh_research()


func _on_restart_pressed() -> void:
	# Unpause BEFORE reloading -- SceneTree.paused isn't automatically
	# cleared by reload_current_scene(), so skipping this would reload
	# straight into a frozen game.
	get_tree().paused = false
	get_tree().reload_current_scene()
