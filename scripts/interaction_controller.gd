class_name InteractionController
extends Control

## Creates one screen-space prompt for every nearby interactable. Each prompt
## follows its world object so outdoor GPS drift never forces the player to
## make one object become the single "nearest" selection.

@export var player_path: NodePath
@export var action_button_path: NodePath
@export var detail_label_path: NodePath

const BUTTON_SIZE := Vector2(178.0, 42.0)
const DETAIL_SIZE := Vector2(190.0, 26.0)
const WORLD_OFFSET := Vector3(0.0, 0.65, 0.0)
const DETAIL_GAP := 5.0
const SCREEN_GAP := 10.0

var _player: PlayerController
var _button_template: Button
var _detail_template: Label
var _entries: Dictionary = {}


func _ready() -> void:
	_player = get_node(player_path) as PlayerController
	_button_template = get_node(action_button_path) as Button
	_detail_template = get_node(detail_label_path) as Label
	_button_template.visible = false
	_detail_template.visible = false


func _process(_delta: float) -> void:
	var available := _available_candidates()
	_remove_stale_entries(available)
	for candidate: InteractableMapNode in available:
		_ensure_entry(candidate)
	_layout_entries(available)


func _available_candidates() -> Array[InteractableMapNode]:
	var result: Array[InteractableMapNode] = []
	for node: Node in get_tree().get_nodes_in_group("available_interactables"):
		var candidate := node as InteractableMapNode
		if candidate != null and is_instance_valid(candidate):
			result.append(candidate)
	return result


func _ensure_entry(candidate: InteractableMapNode) -> void:
	if _entries.has(candidate):
		return
	var button := _button_template.duplicate() as Button
	var detail := _detail_template.duplicate() as Label
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	detail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.size = BUTTON_SIZE
	detail.size = DETAIL_SIZE
	button.visible = true
	detail.visible = true
	button.pressed.connect(_on_candidate_pressed.bind(candidate))
	add_child(detail)
	add_child(button)
	_entries[candidate] = {"button": button, "detail": detail}
	_set_world_labels_visible(candidate, false)


func _remove_stale_entries(available: Array[InteractableMapNode]) -> void:
	for candidate: Variant in _entries.keys():
		if is_instance_valid(candidate) and available.has(candidate as InteractableMapNode):
			continue
		var entry: Dictionary = _entries[candidate]
		if is_instance_valid(candidate):
			_set_world_labels_visible(candidate as InteractableMapNode, true)
		(entry["button"] as Button).queue_free()
		(entry["detail"] as Label).queue_free()
		_entries.erase(candidate)


func _layout_entries(available: Array[InteractableMapNode]) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var viewport_size := get_viewport_rect().size
	var occupied: Array[Rect2] = []
	for candidate: InteractableMapNode in available:
		var entry: Dictionary = _entries[candidate]
		var button := entry["button"] as Button
		var detail := entry["detail"] as Label
		if camera.is_position_behind(candidate.global_position):
			button.visible = false
			detail.visible = false
			continue
		var projected := camera.unproject_position(candidate.global_position + WORLD_OFFSET)
		var prompt_center := projected + Vector2(0.0, 48.0)
		var button_position := Vector2(
			clampf(prompt_center.x - BUTTON_SIZE.x * 0.5, 12.0, viewport_size.x - BUTTON_SIZE.x - 12.0),
			clampf(prompt_center.y, 218.0, viewport_size.y - BUTTON_SIZE.y - 140.0)
		)
		var cluster_rect := Rect2(
			Vector2(button_position.x - (DETAIL_SIZE.x - BUTTON_SIZE.x) * 0.5, button_position.y - DETAIL_SIZE.y - DETAIL_GAP),
			Vector2(DETAIL_SIZE.x, DETAIL_SIZE.y + DETAIL_GAP + BUTTON_SIZE.y)
		)
		while _intersects_any(cluster_rect, occupied):
			cluster_rect.position.y += cluster_rect.size.y + SCREEN_GAP
			if cluster_rect.end.y > viewport_size.y - 132.0:
				cluster_rect.position.y = maxf(180.0, cluster_rect.position.y - (cluster_rect.size.y + SCREEN_GAP) * 2.0)
				cluster_rect.position.x = clampf(cluster_rect.position.x + DETAIL_SIZE.x * 0.55, 8.0, viewport_size.x - DETAIL_SIZE.x - 8.0)
				break
		occupied.append(cluster_rect)
		button.text = "TAP  •  %s" % candidate.get_action_label()
		detail.text = candidate.get_detail_text()
		button.position = Vector2(cluster_rect.get_center().x - BUTTON_SIZE.x * 0.5, cluster_rect.end.y - BUTTON_SIZE.y)
		detail.position = cluster_rect.position
		button.visible = true
		detail.visible = not detail.text.is_empty()


func _intersects_any(rect: Rect2, occupied: Array[Rect2]) -> bool:
	for other: Rect2 in occupied:
		if rect.intersects(other.grow(6.0)):
			return true
	return false


func _on_candidate_pressed(candidate: InteractableMapNode) -> void:
	if candidate != null and is_instance_valid(candidate):
		candidate.interact()


func _set_world_labels_visible(candidate: InteractableMapNode, value: bool) -> void:
	for node: Node in candidate.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = value
