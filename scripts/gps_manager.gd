class_name GPSManager
extends Node

# Central source of truth for "where is the player, in the real world."
# In the editor / on desktop, WASD drives a fake lat/lon so you can test
# the whole loop without leaving your desk. On a real device, swap
# _handle_mock_movement() for a callback from a native geolocation plugin
# that calls report_location() directly with real GPS fixes.

signal location_updated(lat: float, lon: float)

@export var use_mock_location := true

# Starting point for mock mode. Swap these for your own coordinates.
@export var mock_start_lat := 47.6740 # Redmond, WA area
@export var mock_start_lon := -122.1215

@export var mock_move_speed_mps := 1.4 # roughly a real walking pace (~5 km/h / 3.1 mph)
@export var mock_jog_speed_mps := 2.8 # hold Shift to move at this pace instead -- roughly a light jog

var current_lat: float
var current_lon: float
var origin_lat: float
var origin_lon: float


func _ready() -> void:
	current_lat = mock_start_lat
	current_lon = mock_start_lon
	origin_lat = mock_start_lat
	origin_lon = mock_start_lon

	# Deferred so every other node's _ready() (which connects to this
	# signal) has already run before we fire the very first update --
	# otherwise this initial emission fires before anyone is listening,
	# and nothing happens on launch until the player first moves.
	call_deferred("_emit_initial_location")


func _emit_initial_location() -> void:
	location_updated.emit(current_lat, current_lon)


func _physics_process(delta: float) -> void:
	if use_mock_location:
		_handle_mock_movement(delta)


func _handle_mock_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return

	# Move in local meters relative to the origin, then convert back to
	# lat/lon. This keeps mock movement using the exact same math real
	# GPS updates would.
	var speed := mock_jog_speed_mps if Input.is_key_pressed(KEY_SHIFT) else mock_move_speed_mps
	var current_local := GeoMath.lat_lon_to_local(current_lat, current_lon, origin_lat, origin_lon)
	var move_delta := Vector3(input.x, 0.0, input.y) * speed * delta
	var new_local := current_local + move_delta

	var lat_lon := GeoMath.local_to_lat_lon(new_local, origin_lat, origin_lon)
	report_location(lat_lon["lat"], lat_lon["lon"])


# Call this from real GPS updates once you wire in a device plugin.
func report_location(lat: float, lon: float) -> void:
	current_lat = lat
	current_lon = lon
	location_updated.emit(lat, lon)


# Convenience: current position in local scene-space meters.
func get_local_position() -> Vector3:
	return GeoMath.lat_lon_to_local(current_lat, current_lon, origin_lat, origin_lon)
