class_name PlayerController
extends CharacterBody3D

# Keeps the player's visual position locked to GPSManager's reported
# location, faces movement direction, and owns the player's health,
# currency, and combat loop. Auto-attack and the damage aura are still
# fully passive. Stasis Pulse, Field Dressing, and Frag Grenade are
# player-triggered abilities on cooldowns instead -- single key tap each,
# no aiming or held input, so it stays glance-and-tap rather than
# something that demands sustained screen attention while walking.

@export var gps_manager_path: NodePath
@export var hud_label_path: NodePath # optional: a Label to show "HP: x/y"
@export var health_bar_path: NodePath # optional: a ProgressBar for mobile-readable health
@export var currency_label_path: NodePath # optional: a Label to show currency
@export var build_label_path: NodePath # optional: compact list of acquired upgrades

@export_group("Health & Attack")
@export var max_health := 100
@export var attack_range := 3.0
@export var attack_interval := 1.0
@export var attack_damage := 15

@export_group("Sustain")
@export var invulnerability_duration := 0.5 # brief i-frames after any hit -- stops a swarm from stacking multiple hits at once
@export var regen_per_second := 0.5 # slow passive trickle -- always on, no input needed
@export var lifesteal_percent := 0.0 # heal for this fraction of damage dealt on each hit -- upgradeable, 0 by default
@export var damage_reduction_percent := 0.0 # flat percent reduction applied to all incoming damage -- upgradeable, 0 by default

@export_group("Damage Aura")
@export var aura_radius := 2.5
@export var aura_damage_per_tick := 3
@export var aura_tick_interval := 0.5

@export_group("Ability: Stasis Pulse")
@export var stasis_cooldown := 7.0
@export var stasis_radius := 4.0
@export var stasis_duration := 2.5
@export var stasis_action := "ability_1"

@export_group("Ability: Field Dressing")
@export var field_dressing_cooldown := 18.0
@export var field_dressing_heal_percent := 0.35
@export var field_dressing_duration := 8.0
@export var field_dressing_action := "ability_2"

@export_group("Ability: Frag Grenade")
@export var grenade_cooldown := 10.0
@export var grenade_target_range := 10.0
@export var grenade_radius := 3.0
@export var grenade_damage := 35
@export var grenade_fuse := 0.65
@export var grenade_action := "ability_3"

var health: Health
var currency := 0
var currency_gain_multiplier := 1.0
var double_tap_level := 0
var piercing_targets := 0
var execution_damage_multiplier := 1.0
var aura_bonus_damage := 0
var adrenaline_attack_multiplier := 1.0
var grenade_cluster_count := 0

var _gps: GPSManager
var _last_position: Vector3
var _attack_timer := 0.0
var _aura_timer: float
var _invulnerable_timer := 0.0
var _regen_accumulator := 0.0 # fractional HP banked here until it crosses a whole point
var _field_dressing_timer := 0.0
var _field_dressing_remaining := 0.0
var _ability_cooldowns: Dictionary = {} # Abilities.Type -> float remaining
var _upgrade_counts: Dictionary = {}
var _hud_label: Label
var _health_bar: ProgressBar
var _currency_label: Label
var _build_label: Label
var _mesh_material: StandardMaterial3D
var _visual: CharacterVisual
var _movement_animation_timer := 0.0

const BASE_PLAYER_COLOR := Color(0.85, 0.85, 0.88)
const STASIS_FLASH_COLOR := Color(0.3, 0.6, 0.95)
const DRESSING_COLOR := Color(0.3, 0.9, 0.4)


func _ready() -> void:
	_gps = get_node(gps_manager_path)
	_gps.location_updated.connect(_on_location_updated)
	_last_position = global_position

	health = Health.new(max_health)
	var profile := RunProfile.load_profile()
	var training: int = int(profile.get("training_level", 0))
	if training > 0:
		health.max_health += training * 10
		health.heal(training * 10)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	_aura_timer = aura_tick_interval

	# Gives the player capsule a real material to tint/flash for ability
	# feedback -- without this it renders with Godot's default debug
	# material and has no consistent base color to flash away from.
	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	_mesh_material = StandardMaterial3D.new()
	_mesh_material.albedo_color = BASE_PLAYER_COLOR
	mesh_instance.set_surface_override_material(0, _mesh_material)
	_visual = get_node_or_null("VisualRoot") as CharacterVisual
	if _visual != null:
		_visual.play_clip("Idle_Gun")

	# All three abilities granted by default for now, ready immediately --
	# this is a "test whether active abilities feel good at all" pass,
	# not the final unlock/progression design. Gating them behind shop
	# purchases (or a class system) is a deliberate next step, not yet.
	for type in Abilities.Type.values():
		_ability_cooldowns[type] = 0.0

	if hud_label_path != NodePath(""):
		_hud_label = get_node(hud_label_path)
	if health_bar_path != NodePath(""):
		_health_bar = get_node(health_bar_path)
	_update_hud()

	if currency_label_path != NodePath(""):
		_currency_label = get_node(currency_label_path)
		_update_currency_label()
	if build_label_path != NodePath(""):
		_build_label = get_node(build_label_path)
		_update_build_label()


