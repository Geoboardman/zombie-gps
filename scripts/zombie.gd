class_name Zombie
extends Enemy

# Wander/chase/attack state machine. Zombies wander within a radius of
# where they spawned (not real streets -- see earlier design notes on why
# that's the simpler, cheaper-to-build choice), notice the player once in
# range, chase, and attack on contact. Purely primitive-driven -- no
# imported model or animation required to prove this out.

enum State { WANDER, CHASE, ATTACK, RETURN_HOME }

@export var wander_radius := 8.0
@export var detection_radius := 12.0
@export var lose_interest_radius := 18.0 # give up the chase if the player gets this far away
@export var attack_range := 1.5
@export var wander_speed := 0.6 # slow shuffle
@export var chase_speed := 1.8 # roughly a light jog -- tense but outrunnable at a real jog
@export var attack_cooldown := 1.0
@export var attack_damage := 10
@export var max_health := 50
@export var currency_reward := 10

@export_group("Awareness")
@export var noise_alert_duration := 4.0

@export_group("Crowd Spacing")
@export var separation_radius := 1.25
@export var separation_strength := 1.15

signal attacked_player(damage: int) # hook point for the player's health system
signal died # emitted when health reaches zero, before this zombie frees itself

var target: Node3D # set by ZombieSpawner at spawn time

var _state: State = State.WANDER
var _spawn_position: Vector3
var _wander_target: Vector3
var _attack_timer := 0.0
var _noise_alert_timer := 0.0
var _knockback_recovery_timer := 0.0 # briefly locks out chase/attack right after a knockback
var _knockback_active := false # true only while the knockback tween is actively animating position
var _mesh_material: StandardMaterial3D
var _health_bar: HealthBar3D
var _visual: CharacterVisual


