class_name InteractionController
extends Control

@export var player_path: NodePath
@export var action_button_path: NodePath
@export var detail_label_path: NodePath

var _player: PlayerController
var _button: Button
var _detail: Label
var _current: InteractableMapNode


func _ready() -> void:
	_player = get_node(player_path)
	_button = get_node(action_button_path)
	_detail = get_node(detail_label_path)
	_button.pressed.connect(_on_pressed)
	_set_visible(false)


func _process(_delta: float) -> void:
	_current = _nearest_available()
	if _current == null:
		_set_visible(false)
		return
	_button.text = "TAP  •  %s" % _current.get_action_label()
	_detail.text = _current.get_detail_text()
	_set_visible(true)


func _nearest_available() -> InteractableMapNode:
	var nearest: InteractableMapNode
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("available_interactables"):
		var candidate := node as InteractableMapNode
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance := _player.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _on_pressed() -> void:
	if _current != null and is_instance_valid(_current):
		_current.interact()


func _set_visible(value: bool) -> void:
	_button.visible = value
	_detail.visible = value
