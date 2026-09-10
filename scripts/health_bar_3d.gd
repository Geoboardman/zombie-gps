class_name HealthBar3D
extends Node3D

# A health bar built from two flat quads -- no texture assets needed.
# Faces the camera by manually rotating this whole node every frame
# (rather than using each material's shader-based billboard mode), which
# is what makes the small Z gap between the background and fill quads
# below actually mean something: with shader billboarding, a mesh-local
# Z offset doesn't reliably translate to "closer to the camera" once the
# vertex shader re-orients everything at render time, which is why the
# first version of this rendered as a solid black bar -- the two
# coplanar transparent quads had no reliable draw order, and the
# background always won.

@export var width := 1.2
@export var height := 0.15
@export var bg_color := Color(0.08, 0.08, 0.08, 0.85)
@export var fill_color := Color(0.75, 0.15, 0.15, 1.0)

var _fill_instance: MeshInstance3D
var _camera: Camera3D


func _ready() -> void:
	_build_bar()


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera != null:
		look_at(_camera.global_position, Vector3.UP)


func set_fraction(fraction: float) -> void:
	if _fill_instance == null:
		return
	_fill_instance.scale.x = clamp(fraction, 0.0, 1.0)


func _build_bar() -> void:
	# Background: a plain centered quad, doesn't need to change shape.
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(width, height)

	var bg_material := StandardMaterial3D.new()
	bg_material.albedo_color = bg_color
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var bg_instance := MeshInstance3D.new()
	bg_instance.mesh = bg_mesh
	bg_instance.material_override = bg_material
	add_child(bg_instance)

	# Fill: built via SurfaceTool with vertices spanning local x=0..width
	# (not centered) so it shrinks from the left-anchored origin. Sits at
	# a small NEGATIVE local Z -- since this node's -Z axis points toward
	# the camera (that's what look_at() above points at the camera), a
	# negative Z here means "closer to the camera than the background,"
	# so it reliably draws on top once real depth testing applies.
	var half_height := height / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(0.0, -half_height, 0.0))
	st.add_vertex(Vector3(width, -half_height, 0.0))
	st.add_vertex(Vector3(width, half_height, 0.0))
	st.add_vertex(Vector3(0.0, -half_height, 0.0))
	st.add_vertex(Vector3(width, half_height, 0.0))
	st.add_vertex(Vector3(0.0, half_height, 0.0))
	var fill_mesh := st.commit()

	var fill_material := StandardMaterial3D.new()
	fill_material.albedo_color = fill_color
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_fill_instance = MeshInstance3D.new()
	_fill_instance.mesh = fill_mesh
	_fill_instance.material_override = fill_material
	_fill_instance.position = Vector3(-width / 2.0, 0.0, -0.01)
	add_child(_fill_instance)