func _process(delta: float) -> void:
	if _movement_animation_timer > 0.0:
		_movement_animation_timer -= delta
		if _movement_animation_timer <= 0.0 and _visual != null:
			_visual.play_clip("Idle_Gun")
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_try_attack()

	_aura_timer -= delta
	if _aura_timer <= 0.0:
		_apply_aura_damage()
		_aura_timer = aura_tick_interval

	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta

	_apply_regen(delta)
	_process_field_dressing(delta)
	_process_abilities(delta)


func _try_attack() -> void:
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
		var damage := _effective_attack_damage(nearest)
		nearest.take_damage(damage)
		_attack_timer = attack_interval * _current_attack_interval_multiplier()
		_play_attack_lunge(nearest.global_position)
		_apply_piercing_hits(nearest)
		if double_tap_level > 0:
			get_tree().create_timer(0.12).timeout.connect(func():
				if is_instance_valid(nearest):
					nearest.take_damage(int(damage * (0.5 + 0.1 * double_tap_level)))
			)

		if lifesteal_percent > 0.0:
			var heal_amount := int(damage * lifesteal_percent)
			if heal_amount > 0:
				health.heal(heal_amount)


# Passive damage tick to any enemy standing close, so lingering in a
# crowd is punished for THEM too, not just the player.
func _apply_aura_damage() -> void:
	for node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) <= aura_radius:
			enemy.take_damage(aura_damage_per_tick + aura_bonus_damage)


func _effective_attack_damage(enemy: Enemy) -> int:
	if enemy.health != null and float(enemy.health.current_health) / float(enemy.health.max_health) <= 0.3:
		return int(attack_damage * execution_damage_multiplier)
	return attack_damage


func _current_attack_interval_multiplier() -> float:
	if float(health.current_health) / float(health.max_health) <= 0.35:
		return adrenaline_attack_multiplier
	return 1.0


func _apply_piercing_hits(primary: Enemy) -> void:
	if piercing_targets <= 0:
		return
	var hits := 0
	for node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy == null or enemy == primary:
			continue
		if global_position.distance_to(enemy.global_position) <= attack_range + 1.5:
			enemy.take_damage(int(attack_damage * 0.6))
			hits += 1
			if hits >= piercing_targets:
				return


# Small passive HP trickle, always on. Accumulates fractionally since
# regen_per_second is often less than 1 -- only applies a real heal once
# a whole point has banked up.
func _apply_regen(delta: float) -> void:
	if regen_per_second <= 0.0 or health.current_health <= 0:
		return

	_regen_accumulator += regen_per_second * delta
	if _regen_accumulator >= 1.0:
		var whole := int(_regen_accumulator)
		_regen_accumulator -= whole
		health.heal(whole)


func _process_field_dressing(delta: float) -> void:
	if _field_dressing_timer <= 0.0:
		return
	var active_delta: float = minf(delta, _field_dressing_timer)
	_field_dressing_timer -= active_delta
	var heal_this_frame: float = (_field_dressing_remaining / maxf(_field_dressing_timer + active_delta, 0.001)) * active_delta
	_regen_accumulator += heal_this_frame
	_field_dressing_remaining = max(0.0, _field_dressing_remaining - heal_this_frame)
	if _regen_accumulator >= 1.0:
		var whole := int(_regen_accumulator)
		_regen_accumulator -= whole
		health.heal(whole)
	if _field_dressing_timer <= 0.0 and _mesh_material != null:
		_mesh_material.albedo_color = BASE_PLAYER_COLOR


#region Abilities

func _process_abilities(delta: float) -> void:
	for type in _ability_cooldowns.keys():
		if _ability_cooldowns[type] > 0.0:
			_ability_cooldowns[type] -= delta

	if Input.is_action_just_pressed(stasis_action):
		try_activate_ability(Abilities.Type.STASIS_PULSE)
	if Input.is_action_just_pressed(field_dressing_action):
		try_activate_ability(Abilities.Type.FIELD_DRESSING)
	if Input.is_action_just_pressed(grenade_action):
		try_activate_ability(Abilities.Type.FRAG_GRENADE)


