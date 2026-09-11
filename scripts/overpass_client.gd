class_name OverpassClient
extends HTTPRequest

# Fetches real-world map data (roads, water, buildings, landuse) from the
# public Overpass API as plain JSON -- no protobuf/vector-tile parsing
# needed. Must be added to the scene tree as a node (it extends
# HTTPRequest, which Godot requires to be part of the tree to work).
#
# Caches successful responses to disk, keyed by a coarse lat/lon grid
# cell, so re-visiting the same neighborhood -- across restarts, or as
# you walk back and forth near a boundary -- reuses saved data instead of
# hitting the network again.
#
# NOTE: the public Overpass API (overpass-api.de) is a shared, rate-limited
# community service -- great for development, but for a shipped app you'll
# want your own Overpass instance or a paid alternative (e.g. Geofabrik,
# a self-hosted Overpass server) so you're not competing with everyone
# else's requests.

signal features_loaded
signal fetch_failed(reason: String)

var last_features: Array[MapFeature] = []

const OVERPASS_URL := "https://overpass-api.de/api/interpreter"

@export var use_cache := true
@export var cache_dir := "user://map_cache/"

var _pending_cache_key := ""


func _ready() -> void:
	request_completed.connect(_on_request_completed)
	if use_cache:
		DirAccess.make_dir_recursive_absolute(cache_dir)


# Bounding box in degrees: south, west, north, east.
func fetch_area(south: float, west: float, north: float, east: float) -> void:
	var cache_key := _cache_key(south, west, north, east)

	if use_cache:
		var cached: Variant = _load_from_cache(cache_key)
		if cached != null:
			print("[OverpassClient] Cache hit for %s -- skipping network fetch" % cache_key)
			last_features = _parse_overpass_json(cached)
			features_loaded.emit()
			return

	var query := "[out:json][timeout:25];("
	query += "way[\"highway\"](%f,%f,%f,%f);" % [south, west, north, east]
	query += "way[\"natural\"=\"water\"](%f,%f,%f,%f);" % [south, west, north, east]
	query += "way[\"building\"](%f,%f,%f,%f);" % [south, west, north, east]
	query += "way[\"landuse\"](%f,%f,%f,%f);" % [south, west, north, east]
	query += ");out body;>;out skel qt;"

	var url := OVERPASS_URL + "?data=" + query.uri_encode()

	_pending_cache_key = cache_key

	var err := request(url)
	if err != OK:
		push_error("[OverpassClient] Failed to start request: %s" % err)
		fetch_failed.emit(str(err))


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var reason := "HTTP %d" % response_code
		push_error("[OverpassClient] Bad response: %s" % reason)
		fetch_failed.emit(reason)
		return

	var text := body.get_string_from_utf8()

	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		push_error("[OverpassClient] JSON parse error: %s" % parse_err)
		fetch_failed.emit("JSON parse error")
		return

	if use_cache and _pending_cache_key != "":
		_save_to_cache(_pending_cache_key, text)

	last_features = _parse_overpass_json(json.data)
	print("[OverpassClient] Parsed %d features" % last_features.size())
	features_loaded.emit()


func _cache_key(south: float, west: float, north: float, east: float) -> String:
	# Key the actual request bounds. The former coarse center-cell key could
	# return a neighboring 500m map section that did not contain the player.
	return "%.4f_%.4f_%.4f_%.4f" % [south, west, north, east]


func _cache_path(key: String) -> String:
	return cache_dir + key + ".json"


func _load_from_cache(key: String) -> Variant:
	var path := _cache_path(key)
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text := file.get_as_text()
	file.close()

	return JSON.parse_string(text)


func _save_to_cache(key: String, raw_text: String) -> void:
	var file := FileAccess.open(_cache_path(key), FileAccess.WRITE)
	if file == null:
		push_warning("[OverpassClient] Failed to write cache file for %s" % key)
		return
	file.store_string(raw_text)
	file.close()


func _parse_overpass_json(data: Dictionary) -> Array[MapFeature]:
	var features: Array[MapFeature] = []

	if not data.has("elements"):
		return features

	var elements: Array = data["elements"]

	# Pass 1: collect every node's lat/lon by its OSM id.
	var node_positions: Dictionary = {} # id (int) -> Vector2(lat, lon)
	for el in elements:
		if el.get("type") != "node":
			continue
		node_positions[el["id"]] = Vector2(el["lat"], el["lon"])

	# Pass 2: build each "way" (road, building outline, etc.) from its node list.
	for el in elements:
		if el.get("type") != "way":
			continue

		var feature := MapFeature.new()

		var tags: Dictionary = el.get("tags", {})
		feature.tags = tags
		feature.kind = _classify_feature(tags)
		feature.is_polygon = feature.kind == MapFeature.Kind.WATER \
			or feature.kind == MapFeature.Kind.BUILDING \
			or feature.kind == MapFeature.Kind.LANDUSE

		var node_refs: Array = el.get("nodes", [])
		for node_id in node_refs:
			if node_positions.has(node_id):
				var latlon: Vector2 = node_positions[node_id]
				# Packed as Vector3(lat, 0, lon) -- MapBuilder unpacks and
				# converts to real local-space meters.
				feature.points.append(Vector3(latlon.x, 0.0, latlon.y))

		if feature.points.size() >= 2:
			features.append(feature)

	return features


func _classify_feature(tags: Dictionary) -> MapFeature.Kind:
	if tags.has("highway"):
		return MapFeature.Kind.ROAD
	if tags.get("natural") == "water":
		return MapFeature.Kind.WATER
	if tags.has("building"):
		return MapFeature.Kind.BUILDING
	if tags.has("landuse"):
		return MapFeature.Kind.LANDUSE
	return MapFeature.Kind.UNKNOWN
