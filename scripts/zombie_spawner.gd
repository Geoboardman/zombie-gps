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
	return wave_size_start + int(floor(current_heat / heat_per_extra_zombie))


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
	for i in range(spawn_count):
		_spawn_zombie_near(_player.global_position)

	_wave_timer = wave_interval_start


func _spawn_wave() -> void:
	var alive := get_tree().get_nodes_in_group("zombies").size()
	if alive >= max_alive_zombies:
		print("[ZombieSpawner] At zombie cap (%d) -- skipping this wave" % max_alive_zombies)
		return

	var count: int = min(_current_wave_size(), max_alive_zombies - alive)
	print("[ZombieSpawner] Wave incoming: %d zombies (t=%.0fs)" % [count, _elapsed_time])

	for i in range(count):
		_spawn_zombie_near(_player.global_position)


func _spawn_zombie_near(center: Vector3) -> void:
	if zombie_scenes.is_empty():
		push_error("[ZombieSpawner] No zombie_scenes assigned")
		return

	var scene := zombie_scenes[randi() % zombie_scenes.size()]

	var angle := randf() * TAU
	var radius := randf_range(spawn_radius_min, spawn_radius_max)
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