# Public so both keyboard input (above) and the on-screen AbilityBar
# buttons (mouse click or touch tap, same code path) can trigger the
# same ability the same way.
func try_activate_ability(type: Abilities.Type) -> void:
	if _ability_cooldowns.get(type, 0.0) > 0.0:
		return
	if not Abilities.can_activate(self, type):
		return

	var description := Abilities.activate(self, type)
	print("[Abilities] %s" % description)
	_ability_cooldowns[type] = Abilities.cooldown_for(self, type)


# Used by AbilityButtonUI to draw its cooldown wipe -- 0 = ready, 1 = just used.
func get_ability_cooldown_fraction(type: Abilities.Type) -> float:
	var remaining: float = _ability_cooldowns.get(type, 0.0)
	var total := Abilities.cooldown_for(self, type)
	if total <= 0.0:
		return 0.0
	return clamp(remaining / total, 0.0, 1.0)


# Briefly tints the player capsule a color, then eases back to the base
# color -- used to give every ability SOME visible confirmation it fired,
# even ones (like Second Wind's heal) that don't otherwise change
# anything the player can see.
func _flash_color(color: Color, duration: float) -> void:
	if _mesh_material == null:
		return
	_mesh_material.albedo_color = color
	var tween := create_tween()
	tween.tween_property(_mesh_material, "albedo_color", BASE_PLAYER_COLOR, duration)


# Quick "punch" pulse on the mesh, plus a snap-to-face-target -- not a
# real animation (that needs a rigged model), but enough to read as
# "an action just happened" at a glance, with zero art assets.
func _play_attack_lunge(target_pos: Vector3) -> void:
	look_at(Vector3(target_pos.x, global_position.y, target_pos.z), Vector3.UP)
	if _visual != null:
		_visual.recoil()
		_play_shot_feedback(target_pos)
		return

	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	var original_scale := mesh_instance.scale
	mesh_instance.scale = original_scale * 1.25
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", original_scale, 0.15)


func _play_shot_feedback(target_pos: Vector3) -> void:
	var start := global_position + Vector3(0.0, 1.15, 0.0)
	var end := target_pos + Vector3(0.0, 0.9, 0.0)
	var tracer := MeshInstance3D.new()
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(start)
	line_mesh.surface_add_vertex(end)
	line_mesh.surface_end()
	tracer.mesh = line_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.25)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.55, 0.1)
	tracer.material_override = material
	get_tree().current_scene.add_child(tracer)
	get_tree().create_timer(0.07).timeout.connect(tracer.queue_free)

	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.12
	flash_mesh.height = 0.24
	flash.mesh = flash_mesh
	flash.material_override = material
	get_tree().current_scene.add_child(flash)
	flash.global_position = start
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ZERO, 0.1)
	tween.tween_callback(flash.queue_free)


# Stops nearby zombies in attack range; bosses are slowed rather than frozen.
func stasis_pulse() -> void:
	_flash_color(STASIS_FLASH_COLOR, 0.25)
	for node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if global_position.distance_to(enemy.global_position) <= stasis_radius:
			enemy.apply_stasis(stasis_duration, 0.4 if enemy is Boss else 0.0)


# Starts a visible heal-over-time window instead of erasing danger instantly.
func field_dressing() -> void:
	_field_dressing_timer = field_dressing_duration
	_field_dressing_remaining = health.max_health * field_dressing_heal_percent
	for node: Node in get_tree().get_nodes_in_group("survivors"):
		var survivor := node as Survivor
		if survivor != null:
			survivor.apply_field_dressing(field_dressing_duration, field_dressing_heal_percent)
	if _mesh_material != null:
		_mesh_material.albedo_color = DRESSING_COLOR


func is_field_dressing_active() -> bool:
	return _field_dressing_timer > 0.0


func party_needs_dressing() -> bool:
	if health.current_health < health.max_health:
		return true
	for node: Node in get_tree().get_nodes_in_group("survivors"):
		var survivor := node as Survivor
		if survivor != null and survivor.needs_field_dressing():
			return true
	return false


# Auto-targets the densest nearby cluster, so it stays a single safe tap.
func frag_grenade() -> void:
	var target: Variant = _densest_enemy_position()
	if target == null:
		return
	_spawn_grenade_telegraph(target)


func has_grenade_target() -> bool:
	return _densest_enemy_position() != null


func _densest_enemy_position() -> Variant:
	var enemies: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy != null and global_position.distance_to(enemy.global_position) <= grenade_target_range:
			enemies.append(enemy)
	if enemies.is_empty():
		return null
	var best := enemies[0]
	var best_count := 0
	for candidate in enemies:
		var count := 0
		for other in enemies:
			if candidate.global_position.distance_to(other.global_position) <= grenade_radius:
				count += 1
		if count > best_count:
			best = candidate
			best_count = count
	return best.global_position


