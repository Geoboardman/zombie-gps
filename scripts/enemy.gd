class_name Enemy
extends CharacterBody3D

# Common base for anything the player or survivors can auto-target and
# damage -- regular zombies and the boss both extend this. Attack code
# (PlayerController._try_attack, _apply_aura_damage, Survivor's fighter
# loop) loops over the "zombies" group and casts to Enemy, so any enemy
# type automatically works with existing combat without special-casing --
# this is what was missing before, which is why the boss silently took
# zero damage from anything.

var health: Health
var _stasis_timer := 0.0
var _speed_multiplier := 1.0


func _process(delta: float) -> void:
	if _stasis_timer <= 0.0:
		return
	_stasis_timer -= delta
	if _stasis_timer <= 0.0:
		_speed_multiplier = 1.0


func apply_stasis(duration: float, speed_multiplier: float) -> void:
	_stasis_timer = max(_stasis_timer, duration)
	_speed_multiplier = min(_speed_multiplier, clamp(speed_multiplier, 0.0, 1.0))
	_spawn_status_ring(Color(0.2, 0.75, 1.0, 0.8), duration)


func get_speed_multiplier() -> float:
	return _speed_multiplier


func _spawn_status_ring(color: Color, duration: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.75
	mesh.height = 0.025
	ring.mesh = mesh
	ring.position = Vector3(0.0, 0.06, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(1.35, 1.0, 1.35), duration)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)


func take_damage(amount: int) -> void:
	if health == null or health.current_health <= 0 or amount <= 0:
		return
	var actual_damage: int = mini(amount, health.current_health)
	var lethal := actual_damage >= health.current_health
	health.take_damage(amount)
	_spawn_damage_number(actual_damage, lethal)


func _spawn_damage_number(amount: int, lethal: bool) -> void:
	var number := Label3D.new()
	number.text = str(amount)
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.fixed_size = true
	number.no_depth_test = true
	number.font_size = 40 if lethal else 30
	number.outline_size = 8
	number.pixel_size = 0.003
	number.modulate = Color(1.0, 0.34, 0.18) if lethal else _damage_number_color(amount)
	number.outline_modulate = Color(0.03, 0.04, 0.05, 0.95)
	get_tree().current_scene.add_child(number)
	var side_offset := -0.22 if get_instance_id() % 2 == 0 else 0.22
	number.global_position = global_position + Vector3(side_offset, 2.0, 0.0)
	number.scale = Vector3.ONE * (1.15 if lethal else 1.0)
	var tween := number.create_tween()
	tween.set_parallel(true)
	tween.tween_property(number, "global_position", number.global_position + Vector3(0.0, 1.15, 0.0), 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.72).set_delay(0.18)
	tween.tween_property(number, "scale", Vector3.ONE * 0.82, 0.72)
	tween.chain().tween_callback(number.queue_free)


func _damage_number_color(amount: int) -> Color:
	if health != null and amount >= int(ceil(float(health.max_health) * 0.25)):
		return Color(1.0, 0.72, 0.16)
	return Color(0.94, 0.98, 1.0)
