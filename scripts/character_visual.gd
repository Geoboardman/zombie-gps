class_name CharacterVisual
extends Node3D

## Thin adapter around imported character scenes. Gameplay scripts request
## semantic clip names without depending on the glTF's internal node layout.

var _animation_player: AnimationPlayer
var _locked := false
var _generation := 0


func _ready() -> void:
	_animation_player = _find_animation_player(self)
	if _animation_player == null:
		push_warning("[CharacterVisual] Imported model has no AnimationPlayer")


func play_clip(clip_name: String, blend := 0.15, force := false) -> void:
	if _animation_player == null or (_locked and not force):
		return
	var resolved := _resolve_clip(clip_name)
	if resolved == "":
		return
	var animation := _animation_player.get_animation(resolved)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	if _animation_player.current_animation == resolved and _animation_player.is_playing():
		return
	_generation += 1
	_animation_player.play(resolved, blend)


func play_once(clip_name: String, return_clip: String, fallback_duration := 0.35) -> void:
	if _animation_player == null:
		return
	var resolved := _resolve_clip(clip_name)
	if resolved == "":
		return
	_generation += 1
	var generation := _generation
	_locked = true
	var animation := _animation_player.get_animation(resolved)
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(resolved, 0.05)
	var duration: float = animation.length if animation != null else fallback_duration
	get_tree().create_timer(maxf(0.08, minf(duration, fallback_duration))).timeout.connect(func():
		if not is_instance_valid(self) or generation != _generation:
			return
		_locked = false
		play_clip(return_clip, 0.1, true)
	)


func play_death() -> float:
	if _animation_player == null:
		return 0.65
	var resolved := _resolve_clip("Death")
	if resolved == "":
		return 0.65
	_generation += 1
	_locked = true
	var animation := _animation_player.get_animation(resolved)
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(resolved, 0.05)
	return clampf(animation.length if animation != null else 0.9, 0.45, 2.0)


func recoil() -> void:
	var original := position
	position += Vector3(0.0, 0.04, 0.10)
	var tween := create_tween()
	tween.tween_property(self, "position", original, 0.12).set_trans(Tween.TRANS_QUAD)


func set_animation_speed(value: float) -> void:
	if _animation_player != null:
		_animation_player.speed_scale = maxf(0.0, value)


func _resolve_clip(requested: String) -> String:
	if _animation_player.has_animation(requested):
		return requested
	for candidate in _animation_player.get_animation_list():
		if candidate.to_lower().ends_with(requested.to_lower()):
			return candidate
	return ""


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null
