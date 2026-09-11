class_name AbilityButtonUI
extends Control

# A circular ability icon with an outer recharge ring, a themed glyph
# showing what the ability DOES, and a small desktop keybind badge on the
# circle showing what to press -- all drawn in code, no image assets.
# Responds to both mouse clicks and touch taps identically, since
# Control's _gui_input receives both event types natively.

signal pressed

enum IconType { STASIS, HEAL, GRENADE }

@export var radius := 36.0
@export var icon_color := Color(0.3, 0.55, 0.9)
@export var cooldown_overlay_color := Color(0, 0, 0, 0.7)
@export var glyph_color := Color(1, 1, 1, 0.95)
@export var label_text := "Q"
@export var ability_name := "STASIS"
@export var icon_type: IconType = IconType.STASIS

const BADGE_RADIUS := 11.0
const TOP_MARGIN := 22.0 # room reserved above the circle for the keybind badge
const NAME_HEIGHT := 18.0

var _cooldown_fraction := 0.0 # 0 = ready, 1 = just used
var _show_keyboard_hint := true


func _ready() -> void:
	_show_keyboard_hint = not OS.has_feature("mobile")
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0 + TOP_MARGIN + NAME_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		pressed.emit()
		accept_event()


# Called every frame by whatever's managing this button (AbilityBar) with
# the ability's current cooldown progress. Only redraws when it actually
# changes, since _draw() gets called a lot otherwise.
func set_cooldown_fraction(fraction: float) -> void:
	var clamped: float = clamp(fraction, 0.0, 1.0)
	if not is_equal_approx(clamped, _cooldown_fraction):
		_cooldown_fraction = clamped
		queue_redraw()


func _draw() -> void:
	var center := Vector2(radius, radius + TOP_MARGIN)

	var base_color := icon_color
	if _cooldown_fraction > 0.0:
		base_color = icon_color.darkened(0.35) # dim the whole icon while on cooldown, on top of the wipe overlay

	draw_circle(center, radius + 7.0, Color(0.018, 0.055, 0.068, 0.92))
	draw_arc(center, radius + 5.0, 0.0, TAU, 48, Color(0.15, 0.25, 0.27, 0.95), 5.0)
	draw_circle(center, radius, base_color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.85, 1, 1, 0.82), 2.0)
	var recharge_fraction := 1.0 - _cooldown_fraction
	if recharge_fraction > 0.001:
		draw_arc(
			center,
			radius + 5.0,
			-PI / 2.0,
			-PI / 2.0 + TAU * recharge_fraction,
			48,
			icon_color.lightened(0.28),
			5.0,
			true
		)

	_draw_glyph(center)

	if _show_keyboard_hint:
		_draw_keybind_badge()
	draw_string(
		ThemeDB.fallback_font, Vector2(-6.0, radius * 2.0 + TOP_MARGIN + 18.0),
		ability_name, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0 + 12.0, 14, Color.WHITE
	)


func _draw_keybind_badge() -> void:
	var badge_center := Vector2(radius, radius * 2.0 + TOP_MARGIN - 3.0)
	draw_circle(badge_center, BADGE_RADIUS, Color(0, 0, 0, 0.65))
	draw_arc(badge_center, BADGE_RADIUS, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.5)
	draw_string(
		ThemeDB.fallback_font, badge_center + Vector2(-6.0, 6.0),
		label_text, HORIZONTAL_ALIGNMENT_CENTER, 22.0, 16, Color.WHITE
	)


func _draw_glyph(center: Vector2) -> void:
	match icon_type:
		IconType.STASIS:
			_draw_burst_glyph(center)
		IconType.HEAL:
			_draw_cross_glyph(center)
		IconType.GRENADE:
			_draw_grenade_glyph(center)


# Stasis: radiating spokes, reading as a field stopping nearby enemies.
func _draw_burst_glyph(center: Vector2) -> void:
	var inner := radius * 0.25
	var outer := radius * 0.55
	for i in range(6):
		var angle: float = (TAU / 6.0) * i
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * inner, center + dir * outer, glyph_color, 3.0)


# Second Wind: a plus/cross, the universal heal symbol.
func _draw_cross_glyph(center: Vector2) -> void:
	var length := radius * 0.5
	var thickness := 6.0
	draw_line(center + Vector2(0.0, -length), center + Vector2(0.0, length), glyph_color, thickness)
	draw_line(center + Vector2(-length, 0.0), center + Vector2(length, 0.0), glyph_color, thickness)


# Grenade: round body, fuse, and spark.
func _draw_grenade_glyph(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 5.0), radius * 0.3, glyph_color)
	draw_line(center + Vector2(5.0, -5.0), center + Vector2(12.0, -13.0), glyph_color, 4.0)
	draw_circle(center + Vector2(15.0, -16.0), 3.0, glyph_color)


# A pie-slice wipe, clockwise from 12 o'clock, representing how much
# cooldown remains -- shrinks to nothing as the ability becomes ready.
func _draw_cooldown_wedge(center: Vector2) -> void:
	var points := PackedVector2Array()
	points.append(center)

	var start_angle := -PI / 2.0 # 12 o'clock
	var end_angle := start_angle + TAU * _cooldown_fraction
	var segments := 32
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle: float = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	draw_polygon(points, PackedColorArray([cooldown_overlay_color]))
