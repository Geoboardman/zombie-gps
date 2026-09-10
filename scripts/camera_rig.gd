class_name CameraRig
extends Node3D

# Simple angled follow camera, similar to the Pokemon GO / GO Map demo view:
# elevated and pulled back, smoothly trailing the player rather than
# snapping rigidly to their position. Supports zoom via mouse scroll wheel
# (desktop testing) -- scales height and distance together so it reads as
# a real camera zoom rather than just moving vertically.

@export var target_path: NodePath
@export var height := 12.0
@export var distance := 8.0
@export var follow_speed := 5.0

@export_group("Zoom")
@export var zoom_min := 0.5 # closest -- half the base height/distance
@export var zoom_max := 2.0 # farthest -- double the base height/distance
@export var zoom_step := 0.1
@export var zoom_speed := 8.0 # how quickly zoom eases toward its target level

var _target: Node3D
var _zoom := 1.0
var _target_zoom := 1.0


func _ready() -> void:
	_target = get_node(target_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clamp(_target_zoom - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clamp(_target_zoom + zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	if _target == null:
		return

	_zoom = lerp(_zoom, _target_zoom, delta * zoom_speed)

	var desired_position := _target.global_position + Vector3(0, height, distance) * _zoom
	global_position = global_position.lerp(desired_position, delta * follow_speed)
	look_at(_target.global_position, Vector3.UP)
