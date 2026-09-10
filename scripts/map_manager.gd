class_name MapManager
extends Node3D

# The coordinator: listens for GPS updates, decides when the player has
# moved far enough to need fresh map data, fetches it, and hands parsed
# features to MapBuilder to render.

@export var gps_manager_path: NodePath
@export var overpass_client_path: NodePath
@export var map_builder_path: NodePath

# How far out (in meters) to request data around the player each fetch.
@export var fetch_radius_meters := 500.0

# How far the player must move from the last fetch point before we fetch
# again. Keep this comfortably smaller than fetch_radius_meters so you
# never walk off the edge of loaded data.
@export var refetch_trigger_meters := 150.0

var _gps: GPSManager
var _overpass: OverpassClient
var _builder: MapBuilder

var _last_fetch_lat := 0.0
var _last_fetch_lon := 0.0
var _has_fetched := false


func _ready() -> void:
	_gps = get_node(gps_manager_path)
	_overpass = get_node(overpass_client_path)
	_builder = get_node(map_builder_path)

	_overpass.features_loaded.connect(_on_features_loaded)
	_overpass.fetch_failed.connect(_on_fetch_failed)
	_gps.location_updated.connect(_on_location_updated)


func _on_location_updated(lat: float, lon: float) -> void:
	var needs_fetch := not _has_fetched \
		or GeoMath.haversine_distance_meters(lat, lon, _last_fetch_lat, _last_fetch_lon) > refetch_trigger_meters

	if needs_fetch:
		_fetch_around(lat, lon)


func _fetch_around(lat: float, lon: float) -> void:
	# Rough meters-to-degrees conversion -- accurate enough at city-block
	# scale, which is all we need here.
	var meters_per_degree_lat := 111320.0
	var meters_per_degree_lon := 111320.0 * cos(deg_to_rad(lat))

	var d_lat := fetch_radius_meters / meters_per_degree_lat
	var d_lon := fetch_radius_meters / meters_per_degree_lon

	var south := lat - d_lat
	var north := lat + d_lat
	var west := lon - d_lon
	var east := lon + d_lon

	_last_fetch_lat = lat
	_last_fetch_lon = lon
	_has_fetched = true

	print("[MapManager] Fetching map data around (%.5f, %.5f)" % [lat, lon])
	_overpass.fetch_area(south, west, north, east)


func _on_features_loaded() -> void:
	_builder.build_features(_overpass.last_features)


func _on_fetch_failed(reason: String) -> void:
	push_error("[MapManager] Fetch failed: %s" % reason)
