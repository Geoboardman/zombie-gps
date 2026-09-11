class_name RunDirector
extends Node

signal opening_completed
signal heat_changed(value: float)

enum Stage { WAITING_FOR_MAP, FIRST_OUTBREAK, FIELD_KIT, CHOOSE_UPGRADE, SUPPLY, SURVIVOR, BOSS, COMPLETE }

@export var player_path: NodePath
@export var gps_manager_path: NodePath
@export var overpass_client_path: NodePath
@export var objective_title_path: NodePath
@export var objective_detail_path: NodePath
@export var toast_label_path: NodePath
@export var upgrade_choice_path: NodePath
@export var victory_screen_path: NodePath
@export var zombie_spawner_path: NodePath
@export var starter_zombie_scene: PackedScene
@export var field_kit_scene: PackedScene
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
var district := 1
var total_distance_meters := 0.0
var zombies_defeated := 0
var survivors_recruited := 0
var bosses_defeated := 0

var _player: PlayerController
var _gps: GPSManager
var _objective_title: Label
var _objective_detail: Label
var _toast_label: Label
var _upgrade_choice: UpgradeChoiceUI
var _victory_screen: BossVictoryScreen
var _zombie_spawner: ZombieSpawner
var _active_target: Node3D
var _last_heat_position := Vector3.ZERO
var _last_tracking_position := Vector3.ZERO
var _opening_started := false
var _toast_tween: Tween
var _choice_after_cache := false


func _ready() -> void:
	_player = get_node(player_path)
	_gps = get_node(gps_manager_path)
	_objective_title = get_node(objective_title_path)
	_objective_detail = get_node(objective_detail_path)
	_toast_label = get_node(toast_label_path)
	_upgrade_choice = get_node(upgrade_choice_path)
	_victory_screen = get_node(victory_screen_path)
	_zombie_spawner = get_node(zombie_spawner_path)
	_zombie_spawner.begin_district(district)
	_last_heat_position = _player.global_position
	_last_tracking_position = _player.global_position

	var overpass := get_node(overpass_client_path) as OverpassClient
	overpass.features_loaded.connect(_on_map_ready)
	overpass.fetch_failed.connect(_on_map_failed)
	_gps.location_updated.connect(_on_location_updated)
	_upgrade_choice.upgrade_chosen.connect(_on_upgrade_chosen)
	_victory_screen.push_deeper_requested.connect(_on_push_deeper_requested)
	_victory_screen.extract_requested.connect(_on_extract_requested)

	_set_objective("SCANNING THE OUTBREAK", "Loading the streets around you…")
	get_tree().create_timer(2.0).timeout.connect(_on_opening_timeout)


func _process(_delta: float) -> void:
	if _active_target == null or not is_instance_valid(_active_target):
		return
	var distance := _player.global_position.distance_to(_active_target.global_position)
	_objective_detail.text = "%s  •  %dm" % [_detail_for_stage(), int(ceil(distance))]


func register_enemy_defeated() -> void:
	zombies_defeated += 1
	_add_heat(kill_heat)


func get_heat() -> float:
	return heat


func _on_map_ready() -> void:
	_start_opening_once()


func _on_map_failed(_reason: String) -> void:
	if not _opening_started:
		_toast("Map unavailable — the run can still continue")
	_start_opening_once()


func _on_opening_timeout() -> void:
	if not _opening_started:
		_toast("SIGNAL ACQUIRED — MAP STILL LOADING")
	_start_opening_once()


func _start_opening_once() -> void:
	if _opening_started:
		return
	_opening_started = true
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
	stage = Stage.FIELD_KIT
	var drop_position := _active_target.global_position if _active_target != null else _player.global_position
	_player.add_currency(15)
	register_enemy_defeated()
	var kit := field_kit_scene.instantiate() as FieldKitNode
	get_tree().current_scene.add_child(kit)
	kit.global_position = drop_position
	kit.opened.connect(_on_field_kit_opened)
	_active_target = kit
	_set_objective("FIELD KIT DROPPED", "Approach and tap OPEN FIELD KIT")
	_toast("THREAT CLEARED  •  +15 GOLD")


func _on_field_kit_opened() -> void:
	if stage != Stage.FIELD_KIT:
		return
	stage = Stage.CHOOSE_UPGRADE
	_choice_after_cache = false
	_active_target = null
	_set_objective("FIELD KIT RECOVERED", "Choose one piece of equipment")
	_toast("FIELD KIT RECOVERED")
	_upgrade_choice.show_choices(_player, [
		Upgrades.Type.ATTACK_DAMAGE,
		Upgrades.Type.ATTACK_SPEED,
		Upgrades.Type.MAX_HEALTH,
	])


func _on_upgrade_chosen(type: Upgrades.Type) -> void:
	if _choice_after_cache:
		_choice_after_cache = false
		_begin_survivor_stage(type)
		return
	stage = Stage.SUPPLY
	opening_completed.emit()
	_spawn_supply(supply_distance)
	_set_objective("SUPPLY SIGNAL", _detail_for_stage())
	_toast("%s EQUIPPED  •  SUPPLY CACHE LOCATED" % Upgrades.display_name(type).to_upper())


func _spawn_supply(distance: float) -> void:
	var cache := supply_cache_scene.instantiate() as SupplyCacheNode
	get_tree().current_scene.add_child(cache)
	cache.global_position = _point_ahead(distance)
	cache.collected.connect(_on_supply_collected)
	_active_target = cache