func _ready() -> void:
	_spawn_position = global_position
	_pick_new_wander_target()

	add_to_group("zombies")

	health = Health.new(max_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	# Duplicate the mesh's material so flashing THIS zombie doesn't flash
	# every zombie -- by default, instances of the same scene share their
	# material resource unless you split it off per-instance like this.
	var mesh_instance := get_node("MeshInstance3D") as MeshInstance3D
	var shared_material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	_mesh_material = shared_material.duplicate()
	mesh_instance.set_surface_override_material(0, _mesh_material)

	_health_bar = get_node("HealthBar") as HealthBar3D
	_health_bar.set_fraction(1.0)
	_visual = get_node_or_null("VisualRoot") as CharacterVisual
	_play_state_animation()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	if _visual != null:
		_visual.set_animation_speed(get_speed_multiplier())
	if get_speed_multiplier() <= 0.01:
		velocity = Vector3.ZERO
		return

	if _knockback_active:
		return # let the tween own position exclusively -- don't fight it with move_and_slide
	_noise_alert_timer = maxf(0.0, _noise_alert_timer - delta)

	if _knockback_recovery_timer > 0.0:
		_knockback_recovery_timer -= delta
		_move_toward(_wander_target, wander_speed, delta)
		return

	var distance_to_target := global_position.distance_to(target.global_position)

	match _state:
		State.WANDER:
			_process_wander(delta, distance_to_target)
		State.CHASE:
			_process_chase(delta, distance_to_target)
		State.ATTACK:
			_process_attack(delta, distance_to_target)
		State.RETURN_HOME:
			_process_return_home(delta, distance_to_target)


func _process_wander(delta: float, distance_to_target: float) -> void:
	if distance_to_target < detection_radius:
		_set_state(State.CHASE)
		return

	if global_position.distance_to(_wander_target) < 0.5:
		_pick_new_wander_target()

	_move_toward(_wander_target, wander_speed, delta)


func _process_chase(delta: float, distance_to_target: float) -> void:
	if distance_to_target > lose_interest_radius and _noise_alert_timer <= 0.0:
		_set_state(State.RETURN_HOME)
		return

	if distance_to_target < attack_range:
		_set_state(State.ATTACK)
		_attack_timer = 0.0
		return

	_move_toward(target.global_position, chase_speed, delta)


func _process_return_home(delta: float, distance_to_target: float) -> void:
	if distance_to_target < detection_radius:
		_set_state(State.CHASE)
		return
	if global_position.distance_to(_spawn_position) <= 0.75:
		_set_state(State.WANDER)
		_pick_new_wander_target()
		return
	_move_toward(_spawn_position, wander_speed, delta)


func hear_noise(source_position: Vector3, noise_radius: float) -> void:
	if noise_radius <= 0.0 or global_position.distance_to(source_position) > noise_radius:
		return
	_noise_alert_timer = noise_alert_duration
	_set_state(State.CHASE)


func _process_attack(delta: float, distance_to_target: float) -> void:
	if distance_to_target > attack_range * 1.2:
		_set_state(State.CHASE)
		return

	var crowd_push := _separation_vector()
	if crowd_push.length_squared() > 0.0001:
		velocity = crowd_push.normalized() * chase_speed * 0.35 * get_speed_multiplier()
		move_and_slide()
	else:
		velocity = Vector3.ZERO
	look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		if _visual != null:
			_visual.play_once("Punch", "Idle_Attack", 0.45)
		var survivor_target := _nearest_survivor_in_range(maxf(3.2, attack_range * 1.3))
		if survivor_target != null:
			survivor_target.take_damage(attack_damage)
		else:
			attacked_player.emit(attack_damage)
		_attack_timer = attack_cooldown


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


func _move_toward(destination: Vector3, speed: float, _delta: float) -> void:
	var desired := destination - global_position
	desired.y = 0.0
	if desired.length_squared() < 0.0001:
		return
	var direction := desired.normalized()
	var separation := _separation_vector()
	if separation.length_squared() > 0.0001:
		direction = (direction + separation * separation_strength).normalized()

	velocity = direction * speed * get_speed_multiplier()
	move_and_slide()

	look_at(global_position + direction, Vector3.UP)


func _separation_vector() -> Vector3:
	var separation := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group("zombies"):
		var neighbor := node as Enemy
		if neighbor == null or neighbor == self:
			continue
		var offset := global_position - neighbor.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance >= separation_radius:
			continue
		if distance < 0.01:
			var fallback_angle := deg_to_rad(float(get_instance_id() % 360))
			offset = Vector3(cos(fallback_angle), 0.0, sin(fallback_angle))
			distance = 0.01
		separation += offset.normalized() * (1.0 - distance / separation_radius)
	return separation


func _pick_new_wander_target() -> void:
	var angle := randf() * TAU
	var radius := randf() * wander_radius
	_wander_target = _spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _on_health_changed(current: int, max_hp: int) -> void:
	_health_bar.set_fraction(float(current) / float(max_hp))
	_flash_hit()
	if _visual != null:
		_visual.play_once("HitReact", _animation_for_state(), 0.25)


func _flash_hit() -> void:
	var original_color := Color(0.7, 0.15, 0.15) # matches the base zombie color
	_mesh_material.albedo_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_mesh_material, "albedo_color", original_color, 0.15)


func _on_died() -> void:
	set_physics_process(false)
	died.emit()
	var delay := _visual.play_death() if _visual != null else 0.4
	get_tree().create_timer(delay).timeout.connect(queue_free)


func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state
	_play_state_animation()


func _play_state_animation() -> void:
	if _visual != null:
		_visual.play_clip(_animation_for_state())


func _animation_for_state() -> String:
	match _state:
		State.WANDER: return "Walk"
		State.CHASE: return "Run"
		State.ATTACK: return "Idle_Attack"
		State.RETURN_HOME: return "Walk"
		_: return "Idle"


# Called externally (by the player's knockback pulse). Smoothly shoves
# this zombie back over a short duration (not an instant teleport) and
# briefly interrupts whatever it was doing, so a swarm doesn't
# immediately re-close the distance the moment the pulse ends.
func apply_knockback(direction: Vector3, force: float) -> void:
	if _knockback_active:
		return # already mid-knockback -- don't stack a second tween on top

	_set_state(State.WANDER)
	_knockback_recovery_timer = 0.75
	_pick_new_wander_target()

	_knockback_active = true
	var target_pos := global_position + direction * force
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): _knockback_active = false)
