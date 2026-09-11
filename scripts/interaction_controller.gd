class_name InteractionController
extends Control

## Creates one screen-space prompt for every nearby interactable. Each prompt
## follows its world object so outdoor GPS drift never forces the player to
## make one object become the single "nearest" selection.

@export var player_path: NodePath
@export var action_button_path: NodePath
@export var detail_label_path: NodePath

const BUTTON_SIZE := Vector2(260.0, 58.0)
const DETAIL_SIZE := Vector2(280.0, 38.0)
const WORLD_OFFSET := Vector3(0.0, 0.65, 0.0)
const SCREEN_GAP := 12.0

var _button_template: Button
var _detail_template: Label
var _entries: Dictionary = {}


func _ready() -> void:
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


func _remove_stale_entries(available: Array[InteractableMapNode]) -> void:
	for candidate: Variant in _entries.keys():
		if is_instance_valid(candidate) and available.has(candidate as InteractableMapNode):
			continue
		var entry: Dictionary = _entries[candidate]
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
		var button_position := Vector2(
			clampf(projected.x - BUTTON_SIZE.x * 0.5, 12.0, viewport_size.x - BUTTON_SIZE.x - 12.0),
			clampf(projected.y + 28.0, 180.0, viewport_size.y - BUTTON_SIZE.y - 150.0)
		)
		var button_rect := Rect2(button_position, BUTTON_SIZE)
		while _intersects_any(button_rect, occupied):
			button_rect.position.y += BUTTON_SIZE.y + SCREEN_GAP
			if button_rect.end.y > viewport_size.y - 140.0:
				button_rect.position.y = maxf(180.0, button_rect.position.y - (BUTTON_SIZE.y + SCREEN_GAP) * 2.0)
				break
		occupied.append(button_rect)
		button.text = "TAP  •  %s" % candidate.get_action_label()
		detail.text = candidate.get_detail_text()
		button.position = button_rect.position
		detail.position = Vector2(button_rect.get_center().x - DETAIL_SIZE.x * 0.5, button_rect.position.y - DETAIL_SIZE.y - 6.0)
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
