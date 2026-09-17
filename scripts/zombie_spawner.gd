class_name ZombieSpawner
extends Node3D

# Spawns an initial batch of zombies around the player at scene start,
# THEN keeps spawning escalating waves for as long as the run continues --
# this is the RoR2-style "heat" mechanic: the longer you survive, the more
# (and eventually, the more dangerous) comes at you. Without this, there's
# nothing pulling the player anywhere and the world goes quiet the moment
# the first wave is dead -- both real problems this fixes at once.

@export var player_path: NodePath
@export var zombie_scenes: Array[PackedScene] = [] # spawner picks one at random per spawn
@export var spawn_count := 5
@export var spawn_radius_min := 12.0 # widened from 8 -- keeps zombies from all detecting the player at once on spawn
@export var spawn_radius_max := 30.0

@export_group("Escalation (Heat)")
@export var wave_interval_start := 25.0 # seconds between waves at the start of a run
@export var wave_interval_min := 10.0 # waves never come faster than this, no matter how long you survive
@export var wave_size_start := 2
@export var max_alive_zombies := 20 # hard cap so a long run doesn't spiral into unplayable zombie soup

@export_group("Run Director")
@export var run_director_path: NodePath
@export var interval_shrink_per_heat := 1.5
@export var heat_per_extra_zombie := 3.0

# Optional: if set, the spawner waits for the map's first successful fetch
# before spawning anything, so zombies don't appear in an empty gray void
# while the (asynchronous, network-dependent) map data is still loading.
@export var overpass_client_path: NodePath

var _player: PlayerController
var _has_spawned := false
var _elapsed_time := 0.0
var _wave_timer := 0.0
var _map_ready := false
var _opening_ready := false
var _director: RunDirector
var _district := 1
var _run_seed := 0
var _rng := RandomNumberGenerator.new()

enum DistrictModifier { STANDARD, RUNNER_SURGE, BRUTE_TERRITORY, SWARM }
var _district_modifier := DistrictModifier.STANDARD


func configure_run(seed_value: int) -> void:
	_run_seed = seed_value
	_rng.seed = seed_value


func begin_district(value: int) -> void:
	_district = max(1, value)
	_district_modifier = modifier_for_district(_district, _run_seed)
	# Make the district change felt immediately instead of waiting through a
	# full old wave timer. This is still capped by max_alive_zombies.
	_wave_timer = min(_wave_timer, 4.0)


static func modifier_for_district(value: int, run_seed := 0) -> DistrictModifier:
	if value <= 1:
		return DistrictModifier.STANDARD
	var district_rng := RandomNumberGenerator.new()
	district_rng.seed = run_seed ^ (value * 104729)
	return DistrictModifier.values()[district_rng.randi_range(1, DistrictModifier.values().size() - 1)] as DistrictModifier


static func modifier_name_for_district(value: int, run_seed := 0) -> String:
	match modifier_for_district(value, run_seed):
		DistrictModifier.RUNNER_SURGE:
			return "RUNNER SURGE"
		DistrictModifier.BRUTE_TERRITORY:
			return "BRUTE TERRITORY"
		DistrictModifier.SWARM:
			return "THE HORDE"
		_:
			return "FIRST OUTBREAK"


static func modifier_description_for_district(value: int, run_seed := 0) -> String:
	match modifier_for_district(value, run_seed):
		DistrictModifier.RUNNER_SURGE:
			return "Fast zombies dominate incoming waves"
		DistrictModifier.BRUTE_TERRITORY:
			return "Heavy zombies appear much more often"
		DistrictModifier.SWARM:
			return "Each wave contains extra infected"
		_:
			return "Standard infected activity"


func _ready() -> void:
	_player = get_node(player_path)
	if run_director_path != NodePath(""):
		_director = get_node(run_director_path) as RunDirector
		_director.opening_completed.connect(_on_opening_completed)
	else:
		_opening_ready = true

	if overpass_client_path != NodePath(""):
		var overpass := get_node(overpass_client_path) as OverpassClient
		overpass.features_loaded.connect(_on_map_ready)
		overpass.fetch_failed.connect(_on_map_fetch_failed)
	else:
		_map_ready = true
		_try_begin_waves()


