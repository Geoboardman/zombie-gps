class_name Survivor
extends CharacterBody3D

enum SurvivorKind { FIGHTER, MEDIC, SCOUT }

signal permanently_lost(survivor: Survivor)
signal level_gained(survivor: Survivor)

const NAMES := ["Lis", "Matt", "Sam", "Shaun"]

@export var kind: SurvivorKind = SurvivorKind.FIGHTER
@export var appearance_index := 0
@export var survivor_name := "Sam"
@export var follow_distance := 2.5
@export var follow_speed := 3.0
@export var follow_offset_angle := 0.0
@export_group("Combat")
@export var max_health := 60
@export var attack_range := 3.0
@export var attack_damage := 8
@export var attack_interval := 1.2
@export_group("Medic")
@export var heal_interval := 6.0
@export var heal_amount := 8
@export_group("Progression")
@export var level := 1
@export var experience := 0
@export var experience_per_level := 5
@export var downed_recovery_time := 8.0

var player: PlayerController
var health: Health
var injuries := 0
var is_downed := false
var _attack_timer := 0.0
var _heal_timer := 0.0
var _dressing_timer := 0.0
var _dressing_remaining := 0.0
var _dressing_accumulator := 0.0
var _recovery_generation := 0
var _visual: CharacterVisual
var _health_bar: HealthBar3D
var _role_label: Label3D


func _ready() -> void:
	add_to_group("survivors")
	_configure_role_stats()
	_attack_timer = attack_interval
	_heal_timer = heal_interval
	_health_bar = get_node("HealthBar") as HealthBar3D
	_role_label = get_node("RoleLabel") as Label3D
	_select_appearance()
	_visual = get_node_or_null("Visual%d" % appearance_index) as CharacterVisual
	_refresh_label()
	_create_health(max_health)
	if _visual != null:
		_visual.play_clip("Idle_Gun")
		_visual.select_embedded_weapon(weapon_name_for_kind(kind))


func _physics_process(delta: float) -> void:
	if player == null or is_downed:
		return
	_follow_player()
	_process_weapon(delta)
	_process_field_dressing(delta)
	if kind == SurvivorKind.MEDIC:
		_process_medic(delta)


func take_damage(amount: int) -> void:
	if not is_downed and health != null:
		print("[Survivor] %s took %d enemy damage" % [survivor_name, amount])
		health.take_damage(amount)


func receive_healing(amount: int) -> void:
	if not is_downed and health != null:
		health.heal(amount)


func needs_field_dressing() -> bool:
	return is_downed or injuries > 0 or (health != null and health.current_health < health.max_health)


func apply_field_dressing(duration: float, heal_percent: float) -> void:
	if is_downed:
		_recovery_generation += 1
		is_downed = false
		_create_health(maxi(1, int(round(float(max_health) * 0.2))))
		_health_bar.visible = true
		if _visual != null:
			_visual.play_clip("Idle_Gun", 0.1, true)
	else:
		injuries = 0
	_dressing_timer = duration
	_dressing_remaining = float(max_health) * heal_percent
	_dressing_accumulator = 0.0
	_refresh_label()


func award_experience(amount: int) -> void:
	if is_downed:
		return
	experience += maxi(0, amount)
	while experience >= experience_per_level:
		experience -= experience_per_level
		level += 1
		max_health += 8
		attack_damage += 2
		health.max_health = max_health
		health.heal(8)
		level_gained.emit(self)
	_refresh_label()


func can_be_attacked() -> bool:
	return not is_downed and health != null and health.current_health > 0


func _configure_role_stats() -> void:
	match kind:
		SurvivorKind.MEDIC:
			attack_damage = 5
			attack_interval = 1.5
		SurvivorKind.SCOUT:
			attack_range = 5.5
			attack_damage = 14
			attack_interval = 1.8


func _create_health(current: int) -> void:
	health = Health.new(max_health)
	health.current_health = clampi(current, 1, max_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_health_depleted)
	_health_bar.set_fraction(float(health.current_health) / float(max_health))


func _follow_player() -> void:
	var target_offset := Vector3(cos(follow_offset_angle), 0.0, sin(follow_offset_angle)) * follow_distance
	var direction := player.global_position + target_offset - global_position
	direction.y = 0.0
	if direction.length() > 0.3:
		var move_dir := direction.normalized()
		velocity = move_dir * follow_speed
		move_and_slide()
		look_at(global_position + move_dir, Vector3.UP)
		if _visual != null:
			_visual.play_clip("Walk_Gun")
	else:
		velocity = Vector3.ZERO
		if _visual != null:
			_visual.play_clip("Idle_Gun")


