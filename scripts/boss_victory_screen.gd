class_name BossVictoryScreen
extends Control

# Shown when the boss dies. Pauses the game the same way GameOverScreen
# does (opts out of pause via process_mode = ALWAYS so the buttons still
# work) -- this is meant to be a real "stop and decide" moment, not
# something you have to react to instantly.
#
# Leave: reload the scene fresh, same as a restart -- banks the run as a
# clean win. Continue: just unpauses and lets play resume. NOTE: Continue
# does not yet re-scope node spacing deeper (shops/survivors/next altar
# further out) -- that's the natural next step, not built in this pass.

@export var reward_label_path: NodePath


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var continue_button := get_node("CenterContainer/VBoxContainer/ContinueButton") as Button
	var leave_button := get_node("CenterContainer/VBoxContainer/LeaveButton") as Button

	continue_button.pressed.connect(_on_continue_pressed)
	leave_button.pressed.connect(_on_leave_pressed)


func show_victory(reward: int) -> void:
	if reward_label_path != NodePath(""):
		var reward_label := get_node(reward_label_path) as Label
		reward_label.text = "+%d Gold" % reward

	visible = true
	get_tree().paused = true


func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false


func _on_leave_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
