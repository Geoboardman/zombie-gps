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
	if health != null:
		health.take_damage(amount)
