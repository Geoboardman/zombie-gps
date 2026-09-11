class_name CompassHUD
extends Control

# An egocentric compass strip: "ahead" (wherever the player is currently
# facing) sits at the center, directly behind wraps to both edges. Every
# MapNode in the world (shop or boss altar) shows up as a colored diamond,
# regardless of how far away or out of view it
# is -- this is the actual answer to "which way should I walk," since in
# a real-world game a node 300m away is never going to be visible in the
# 3D view no matter how good your draw distance is.

@export var player_path: NodePath
@export var strip_width := 600.0
@export var strip_height := 36.0

var _player: PlayerController


func _ready() -> void:
	_player = get_node(player_path)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw() # markers move every frame as the player walks/turns, so just redraw continuously


func _draw() -> void:
	if _player == null:
		return

	var actual_width := size.x if size.x > 0.0 else strip_width
	draw_style_box(_compass_background(), Rect2(0, 0, actual_width, strip_height))
	draw_line(Vector2(actual_width / 2.0, 3.0), Vector2(actual_width / 2.0, strip_height - 3.0), Color(0.95, 0.78, 0.25), 3.0)

	var heading_deg := rad_to_deg(_angle_of(-_player.global_transform.basis.z))

	_draw_cardinal("N", 0.0, heading_deg)
	_draw_cardinal("E", 90.0, heading_deg)
	_draw_cardinal("S", 180.0, heading_deg)
	_draw_cardinal("W", -90.0, heading_deg)

	for node in get_tree().get_nodes_in_group("map_pois"):
		var poi := node as Node3D
		if poi == null or not is_instance_valid(poi):
			continue

		var to_target := poi.global_position - _player.global_position
		to_target.y = 0.0
		var bearing_deg := rad_to_deg(_angle_of(to_target))
		var relative_deg := wrapf(bearing_deg - heading_deg, -180.0, 180.0)

		var x := (actual_width / 2.0) + (relative_deg / 180.0) * (actual_width / 2.0)

		var color := Color(0.95, 0.8, 0.1) # shop yellow, matches shop_node.tscn
		if poi is BossAltarNode:
			color = Color(0.7, 0.2, 0.9) # boss purple, matches boss_altar_node.tscn
		elif poi is SurvivorNode:
			color = Color(0.85, 0.55, 0.25) # amber, matches survivor_node.tscn
		elif poi is SupplyCacheNode:
			color = Color(0.15, 0.75, 0.85)
		elif poi is FieldKitNode:
			color = Color(0.95, 0.55, 0.1)

		var marker := PackedVector2Array([
			Vector2(x, 6.0),
			Vector2(x + 6.0, strip_height / 2.0),
			Vector2(x, strip_height - 6.0),
			Vector2(x - 6.0, strip_height / 2.0),
		])
		draw_colored_polygon(marker, color)


func _draw_cardinal(text: String, absolute_deg: float, heading_deg: float) -> void:
	var relative_deg := wrapf(absolute_deg - heading_deg, -180.0, 180.0)
	if absf(relative_deg) > 90.0:
		return # behind the player -- don't clutter the strip with it

	var actual_width := size.x if size.x > 0.0 else strip_width
	var x := (actual_width / 2.0) + (relative_deg / 180.0) * (actual_width / 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(x - 6.0, 14.0), text, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 16, Color.WHITE)


func _compass_background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.018, 0.055, 0.068, 0.82)
	box.border_color = Color(0.3, 0.62, 0.68, 0.72)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	return box


# Consistent 2D bearing angle for any world-space vector, ignoring Y --
# 0 = north (-Z), 90 = east (+X), matching GeoMath's coordinate convention.
func _angle_of(vec: Vector3) -> float:
	return atan2(vec.x, -vec.z)
