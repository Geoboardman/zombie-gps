class_name Boss
extends Enemy

# A real encounter, not just a bigger zombie. Joins the "zombies" group
# so the player's existing auto-attack, damage aura, and knockback all
# work on it automatically -- no special-casing needed. What makes it a
# boss: a telegraphed AOE slam (freeze + warning flash + growing danger
# disc, giving a clear learnable window to back off) and an enrage phase
# at low HP. Meant to be genuinely losable the first time a player
# reaches it undergeared -- that's a feature, not a bug.

@export var max_health := 400
@export var attack_range := 2.0
@export var attack_damage := 18
@export var attack_cooldown := 1.2
@export var chase_speed := 1.6
@export var currency_reward := 150

@export_group("Slam Attack")
@export var slam_interval := 8.0
@export var slam_telegraph_duration := 1.2
@export var slam_radius := 4.0
@export var slam_damage := 35

@export_group("Enrage")
@export var enrage_health_percent := 0.3
@export var enrage_speed_multiplier := 1.4
@export var enrage_damage_multiplier := 1.3

signal attacked_player(damage: int)
signal died

var target: Node3D # set by whoever summons this boss (BossAltarNode)

var _attack_timer := 0.0
var _slam_timer := 0.0
var _is_telegraphing := false
var _enraged := false
var _base_color := Color(0.45, 0.1, 0.55) # boss purple, matches the altar theme
var _mesh_material: StandardMaterial3D
var _health_bar: HealthBar3D
var _telegraph_disc: MeshInstance3D


func _ready() -> void:
	add_to_group("zombies") # free auto-attack/aura targeting from the player, same as regular enemies
	add_to_group("bosses")

	_attack_timer = attack_cooldown
	_slam_timer = slam_interval

	health = Health.new(max_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	_mesh_material = StandardMaterial3D.new()
	_mesh_material.albedo_color = _base_color
	mesh_instance.set_surface_override_material(0, _mesh_material)

	_health_bar = get_node("HealthBar") as HealthBar3D
	_health_bar.set_fraction(1.0)

	_telegraph_disc = get_node("TelegraphDisc") as MeshInstance3D
	_telegraph_disc.visible = false


func _physics_process(delta: float) -> void:
	if target == null:
		return

	if _is_telegraphing:
		return # frozen mid-windup -- this is the player's window to back off

	_slam_timer -= delta
	if _slam_timer <= 0.0:
		_begin_slam_telegraph()
		return

	var distance := global_position.distance_to(target.global_position)

	if distance > attack_range:
		_move_toward(target.global_position, _current_speed(), delta)
	else:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			var damage := int(attack_damage * (enrage_damage_multiplier if _enraged else 1.0))
			attacked_player.emit(damage)
			_attack_timer = attack_cooldown


func _current_speed() -> float:
	return chase_speed * (enrage_speed_multiplier if _enraged else 1.0)


func _move_toward(destination: Vector3, speed: float, _delta: float) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()

	velocity = direction * speed * get_speed_multiplier()
	move_and_slide()
	look_at(global_position + direction, Vector3.UP)


func _begin_slam_telegraph() -> void:
	_is_telegraphing = true
	_telegraph_disc.visible = true
	_telegraph_disc.scale = Vector3.ZERO
	_mesh_material.albedo_color = Color(1.0, 0.3, 0.1) # held warning color -- not tweened away, so it doesn't fight with hit-flashes

	var tween := create_tween()
	tween.tween_property(_telegraph_disc, "scale", Vector3(slam_radius, slam_radius, slam_radius), slam_telegraph_duration)
	tween.tween_callback(_resolve_slam)


func _resolve_slam() -> void:
	_telegraph_disc.visible = false
	_is_telegraphing = false
	_slam_timer = slam_interval
	_mesh_material.albedo_color = _base_color

	if target != null and global_position.distance_to(target.global_position) <= slam_radius:
		attacked_player.emit(slam_damage)


func _on_health_changed(current: int, max_hp: int) -> void:
	_health_bar.set_fraction(float(current) / float(max_hp))

	if not _enraged and float(current) / float(max_hp) <= enrage_health_percent:
		_enraged = true
		_base_color = Color(0.9, 0.1, 0.1) # visible signal that this is now the dangerous part

	_flash_hit()


func _flash_hit() -> void:
	_mesh_material.albedo_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_mesh_material, "albedo_color", _base_color, 0.15)


func _on_died() -> void:
	set_physics_process(false)
	died.emit()
	queue_free()
