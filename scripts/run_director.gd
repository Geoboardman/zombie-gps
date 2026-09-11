class_name RunDirector
extends Node

## Authors the first few minutes of a run so every session begins with a clear
## promise, an attainable destination, and a chain of escalating payoffs.

signal opening_completed
signal heat_changed(value: float)

enum Stage { WAITING_FOR_MAP, FIRST_OUTBREAK, CHOOSE_UPGRADE, SUPPLY, SURVIVOR, BOSS, COMPLETE }

@export var player_path: NodePath
@export var gps_manager_path: NodePath
@export var overpass_client_path: NodePath
@export var objective_title_path: NodePath
@export var objective_detail_path: NodePath
@export var toast_label_path: NodePath
@export var upgrade_choice_path: NodePath
@export var boss_action_button_path: NodePath
@export var starter_zombie_scene: PackedScene
@export var supply_cache_scene: PackedScene
@export var survivor_node_scene: PackedScene
@export var boss_altar_scene: PackedScene

@export_group("Guided Distances")
@export var starter_distance := 6.0
@export var supply_distance := 18.0
@export var survivor_distance := 28.0
@export var boss_distance := 48.0

@export_group("Heat")
@export var meters_per_heat := 30.0
@export var kill_heat := 0.35

var stage := Stage.WAITING_FOR_MAP
var heat := 0.0

var _player: PlayerController
var _gps: GPSManager
var _objective_title: Label
var _objective_detail: Label
var _toast_label: Label
var _upgrade_choice: UpgradeChoiceUI
var _boss_action_button: Button
var _active_altar: BossAltarNode
var _active_target: Node3D
var _last_heat_position := Vector3.ZERO
var _map_started := false
var _toast_tween: Tween


func _ready() -> void:
	_player = get_node(player_path)
	_gps = get_node(gps_manager_path)
	_objective_title = get_node(objective_title_path)
	_objective_detail = get_node(objective_detail_path)
	_toast_label = get_node(toast_label_path)
	_upgrade_choice = get_node(upgrade_choice_path)
	_boss_action_button = get_node(boss_action_button_path)
	_boss_action_button.visible = false
	_boss_action_button.pressed.connect(_on_boss_action_pressed)
	_last_heat_position = _player.global_position

	var overpass := get_node(overpass_client_path) as OverpassClient
	overpass.features_loaded.connect(_on_map_ready)
	overpass.fetch_failed.connect(_on_map_failed)
	_gps.location_updated.connect(_on_location_updated)
	_upgrade_choice.upgrade_chosen.connect(_on_starter_upgrade_chosen)

	_set_objective("SCANNING THE OUTBREAK", "Loading the streets around you…")
	# Network latency must never own the opening hook. If map data is not back
	# quickly, start on the ground plane and let the streets appear afterward.
	get_tree().create_timer(2.0).timeout.connect(_on_opening_timeout)


func _process(_delta: float) -> void:
	if _active_target == null or not is_instance_valid(_active_target):
		return
	var distance := _player.global_position.distance_to(_active_target.global_position)
	_objective_detail.text = "%s  •  %dm" % [_detail_for_stage(), int(ceil(distance))]


func register_enemy_defeated() -> void:
	_add_heat(kill_heat)


func get_heat() -> float:
	return heat


func _on_map_ready() -> void:
	if _map_started:
		return
	_map_started = true
	_start_opening()


func _on_map_failed(_reason: String) -> void:
	if _map_started:
		return
	_map_started = true
	_toast("Map data unavailable — the run can still continue")
	_start_opening()


func _on_opening_timeout() -> void:
	if _map_started:
		return
	_map_started = true
	_toast("SIGNAL ACQUIRED — MAP STILL LOADING")
	_start_opening()


func _start_opening() -> void:
	stage = Stage.FIRST_OUTBREAK
	_toast("OUTBREAK DETECTED")
	_play_outbreak_pulse()
	var zombie := starter_zombie_scene.instantiate() as Zombie
	zombie.max_health = 15
	zombie.currency_reward = 15
	zombie.detection_radius = starter_distance + 2.0
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = _point_ahead(starter_distance)
	zombie.target = _player
	zombie.attacked_player.connect(_player.take_damage)
	zombie.died.connect(_on_starter_zombie_defeated)
	_active_target = zombie
	_set_objective("MOVE TO THE OUTBREAK", _detail_for_stage())