func _spawn_grenade_telegraph(target_position: Vector3) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = grenade_radius
	mesh.bottom_radius = grenade_radius
	mesh.height = 0.03
	disc.mesh = mesh
	get_tree().current_scene.add_child(disc)
	disc.global_position = target_position + Vector3(0.0, 0.08, 0.0)
	disc.scale = Vector3(0.1, 1.0, 0.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.35, 0.05, 0.55)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.18, 0.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = material
	var tween := disc.create_tween()
	tween.tween_property(disc, "scale", Vector3.ONE, grenade_fuse)
	tween.tween_callback(_explode_grenade.bind(target_position, grenade_radius, grenade_damage, disc, true))


func _explode_grenade(center: Vector3, radius: float, damage: int, disc: MeshInstance3D, allow_clusters: bool) -> void:
	if is_instance_valid(disc):
		disc.queue_free()
	for node in get_tree().get_nodes_in_group("zombies"):
		var enemy := node as Enemy
		if enemy != null and enemy.global_position.distance_to(center) <= radius:
			enemy.take_damage(damage)
	_spawn_explosion_ring(center, radius, Color(1.0, 0.5, 0.08))
	if not allow_clusters:
		return
	for i in range(grenade_cluster_count):
		var angle := TAU * float(i) / float(max(1, grenade_cluster_count))
		var child_center := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		get_tree().create_timer(0.18).timeout.connect(
			_explode_grenade.bind(child_center, radius * 0.55, int(damage * 0.45), null, false)
		)


func _spawn_explosion_ring(center: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.04
	ring.mesh = mesh
	get_tree().current_scene.add_child(ring)
	ring.global_position = center + Vector3(0.0, 0.1, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	ring.material_override = material
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.22)
	tween.tween_callback(ring.queue_free)

#endregion


# Called externally (by a zombie's attacked_player signal, wired up by
# ZombieSpawner) to damage the player. Ignores damage entirely during the
# post-hit invulnerability window -- this is what stops a swarm of
# zombies from all landing a hit in the same instant.
func take_damage(amount: int) -> void:
	if _invulnerable_timer > 0.0:
		return

	var reduced := int(amount * (1.0 - damage_reduction_percent))
	health.take_damage(max(1, reduced)) # always at least 1 damage gets through, even at high reduction
	_invulnerable_timer = invulnerability_duration


func add_currency(amount: int) -> int:
	var awarded := int(amount * currency_gain_multiplier)
	currency += awarded
	_update_currency_label()
	return awarded


# Called by shop nodes to spend currency. Returns true if the player could
# afford it (and the cost was deducted), false otherwise.
func try_spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	currency -= amount
	_update_currency_label()
	return true


func _on_health_changed(_current: int, _max_hp: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if _hud_label:
		_hud_label.text = "%d / %d" % [health.current_health, health.max_health]
	if _health_bar:
		_health_bar.max_value = health.max_health
		_health_bar.value = health.current_health


func _update_currency_label() -> void:
	if _currency_label:
		_currency_label.text = "◆  %d" % currency


func record_upgrade(type: Upgrades.Type) -> void:
	_upgrade_counts[type] = int(_upgrade_counts.get(type, 0)) + 1
	_update_build_label()


func get_upgrade_count(type: Upgrades.Type) -> int:
	return int(_upgrade_counts.get(type, 0))


func _update_build_label() -> void:
	if _build_label == null:
		return
	if _upgrade_counts.is_empty():
		_build_label.visible = false
		return
	var parts: PackedStringArray = []
	for type in _upgrade_counts:
		var count := int(_upgrade_counts[type])
		parts.append("%s%s" % [Upgrades.short_name(type as Upgrades.Type), " x%d" % count if count > 1 else ""])
	_build_label.text = "BUILD  •  " + "  •  ".join(parts)
	_build_label.visible = true


func _on_died() -> void:
	if _hud_label:
		_hud_label.text = "YOU DIED"
	set_physics_process(false)
	set_process(false)


func _on_location_updated(_lat: float, _lon: float) -> void:
	var new_position := _gps.get_local_position()

	var move_dir := new_position - _last_position
	if move_dir.length_squared() > 0.0001:
		look_at(global_position + move_dir, Vector3.UP)
		_movement_animation_timer = 0.2
		if _visual != null:
			_visual.play_clip("Walk_Gun")

	_last_position = new_position
	global_position = new_position
