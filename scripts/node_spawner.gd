class_name NodeSpawner
extends Node3D

# Places shop nodes and a single boss altar around the player at scene
# start -- same wait-for-map-data pattern as ZombieSpawner, for the same
# reason (don't put stuff in a void while the map's still loading).

@export var player_path: NodePath
@export var shop_node_scene: PackedScene
@export var boss_altar_scene: PackedScene
@export var survivor_node_scene: PackedScene

@export_group("Shop Placement")
@export var shop_count := 3
@export var shop_radius_min := 15.0
@export var shop_radius_max := 30.0

@export_group("Survivor Placement")
@export var survivor_count := 2
@export var survivor_radius_min := 20.0
@export var survivor_radius_max := 35.0

@export_group("Boss Altar Placement")
@export var boss_altar_radius_min := 40.0
@export var boss_altar_radius_max := 50.0
@export var boss_altar_count := 1

@export var overpass_client_path: NodePath

var _player: PlayerController
var _has_spawned := false


func _ready() -> void:
	_player = get_node(player_path)

	if overpass_client_path != NodePath(""):
		var overpass := get_node(overpass_client_path) as OverpassClient
		overpass.features_loaded.connect(_on_map_ready)
		overpass.fetch_failed.connect(_on_map_fetch_failed)
	else:
		_spawn_all()


func _on_map_ready() -> void:
	if _has_spawned:
		return
	_has_spawned = true
	_spawn_all()


func _on_map_fetch_failed(reason: String) -> void:
	if _has_spawned:
		return
	push_warning("[NodeSpawner] Map fetch failed (%s) -- spawning nodes anyway" % reason)
	_has_spawned = true
	_spawn_all()


func _spawn_all() -> void:
	for i in range(shop_count):
		_spawn_at_radius(shop_node_scene, shop_radius_min, shop_radius_max)

	for i in range(survivor_count):
		_spawn_at_radius(survivor_node_scene, survivor_radius_min, survivor_radius_max)

	for i in range(boss_altar_count):
		_spawn_at_radius(boss_altar_scene, boss_altar_radius_min, boss_altar_radius_max)


func _spawn_at_radius(scene: PackedScene, radius_min: float, radius_max: float) -> void:
	if scene == null:
		push_error("[NodeSpawner] Missing scene for a node placement")
		return

	var angle := randf() * TAU
	var radius := randf_range(radius_min, radius_max)
	var spawn_pos := _player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

	var instance := scene.instantiate()
	add_child(instance)
	instance.global_position = spawn_pos
