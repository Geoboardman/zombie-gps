class_name MapBuilder
extends Node3D

# Takes parsed MapFeatures and turns each into a flat, styled MeshInstance3D
# lying on the ground plane -- roads as ribbons, water/buildings/landuse as
# filled polygons. Uses Godot's built-in Geometry2D.triangulate_polygon for
# correct triangulation even on concave building footprints (a naive fan
# triangulation breaks on those).

@export var style: MapStyle
@export var gps_manager_path: NodePath

var _gps: GPSManager
var _spawned_features: Array[Node3D] = []


func _ready() -> void:
	_gps = get_node(gps_manager_path)


func build_features(features: Array[MapFeature]) -> void:
	_clear_features()

	for feature in features:
		var local_points: Array[Vector3] = []
		for packed in feature.points:
			# Unpack Vector3(lat, 0, lon) and convert to real local-space
			# meters using the GPS system's current origin.
			var lat := packed.x
			var lon := packed.z
			var local := GeoMath.lat_lon_to_local(lat, lon, _gps.origin_lat, _gps.origin_lon)
			local_points.append(local)

		var built: Node3D
		if feature.is_polygon:
			built = _build_polygon(local_points, feature.kind)
		else:
			built = _build_line(local_points, feature.kind)

		if built == null:
			continue

		add_child(built)
		_spawned_features.append(built)


func _clear_features() -> void:
	for f in _spawned_features:
		f.queue_free()
	_spawned_features.clear()


func _color_for_kind(kind: MapFeature.Kind) -> Color:
	match kind:
		MapFeature.Kind.ROAD:
			return style.road_color
		MapFeature.Kind.WATER:
			return style.water_color
		MapFeature.Kind.BUILDING:
			return style.building_color
		MapFeature.Kind.LANDUSE:
			return style.landuse_color
		_:
			return Color.WHITE


# Builds a flat ribbon mesh (a road drawn as a thick line) from a sequence
# of points.
func _build_line(points: Array[Vector3], kind: MapFeature.Kind) -> Node3D:
	if points.size() < 2:
		return null

	var half_width := style.road_width / 2.0
	var y := 0.05 # slightly above the ground plane to avoid z-fighting

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var dir := b - a
		if dir.length_squared() < 0.0001:
			continue
		dir = dir.normalized()

		var perp := Vector3(-dir.z, 0, dir.x) * half_width

		var a1 := Vector3(a.x + perp.x, y, a.z + perp.z)
		var a2 := Vector3(a.x - perp.x, y, a.z - perp.z)
		var b1 := Vector3(b.x + perp.x, y, b.z + perp.z)
		var b2 := Vector3(b.x - perp.x, y, b.z - perp.z)

		st.add_vertex(a1); st.add_vertex(b1); st.add_vertex(a2)
		st.add_vertex(a2); st.add_vertex(b1); st.add_vertex(b2)

	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(_color_for_kind(kind))
	return mesh_instance


# Builds a flat filled polygon (water, building footprint, landuse area)
# using proper triangulation so concave shapes still render correctly.
func _build_polygon(points: Array[Vector3], kind: MapFeature.Kind) -> Node3D:
	if points.size() < 3:
		return null

	var points_2d := PackedVector2Array()
	for p in points:
		points_2d.append(Vector2(p.x, p.z))

	var indices := Geometry2D.triangulate_polygon(points_2d)
	if indices.is_empty():
		return null # self-intersecting or degenerate shape -- skip it rather than crash

	var y: float
	match kind:
		MapFeature.Kind.WATER:
			y = 0.02
		MapFeature.Kind.BUILDING:
			y = 0.08
		_:
			y = 0.01

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in indices:
		var v: Vector3 = points[idx]
		v.y = y
		st.add_vertex(v)

	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return null

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(_color_for_kind(kind))
	return mesh_instance


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
