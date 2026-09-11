class_name RestControl
extends Control

@export var rest_button_path: NodePath
@export var overlay_path: NodePath
@export var resume_button_path: NodePath

var _resting := false
var _rest_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rest_button = get_node(rest_button_path) as Button
	var resume_button := get_node(resume_button_path) as Button
	_rest_button.pressed.connect(_begin_rest)
	resume_button.pressed.connect(_end_rest)
	get_node(overlay_path).visible = false


func _process(_delta: float) -> void:
	# Other modal screens also pause the tree. Do not leave a dead REST button
	# floating over upgrade, victory, or game-over decisions.
	if not _resting:
		_rest_button.visible = not get_tree().paused


func _begin_rest() -> void:
	if get_tree().paused:
		return
	_resting = true
	_rest_button.visible = false
	get_node(overlay_path).visible = true
	get_tree().paused = true


func _end_rest() -> void:
	if not _resting:
		return
	_resting = false
	_rest_button.visible = true
	get_node(overlay_path).visible = false
	get_tree().paused = false