func _process_weapon(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	var nearest: Enemy = null
	var nearest_distance := attack_range
	for node: Node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest == null:
		return
	nearest.take_damage(attack_damage)
	_attack_timer = attack_interval
	look_at(Vector3(nearest.global_position.x, global_position.y, nearest.global_position.z), Vector3.UP)
	if _visual != null:
		_visual.recoil()
	_play_shot_feedback(nearest.global_position)


func _process_medic(delta: float) -> void:
	_heal_timer -= delta
	if _heal_timer > 0.0:
		return
	var most_hurt: Survivor = null
	var lowest_fraction := 1.0
	for node: Node in get_tree().get_nodes_in_group("survivors"):
		var ally := node as Survivor
		if ally == null or not ally.can_be_attacked():
			continue
		var fraction := float(ally.health.current_health) / float(ally.health.max_health)
		if fraction < lowest_fraction:
			lowest_fraction = fraction
			most_hurt = ally
	if most_hurt != null:
		most_hurt.health.heal(heal_amount)
	elif player != null:
		player.health.heal(heal_amount)
	_heal_timer = heal_interval


func _process_field_dressing(delta: float) -> void:
	if _dressing_timer <= 0.0 or is_downed or health == null:
		return
	var active_delta: float = minf(delta, _dressing_timer)
	_dressing_timer -= active_delta
	var heal_this_frame: float = (_dressing_remaining / maxf(_dressing_timer + active_delta, 0.001)) * active_delta
	_dressing_remaining = maxf(0.0, _dressing_remaining - heal_this_frame)
	_dressing_accumulator += heal_this_frame
	if _dressing_accumulator >= 1.0:
		var whole := int(_dressing_accumulator)
		_dressing_accumulator -= float(whole)
		health.heal(whole)


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.set_fraction(float(current) / float(maximum))
	if _visual != null:
		_visual.play_once("HitReact", "Idle_Gun", 0.25)


func _on_health_depleted() -> void:
	if injuries == 0:
		injuries = 1
		is_downed = true
		_recovery_generation += 1
		var recovery_generation := _recovery_generation
		velocity = Vector3.ZERO
		_role_label.text = "%s\nDOWNED" % survivor_name
		_health_bar.visible = false
		if _visual != null:
			_visual.play_death()
		get_tree().create_timer(downed_recovery_time).timeout.connect(_recover_injured.bind(recovery_generation))
		return
	_permanently_die()


func _recover_injured(recovery_generation: int) -> void:
	if not is_inside_tree() or recovery_generation != _recovery_generation or not is_downed:
		return
	is_downed = false
	_create_health(int(round(float(max_health) * 0.4)))
	_health_bar.visible = true
	_refresh_label()
	if _visual != null:
		_visual.play_clip("Idle_Gun", 0.1, true)


func _permanently_die() -> void:
	is_downed = true
	remove_from_group("survivors")
	_role_label.text = "%s\nLOST" % survivor_name
	permanently_lost.emit(self)
	var delay := _visual.play_death() if _visual != null else 0.5
	get_tree().create_timer(delay).timeout.connect(queue_free)


func _select_appearance() -> void:
	appearance_index = clampi(appearance_index, 0, NAMES.size() - 1)
	survivor_name = NAMES[appearance_index]
	for index in range(NAMES.size()):
		var visual_root := get_node_or_null("Visual%d" % index) as Node3D
		if visual_root != null:
			visual_root.visible = index == appearance_index


func _refresh_label() -> void:
	_role_label.text = "%s\n%s • Lv.%d%s" % [survivor_name, name_for_kind(kind), level, " • Injured" if injuries > 0 else ""]


static func name_for_kind(value: SurvivorKind) -> String:
	match value:
		SurvivorKind.FIGHTER: return "Fighter"
		SurvivorKind.MEDIC: return "Medic"
		SurvivorKind.SCOUT: return "Scout"
		_: return "Survivor"


static func description_for_kind(value: SurvivorKind) -> String:
	match value:
		SurvivorKind.FIGHTER: return "steady rifle damage"
		SurvivorKind.MEDIC: return "fights and heals the wounded"
		SurvivorKind.SCOUT: return "long-range precision fire"
		_: return "fights alongside the party"


static func weapon_name_for_kind(value: SurvivorKind) -> String:
	match value:
		SurvivorKind.FIGHTER: return "Shotgun"
		SurvivorKind.SCOUT: return "Rifle"
		_: return "Pistol"


func _play_shot_feedback(target_position: Vector3) -> void:
	var start := global_position + Vector3(0.0, 1.15, 0.0)
	var end := target_position + Vector3(0.0, 0.9, 0.0)
	var tracer := MeshInstance3D.new()
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(start)
	line_mesh.surface_add_vertex(end)
	line_mesh.surface_end()
	tracer.mesh = line_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.9, 1.0) if kind == SurvivorKind.SCOUT else Color(1.0, 0.82, 0.25)
	material.emission_enabled = true
	material.emission = material.albedo_color
	tracer.material_override = material
	get_tree().current_scene.add_child(tracer)
	get_tree().create_timer(0.07).timeout.connect(tracer.queue_free)