func _on_starter_zombie_defeated() -> void:
	if stage != Stage.FIRST_OUTBREAK:
		return
	stage = Stage.CHOOSE_UPGRADE
	_active_target = null
	_player.add_currency(15)
	register_enemy_defeated()
	_set_objective("FIRST THREAT CLEARED", "Choose your first advantage")
	_toast("THREAT CLEARED  •  +15 GOLD")
	_upgrade_choice.show_choices(_player, [
		Upgrades.Type.ATTACK_DAMAGE,
		Upgrades.Type.ATTACK_SPEED,
		Upgrades.Type.MAX_HEALTH,
	])


func _on_starter_upgrade_chosen(_type: Upgrades.Type) -> void:
	stage = Stage.SUPPLY
	opening_completed.emit()
	var cache := supply_cache_scene.instantiate() as SupplyCacheNode
	get_tree().current_scene.add_child(cache)
	cache.global_position = _point_ahead(supply_distance)
	cache.collected.connect(_on_supply_collected)
	_active_target = cache
	_set_objective("SUPPLY SIGNAL", _detail_for_stage())
	_toast("SUPPLY CACHE LOCATED")


func _on_supply_collected() -> void:
	if stage != Stage.SUPPLY:
		return
	stage = Stage.SURVIVOR
	_add_heat(1.0)
	var survivor_node := survivor_node_scene.instantiate() as SurvivorNode
	get_tree().current_scene.add_child(survivor_node)
	survivor_node.global_position = _point_ahead(survivor_distance)
	survivor_node.recruited.connect(_on_survivor_recruited)
	_active_target = survivor_node
	_set_objective("SURVIVOR DISTRESS SIGNAL", _detail_for_stage())
	_toast("A SURVIVOR NEEDS HELP")


func _on_survivor_recruited(_survivor: Survivor) -> void:
	if stage != Stage.SURVIVOR:
		return
	stage = Stage.BOSS
	_add_heat(2.0)
	var altar := boss_altar_scene.instantiate() as BossAltarNode
	get_tree().current_scene.add_child(altar)
	altar.global_position = _point_ahead(boss_distance)
	altar.boss_fight_requested.connect(_on_boss_requested)
	altar.boss_defeated.connect(_on_boss_defeated)
	altar.interaction_available.connect(_on_boss_interaction_available)
	_active_target = altar
	_set_objective("OUTBREAK SOURCE REVEALED", _detail_for_stage())
	_toast("BOSS SIGNAL REVEALED")


func _on_boss_requested() -> void:
	_boss_action_button.visible = false
	_active_altar = null
	_active_target = null
	_set_objective("DEFEAT THE OUTBREAK BOSS", "Watch the ground and evade its slam")


func _on_boss_defeated() -> void:
	stage = Stage.COMPLETE
	_add_heat(3.0)
	_active_target = null
	_set_objective("DISTRICT CLEARED", "Bank the run or continue deeper")


func _on_boss_interaction_available(altar: BossAltarNode, available: bool) -> void:
	_active_altar = altar if available else null
	_boss_action_button.visible = available


func _on_boss_action_pressed() -> void:
	if _active_altar != null and is_instance_valid(_active_altar):
		_active_altar.summon_boss()


func _on_location_updated(_lat: float, _lon: float) -> void:
	var current := _gps.get_local_position()
	var traveled := current.distance_to(_last_heat_position)
	if traveled >= meters_per_heat:
		_add_heat(traveled / meters_per_heat)
		_last_heat_position = current


func _add_heat(amount: float) -> void:
	heat += max(0.0, amount)
	heat_changed.emit(heat)


func _point_ahead(distance: float) -> Vector3:
	# Keep the guided chain on one readable bearing during desktop testing.
	# Later this can choose a safe pedestrian OSM way instead.
	return _player.global_position + Vector3(distance * 0.55, 0.0, -distance * 0.835)


func _detail_for_stage() -> String:
	match stage:
		Stage.FIRST_OUTBREAK:
			return "Close the distance — your survivor fires automatically"
		Stage.SUPPLY:
			return "Reach the cache"
		Stage.SURVIVOR:
			return "Reach the distress signal"
		Stage.BOSS:
			return "Prepare, then summon the boss"
		_:
			return ""


func _set_objective(title: String, detail: String) -> void:
	_objective_title.text = title
	_objective_detail.text = detail


func _toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func _play_outbreak_pulse() -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.025
	ring.mesh = mesh
	ring.global_position = _player.global_position + Vector3(0.0, 0.08, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.9, 0.85, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	ring.material_override = material
	get_tree().current_scene.add_child(ring)

	ring.scale = Vector3(0.2, 1.0, 0.2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(14.0, 1.0, 14.0), 1.1)
	tween.tween_property(material, "albedo_color", Color(0.1, 0.9, 0.85, 0.0), 1.1)
	tween.chain().tween_callback(ring.queue_free)
