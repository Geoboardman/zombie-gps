class_name PlayerController
extends CharacterBody3D

# Keeps the player's visual position locked to GPSManager's reported
# location, faces movement direction, and owns the player's health,
# currency, and combat loop. Auto-attack and the damage aura are still
# fully passive. Knockback Pulse, Second Wind, and Overcharge are now
# player-triggered abilities on cooldowns instead -- single key tap each,
# no aiming or held input, so it stays glance-and-tap rather than
# something that demands sustained screen attention while walking.

@export var gps_manager_path: NodePath
@export var hud_label_path: NodePath # optional: a Label to show "HP: x/y"
@export var health_bar_path: NodePath # optional: a ProgressBar for mobile-readable health
@export var currency_label_path: NodePath # optional: a Label to show currency

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

@export_group("Ability: Knockback Pulse")
@export var knockback_cooldown := 4.0
@export var knockback_radius := 4.0
@export var knockback_force := 2.5
@export var knockback_action := "ability_1" # Input Map action -- default binding: Q

@export_group("Ability: Second Wind")
@export var second_wind_cooldown := 15.0
@export var second_wind_heal_percent := 0.25
@export var second_wind_action := "ability_2" # Input Map action -- default binding: E

@export_group("Ability: Overcharge")
@export var overcharge_cooldown := 12.0
@export var overcharge_duration := 5.0
@export var overcharge_damage_multiplier := 1.5
@export var overcharge_interval_multiplier := 0.7 # lower = faster attacks
@export var overcharge_action := "ability_3" # Input Map action -- default binding: R

var health: Health
var currency := 0
var currency_gain_multiplier := 1.0

var _gps: GPSManager
var _last_position: Vector3
var _attack_timer := 0.0
var _aura_timer: float
var _invulnerable_timer := 0.0
var _regen_accumulator := 0.0 # fractional HP banked here until it crosses a whole point
var _ability_cooldowns: Dictionary = {} # Abilities.Type -> float remaining
var _hud_label: Label
var _health_bar: ProgressBar
var _currency_label: Label
var _mesh_material: StandardMaterial3D

const BASE_PLAYER_COLOR := Color(0.85, 0.85, 0.88)
const KNOCKBACK_FLASH_COLOR := Color(0.3, 0.6, 0.95)
const SECOND_WIND_FLASH_COLOR := Color(0.3, 0.9, 0.4)
const OVERCHARGE_COLOR := Color(0.95, 0.55, 0.15)


func _ready() -> void:
	_gps = get_node(gps_manager_path)
	_gps.location_updated.connect(_on_location_updated)
	_last_position = global_position

	health = Health.new(max_health)
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


func _process(delta: float) -> void:
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
		nearest.take_damage(attack_damage)
		_attack_timer = attack_interval
		_play_attack_lunge(nearest.global_position)

		if lifesteal_percent > 0.0:
			var heal_amount := int(attack_damage * lifesteal_percent)
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
			enemy.take_damage(aura_damage_per_tick)


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


#region Abilities

func _process_abilities(delta: float) -> void:
	for type in _ability_cooldowns.keys():
		if _ability_cooldowns[type] > 0.0:
			_ability_cooldowns[type] -= delta

	if Input.is_action_just_pressed(knockback_action):
		try_activate_ability(Abilities.Type.KNOCKBACK_PULSE)
	if Input.is_action_just_pressed(second_wind_action):
		try_activate_ability(Abilities.Type.SECOND_WIND)
	if Input.is_action_just_pressed(overcharge_action):
		try_activate_ability(Abilities.Type.OVERCHARGE)


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

	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	var original_scale := mesh_instance.scale
	mesh_instance.scale = original_scale * 1.25
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", original_scale, 0.15)


# Shoves back any zombie within knockback_radius and interrupts their
# chase, buying breathing room during a swarm on demand. Flashes blue
# regardless of whether any zombies were actually in range, so the
# ability always gives SOME confirmation it fired.
func knockback_pulse() -> void:
	_flash_color(KNOCKBACK_FLASH_COLOR, 0.25)

	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie == null:
			continue

		var offset := zombie.global_position - global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist > knockback_radius:
			continue

		var direction := offset.normalized() if dist > 0.0001 else Vector3.RIGHT
		zombie.apply_knockback(direction, knockback_force)


# Instant emergency heal. Flashes green so it's obvious something
# happened, not just a number ticking up on the HUD.
func second_wind() -> void:
	var heal_amount := int(health.max_health * second_wind_heal_percent)
	health.heal(heal_amount)
	_flash_color(SECOND_WIND_FLASH_COLOR, 0.4)


# Temporary offense boost. Tints the player orange for the whole
# duration -- not just a flash -- so it stays visibly obvious the buff
# is active the entire time, not just at the moment of activation.
# Reverts after overcharge_duration -- note this stores and restores
# exact values, so buying an attack upgrade WHILE overcharge is active
# will get overwritten when it reverts. A known, acceptable limitation
# for now; a proper multiplicative-buff-stack system is a later fix,
# not urgent for this pass.
func overcharge() -> void:
	var original_damage := attack_damage
	var original_interval := attack_interval

	attack_damage = int(attack_damage * overcharge_damage_multiplier)
	attack_interval = max(0.1, attack_interval * overcharge_interval_multiplier)

	if _mesh_material != null:
		_mesh_material.albedo_color = OVERCHARGE_COLOR

	get_tree().create_timer(overcharge_duration).timeout.connect(func():
		attack_damage = original_damage
		attack_interval = original_interval
		if _mesh_material != null:
			_mesh_material.albedo_color = BASE_PLAYER_COLOR
	)

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

	_last_position = new_position
	global_position = new_position
