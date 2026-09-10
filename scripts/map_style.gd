class_name MapStyle
extends Resource

# A Resource (not a Node) so you can create multiple style presets as .tres
# files in the editor -- e.g. map_style_zombie.tres, map_style_night.tres --
# and swap which one MapBuilder uses without touching code. This is your
# main "change the look and feel" lever.

@export_group("Roads")
@export var road_color: Color = Color(0.55, 0.55, 0.55)
@export var road_width: float = 3.0

@export_group("Water")
@export var water_color: Color = Color(0.20, 0.45, 0.75)

@export_group("Buildings")
@export var building_color: Color = Color(0.75, 0.68, 0.60)

@export_group("Landuse")
@export var landuse_color: Color = Color(0.45, 0.62, 0.38)

@export_group("Ground")
@export var ground_color: Color = Color(0.30, 0.50, 0.30)