func _process(delta: float) -> void:
	if not _has_spawned:
		return

	_elapsed_time += delta
	_wave_timer -= delta

	if _wave_timer <= 0.0:
		_spawn_wave()
		_wave_timer = _current_wave_interval()


func _current_wave_interval() -> float:
	var current_heat := _director.get_heat() if _director != null else _elapsed_time / 60.0
	return max(wave_interval_min, wave_interval_start - current_heat * interval_shrink_per_heat)


func _current_wave_size() -> int:
	var current_heat := _director.get_heat() if _director != null else _elapsed_time / 60.0
	var modifier_bonus := 2 if _district_modifier == DistrictModifier.SWARM else 0
	return wave_size_start + int(floor(current_heat / heat_per_extra_zombie)) + modifier_bonus


func _on_map_ready() -> void:
	_map_ready = true
	_try_begin_waves()


func _on_map_fetch_failed(reason: String) -> void:
	if _has_spawned:
		return
	# Don't block zombie spawning forever just because the map fetch
	# failed (e.g. the public Overpass instance rate-limited us) --
	# zombies are positioned relative to the player, not the map, so
	# there's nothing they actually need the map data for.
	push_warning("[ZombieSpawner] Map fetch failed (%s) -- spawning zombies anyway" % reason)
	_map_ready = true
	_try_begin_waves()


func _on_opening_completed() -> void:
	_opening_ready = true
	_try_begin_waves()


func _try_begin_waves() -> void:
	if _has_spawned or not _map_ready or not _opening_ready:
		return
	_has_spawned = true
	_spawn_initial()


func _spawn_initial() -> void:
	_spawn_group(spawn_count, _player.global_position)

	_wave_timer = wave_interval_start


func _spawn_wave() -> void:
	var alive := get_tree().get_nodes_in_group("zombies").size()
	if alive >= max_alive_zombies:
		print("[ZombieSpawner] At zombie cap (%d) -- skipping this wave" % max_alive_zombies)
		return

	var count: int = min(_current_wave_size(), max_alive_zombies - alive)
	print("[ZombieSpawner] Wave incoming: %d zombies (t=%.0fs)" % [count, _elapsed_time])

	_spawn_group(count, _player.global_position)


func _spawn_group(count: int, center: Vector3) -> void:
	if count <= 0:
		return
	var base_angle := _rng.randf() * TAU
	var angle_step := TAU / float(count)
	for index in range(count):
		# Even sectors prevent one random wave from appearing as a single pile.
		# Small jitter keeps the distribution organic rather than perfectly radial.
		var jitter := _rng.randf_range(-angle_step * 0.18, angle_step * 0.18)
		_spawn_zombie_near(center, base_angle + angle_step * float(index) + jitter)


func _spawn_zombie_near(center: Vector3, angle: float) -> void:
	if zombie_scenes.is_empty():
		push_error("[ZombieSpawner] No zombie_scenes assigned")
		return

	var scene := _pick_scene_for_district()

	var radius := _rng.randf_range(spawn_radius_min, spawn_radius_max)
	var spawn_pos := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

	var zombie: Zombie = scene.instantiate()
	add_child(zombie)
	zombie.global_position = spawn_pos
	zombie.target = _player
	zombie.attacked_player.connect(_player.take_damage)
	zombie.died.connect(func():
		_player.add_currency(zombie.currency_reward)
		if _director != null:
			_director.register_enemy_defeated()
	)


func _pick_scene_for_district() -> PackedScene:
	# Main wires scenes as basic, runner, brute. Fall back to the full pool if a
	# variant is absent so custom test scenes remain safe.
	if _district_modifier == DistrictModifier.RUNNER_SURGE and zombie_scenes.size() >= 2 and _rng.randf() < 0.7:
		return zombie_scenes[1]
	if _district_modifier == DistrictModifier.BRUTE_TERRITORY and zombie_scenes.size() >= 3 and _rng.randf() < 0.55:
		return zombie_scenes[2]
	return zombie_scenes[_rng.randi_range(0, zombie_scenes.size() - 1)]
