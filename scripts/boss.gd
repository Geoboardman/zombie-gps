class_name Boss
extends Enemy

enum Mutation { RELENTLESS, JUGGERNAUT, RABID }

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
@export var mutation := Mutation.RELENTLESS

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
var _mesh_material: StandardMaterial3D
var _health_bar: HealthBar3D
var _telegraph_disc: MeshInstance3D
var _visual: CharacterVisual


static func mutation_name(value: int) -> String:
	match value:
		Mutation.JUGGERNAUT: return "JUGGERNAUT"
		Mutation.RABID: return "RABID"
		_: return "RELENTLESS"


static func mutation_description(value: int) -> String:
	match value:
		Mutation.JUGGERNAUT: return "More health and heavier hits"
		Mutation.RABID: return "Moves and attacks faster"
		_: return "Slams more frequently"


func _ready() -> void:
	add_to_group("zombies") # free auto-attack/aura targeting from the player, same as regular enemies
	add_to_group("bosses")

	_apply_mutation()
	_attack_timer = attack_cooldown
	_slam_timer = slam_interval

	health = Health.new(max_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	_mesh_material = StandardMaterial3D.new()
	_mesh_material.albedo_color = Color(1.0, 0.3, 0.1, 0.0)
	_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, _mesh_material)

	_health_bar = get_node("HealthBar") as HealthBar3D
	_health_bar.set_fraction(1.0)

	_telegraph_disc = get_node("TelegraphDisc") as MeshInstance3D
	_telegraph_disc.visible = false
	_visual = get_node_or_null("VisualRoot") as CharacterVisual
	if _visual != null:
		_visual.play_clip("Idle_Attack")


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
		if _visual != null:
			_visual.play_clip("Run")
		_move_toward(target.global_position, _current_speed(), delta)
	else:
		if _visual != null:
			_visual.play_clip("Idle_Attack")
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			if _visual != null:
				_visual.play_once("Punch", "Idle_Attack", 0.5)
			var damage := int(attack_damage * (enrage_damage_multiplier if _enraged else 1.0))
			var survivor_target := _nearest_survivor_in_range(attack_range * 1.4)
			if survivor_target != null:
				survivor_target.take_damage(damage)
			else:
				attacked_player.emit(damage)
			_attack_timer = attack_cooldown


func _current_speed() -> float:
	return chase_speed * (enrage_speed_multiplier if _enraged else 1.0)


func _apply_mutation() -> void:
	match mutation:
		Mutation.JUGGERNAUT:
			max_health = int(round(float(max_health) * 1.35))
			attack_damage = int(round(float(attack_damage) * 1.2))
			slam_damage = int(round(float(slam_damage) * 1.15))
		Mutation.RABID:
			chase_speed *= 1.25
			attack_cooldown *= 0.75
		_:
			slam_interval *= 0.7


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
	if _visual != null:
		_visual.play_clip("Idle_Attack")
	_telegraph_disc.visible = true
	_telegraph_disc.scale = Vector3.ZERO
	_mesh_material.albedo_color = Color(1.0, 0.3, 0.1, 0.32)

	var tween := create_tween()
	tween.tween_property(_telegraph_disc, "scale", Vector3(slam_radius, slam_radius, slam_radius), slam_telegraph_duration)
	tween.tween_callback(_resolve_slam)


func _resolve_slam() -> void:
	_telegraph_disc.visible = false
	_is_telegraphing = false
	_slam_timer = slam_interval
	_mesh_material.albedo_color = Color(1.0, 0.3, 0.1, 0.0)

	if target != null and global_position.distance_to(target.global_position) <= slam_radius:
		attacked_player.emit(slam_damage)
	for node: Node in get_tree().get_nodes_in_group("survivors"):
		var survivor := node as Survivor
		if survivor != null and survivor.can_be_attacked() and global_position.distance_to(survivor.global_position) <= slam_radius:
			survivor.take_damage(slam_damage)


func _nearest_survivor_in_range(maximum_distance: float) -> Survivor:
	var nearest: Survivor = null
	var nearest_distance := maximum_distance
	for node: Node in get_tree().get_nodes_in_group("survivors"):
		var candidate := node as Survivor
		if candidate == null or not candidate.can_be_attacked():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _on_health_changed(current: int, max_hp: int) -> void:
	_health_bar.set_fraction(float(current) / float(max_hp))

	if not _enraged and float(current) / float(max_hp) <= enrage_health_percent:
		_enraged = true
		_mesh_material.albedo_color = Color(0.9, 0.1, 0.1, 0.22)

	_flash_hit()


func _flash_hit() -> void:
	var resting_color := Color(0.9, 0.1, 0.1, 0.22) if _enraged else Color(1.0, 0.3, 0.1, 0.0)
	_mesh_material.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
	var tween := create_tween()
	tween.tween_property(_mesh_material, "albedo_color", resting_color, 0.15)
	if _visual != null:
		_visual.play_once("HitReact", "Idle_Attack", 0.25)


func _on_died() -> void:
	set_physics_process(false)
	var collision := get_node("CollisionShape3D") as CollisionShape3D
	collision.set_deferred("disabled", true)
	var delay := _visual.play_death() if _visual != null else 0.4
	get_tree().create_timer(delay).timeout.connect(func():
		died.emit()
		queue_free()
	)
