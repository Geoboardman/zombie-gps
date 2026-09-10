class_name Survivor
extends CharacterBody3D

# A recruited party member that follows the player and provides exactly
# one clear benefit, depending on kind. Deliberately simple for now --
# no health, no death, no separate ability/upgrade system. Prove the
# "party grows and visibly fights with you" hook first; depth (losing
# survivors, upgrading them individually) is a later increment once this
# feels good.

enum SurvivorKind {
	FIGHTER, # auto-attacks the nearest zombie, same pattern as the player
	MEDIC, # periodically heals the player
	SCOUT, # permanently boosts the player's currency gain while alive
}

@export var kind: SurvivorKind = SurvivorKind.FIGHTER
@export var follow_distance := 2.5
@export var follow_speed := 3.0
@export var follow_offset_angle := 0.0 # spawner assigns a different angle to each so they don't stack

@export_group("Fighter")
@export var attack_range := 3.0
@export var attack_damage := 8
@export var attack_interval := 1.2

@export_group("Medic")
@export var heal_interval := 6.0
@export var heal_amount := 10

@export_group("Scout")
@export var currency_bonus := 0.10 # added to the player's currency_gain_multiplier once, on recruit

var player: PlayerController # set by whoever recruits this survivor (SurvivorNode)

var _attack_timer := 0.0
var _heal_timer := 0.0


func _ready() -> void:
	add_to_group("survivors")

	_attack_timer = attack_interval
	_heal_timer = heal_interval

	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_for_kind(kind)
	mesh_instance.set_surface_override_material(0, mat)

	var label := get_node("RoleLabel") as Label3D
	label.text = name_for_kind(kind)

	if kind == SurvivorKind.SCOUT and player != null:
		player.currency_gain_multiplier += currency_bonus


func _physics_process(delta: float) -> void:
	if player == null:
		return

	_follow_player(delta)

	match kind:
		SurvivorKind.FIGHTER:
			_process_fighter(delta)
		SurvivorKind.MEDIC:
			_process_medic(delta)
		_:
			pass # Scout's benefit is a one-time stat bump applied in _ready, nothing to tick


func _follow_player(_delta: float) -> void:
	var target_offset := Vector3(cos(follow_offset_angle), 0.0, sin(follow_offset_angle)) * follow_distance
	var target_pos := player.global_position + target_offset

	var direction := target_pos - global_position
	direction.y = 0.0

	if direction.length() > 0.3: # small deadzone so it doesn't jitter in place once it arrives
		var move_dir := direction.normalized()
		velocity = move_dir * follow_speed
		move_and_slide()
		look_at(global_position + move_dir, Vector3.UP)
	else:
		velocity = Vector3.ZERO


func _process_fighter(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return

	var nearest: Enemy = null
	var nearest_dist := attack_range

	for node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= nearest_dist:
			nearest = enemy
			nearest_dist = dist

	if nearest != null:
		nearest.take_damage(attack_damage)
		_attack_timer = attack_interval
		_play_attack_lunge(nearest.global_position)


func _process_medic(delta: float) -> void:
	_heal_timer -= delta
	if _heal_timer > 0.0:
		return

	if player != null:
		player.health.heal(heal_amount)

	_heal_timer = heal_interval


static func name_for_kind(k: SurvivorKind) -> String:
	match k:
		SurvivorKind.FIGHTER:
			return "Fighter"
		SurvivorKind.MEDIC:
			return "Medic"
		SurvivorKind.SCOUT:
			return "Scout"
		_:
			return "Survivor"


static func color_for_kind(k: SurvivorKind) -> Color:
	match k:
		SurvivorKind.FIGHTER:
			return Color(0.85, 0.7, 0.2) # warrior gold
		SurvivorKind.MEDIC:
			return Color(0.4, 0.75, 0.95) # medical blue -- was near-white before, indistinguishable from the player
		SurvivorKind.SCOUT:
			return Color(0.4, 0.75, 0.5) # scout green
		_:
			return Color.WHITE


# Quick "punch" pulse on the mesh, plus a snap-to-face-target -- not a
# real animation (that needs a rigged model), but enough to read as
# "an action just happened" at a glance, with zero art assets.
func _play_attack_lunge(target_pos: Vector3) -> void:
	look_at(Vector3(target_pos.x, global_position.y, target_pos.z), Vector3.UP)

	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	var original_scale := mesh_instance.scale
	mesh_instance.scale = original_scale * 1.25
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", original_scale, 0.15)
