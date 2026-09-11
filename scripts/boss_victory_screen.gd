class_name BossVictoryScreen
extends Control

signal push_deeper_requested
signal extract_requested

# Shown when the boss dies. Pauses the game the same way GameOverScreen
# does (opts out of pause via process_mode = ALWAYS so the buttons still
# work) -- this is meant to be a real "stop and decide" moment, not
# something you have to react to instantly.
#
# Extract shows a complete run summary. Push Deeper hands control back to the
# RunDirector, which generates the next district at greater distance and heat.

@export var reward_label_path: NodePath

var _summary_mode := false
var _continue_button: Button
var _leave_button: Button
var _reward_label: Label
var _stats_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_continue_button = get_node("CenterContainer/VBoxContainer/ContinueButton")
	_leave_button = get_node("CenterContainer/VBoxContainer/LeaveButton")
	_reward_label = get_node(reward_label_path)
	_stats_label = get_node("CenterContainer/VBoxContainer/StatsLabel")
	_continue_button.pressed.connect(_on_continue_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)


func show_victory(reward: int) -> void:
	_summary_mode = false
	_reward_label.text = "+%d Gold secured at this checkpoint" % reward
	_stats_label.visible = false
	_continue_button.visible = true
	_continue_button.text = "PUSH DEEPER"
	_leave_button.text = "EXTRACT RUN"

	visible = true
	get_tree().paused = true


func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false
	push_deeper_requested.emit()


func _on_leave_pressed() -> void:
	if _summary_mode:
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	extract_requested.emit()


func show_extraction_summary(summary: String) -> void:
	_summary_mode = true
	var title := get_node("CenterContainer/VBoxContainer/TitleLabel") as Label
	title.text = "RUN EXTRACTED"
	_reward_label.text = "Your survivors made it out."
	_stats_label.text = summary
	_stats_label.visible = true
	_continue_button.visible = false
	_leave_button.text = "START NEW RUN"
	visible = true
	get_tree().paused = true