func _on_supply_collected() -> void:
	if stage != Stage.SUPPLY:
		return
	_add_heat(1.0)
	stage = Stage.CHOOSE_UPGRADE
	_choice_after_cache = true
	_active_target = null
	_set_objective("CACHE EQUIPMENT FOUND", "Choose one upgrade before moving on")
	_toast("CACHE SEARCHED  •  +35 GOLD  •  EQUIPMENT FOUND")
	_upgrade_choice.show_choices(_player, Upgrades.random_choices(3), "SUPPLY CACHE — CHOOSE ONE")


func _begin_survivor_stage(chosen_type: Upgrades.Type) -> void:
	stage = Stage.SURVIVOR
	var survivor_node := survivor_node_scene.instantiate() as SurvivorNode
	get_tree().current_scene.add_child(survivor_node)
	survivor_node.global_position = _point_ahead(survivor_distance + float(district - 1) * 10.0)
	survivor_node.recruited.connect(_on_survivor_recruited)
	_active_target = survivor_node
	_set_objective("SURVIVOR DISTRESS SIGNAL", _detail_for_stage())
	_toast("%s EQUIPPED  •  SURVIVOR SIGNAL FOUND" % Upgrades.display_name(chosen_type).to_upper())


func _on_survivor_recruited(survivor: Survivor) -> void:
	if stage != Stage.SURVIVOR:
		return
	stage = Stage.BOSS
	survivors_recruited += 1
	_add_heat(2.0)
	var altar := boss_altar_scene.instantiate() as BossAltarNode
	altar.district = district
	get_tree().current_scene.add_child(altar)
	altar.global_position = _point_ahead(boss_distance + float(district - 1) * 15.0)
	altar.boss_fight_requested.connect(_on_boss_requested)
	altar.boss_defeated.connect(_on_boss_defeated)
	_active_target = altar
	_set_objective("DISTRICT %d BOSS REVEALED" % district, _detail_for_stage())
	_toast("%s RECRUITED  •  BOSS SIGNAL REVEALED" % Survivor.name_for_kind(survivor.kind).to_upper())


func _on_boss_requested() -> void:
	_active_target = null
	_set_objective("DEFEAT THE DISTRICT %d BOSS" % district, "Watch the ground and evade its slam")


func _on_boss_defeated(reward_awarded: int) -> void:
	stage = Stage.COMPLETE
	bosses_defeated += 1
	_add_heat(3.0)
	_active_target = null
	_set_objective("DISTRICT %d CLEARED" % district, "Extract safely or push deeper")
	var next_district := district + 1
	_victory_screen.show_victory(
		reward_awarded,
		_player.currency,
		district,
		ZombieSpawner.modifier_name_for_district(next_district),
		ZombieSpawner.modifier_description_for_district(next_district),
		25,
	)


func _on_push_deeper_requested() -> void:
	district += 1
	stage = Stage.SUPPLY
	_player.health.heal(int(_player.health.max_health * 0.25))
	_player.currency_gain_multiplier += 0.25
	_zombie_spawner.begin_district(district)
	_add_heat(2.0 + district)
	_spawn_supply(supply_distance + float(district - 1) * 15.0)
	_set_objective(
		"DISTRICT %d — %s" % [district, ZombieSpawner.modifier_name_for_district(district)],
		"%s • All gold rewards +25%%" % ZombieSpawner.modifier_description_for_district(district)
	)
	_toast("%s  •  GOLD REWARDS INCREASED" % ZombieSpawner.modifier_name_for_district(district))


func _on_extract_requested() -> void:
	var profile := RunProfile.record_extraction(_player.currency, district)
	_victory_screen.show_extraction_summary(
		"DISTRICT REACHED: %d\nDISTANCE: %dm\nZOMBIES DEFEATED: %d\nSURVIVORS RECRUITED: %d\nBOSSES DEFEATED: %d\nGOLD BANKED: %d\n\nCAREER GOLD: %d  •  BEST DISTRICT: %d" % [
			district, int(total_distance_meters), zombies_defeated,
			survivors_recruited, bosses_defeated, _player.currency,
			int(profile["total_extracted_gold"]), int(profile["best_district"]),
		]
	)


func _on_location_updated(_lat: float, _lon: float) -> void:
	var current := _gps.get_local_position()
	var segment := current.distance_to(_last_tracking_position)
	if segment < 100.0:
		total_distance_meters += segment
	_last_tracking_position = current

	var traveled := current.distance_to(_last_heat_position)
	if traveled >= meters_per_heat:
		_add_heat(traveled / meters_per_heat)
		_last_heat_position = current


func _add_heat(amount: float) -> void:
	heat += max(0.0, amount)
	heat_changed.emit(heat)


func _point_ahead(distance: float) -> Vector3:
	return _player.global_position + Vector3(distance * 0.55, 0.0, -distance * 0.835)


func _detail_for_stage() -> String:
	match stage:
		Stage.FIRST_OUTBREAK:
			return "Close the distance — your survivor fires automatically"
		Stage.FIELD_KIT:
			return "Open the dropped field kit"
		Stage.SUPPLY:
			return "Reach and search the cache"
		Stage.SURVIVOR:
			return "Reach and recruit the survivor"
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
