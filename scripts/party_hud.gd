class_name PartyHUD
extends Control

@export var player_path: NodePath

const CARD_SIZE := Vector2(184.0, 64.0)
const ROLE_COLORS := {
	Survivor.SurvivorKind.FIGHTER: Color(0.95, 0.55, 0.18),
	Survivor.SurvivorKind.MEDIC: Color(0.2, 0.9, 0.5),
	Survivor.SurvivorKind.SCOUT: Color(0.25, 0.65, 1.0),
}

var _player: PlayerController
var _card_list: VBoxContainer
var _cards: Dictionary = {}
var _detail_backdrop: ColorRect
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_status: Label
var _detail_health: ProgressBar
var _detail_health_text: Label
var _detail_body: Label
var _treat_button: Button
var _selected: Survivor
var _owns_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node(player_path) as PlayerController
	_build_party_list()
	_build_detail_panel()


func _process(_delta: float) -> void:
	var survivors := _active_survivors()
	_sync_cards(survivors)
	if _owns_pause and (_selected == null or not is_instance_valid(_selected)):
		_close_detail()
	if _owns_pause:
		_refresh_detail()
	_card_list.visible = not get_tree().paused or _owns_pause


func _active_survivors() -> Array[Survivor]:
	var result: Array[Survivor] = []
	for node: Node in get_tree().get_nodes_in_group("survivors"):
		var survivor := node as Survivor
		if survivor != null and is_instance_valid(survivor):
			result.append(survivor)
	result.sort_custom(func(a: Survivor, b: Survivor) -> bool: return a.get_instance_id() < b.get_instance_id())
	while result.size() > 3:
		result.pop_back()
	return result


func _build_party_list() -> void:
	_card_list = VBoxContainer.new()
	_card_list.name = "PartyCards"
	_card_list.position = Vector2(8.0, 164.0)
	_card_list.size = Vector2(CARD_SIZE.x, 204.0)
	_card_list.add_theme_constant_override("separation", 4)
	add_child(_card_list)


func _sync_cards(survivors: Array[Survivor]) -> void:
	for existing: Variant in _cards.keys():
		if is_instance_valid(existing) and survivors.has(existing as Survivor):
			continue
		var old_entry: Dictionary = _cards[existing]
		(old_entry["button"] as Button).queue_free()
		_cards.erase(existing)
	for survivor: Survivor in survivors:
		if not _cards.has(survivor):
			_create_card(survivor)
		_update_card(survivor)


func _create_card(survivor: Survivor) -> void:
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.text = ""
	button.pressed.connect(_open_detail.bind(survivor))
	var badge := Label.new()
	badge.position = Vector2(8.0, 9.0)
	badge.size = Vector2(38.0, 38.0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 21)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("normal", _badge_style(survivor))
	button.add_child(badge)
	var name_label := Label.new()
	name_label.position = Vector2(54.0, 5.0)
	name_label.size = Vector2(74.0, 21.0)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	var level_label := Label.new()
	level_label.position = Vector2(130.0, 6.0)
	level_label.size = Vector2(48.0, 19.0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.82, 0.86))
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(level_label)
	var role_label := Label.new()
	role_label.position = Vector2(54.0, 24.0)
	role_label.size = Vector2(58.0, 17.0)
	role_label.add_theme_font_size_override("font_size", 10)
	var role_color: Color = ROLE_COLORS.get(survivor.kind, Color.WHITE)
	role_label.add_theme_color_override("font_color", role_color)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(role_label)
	var status_label := Label.new()
	status_label.position = Vector2(112.0, 24.0)
	status_label.size = Vector2(66.0, 17.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(status_label)
	var health_track := Panel.new()
	health_track.position = Vector2(54.0, 47.0)
	health_track.size = Vector2(124.0, 7.0)
	health_track.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	health_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_track.add_theme_stylebox_override("panel", _progress_style(Color(0.08, 0.13, 0.15)))
	button.add_child(health_track)
	var health_fill := Panel.new()
	health_fill.size = health_track.size
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_fill.add_theme_stylebox_override("panel", _progress_style(Color(0.15, 0.88, 0.48)))
	health_track.add_child(health_fill)
	_card_list.add_child(button)
	_cards[survivor] = {
		"button": button, "health_fill": health_fill, "badge": badge,
		"name": name_label, "level": level_label, "role": role_label,
		"status_label": status_label, "status": "",
	}


func _update_card(survivor: Survivor) -> void:
	var entry: Dictionary = _cards[survivor]
	var button := entry["button"] as Button
	var health_fill := entry["health_fill"] as Panel
	var badge := entry["badge"] as Label
	var name_label := entry["name"] as Label
	var level_label := entry["level"] as Label
	var role_label := entry["role"] as Label
	var status_label := entry["status_label"] as Label
	var current: float = float(survivor.health.current_health if survivor.health != null else 0)
	var maximum: float = float(survivor.health.max_health if survivor.health != null else survivor.max_health)
	badge.text = _role_icon(survivor.kind)
	name_label.text = survivor.survivor_name.to_upper()
	level_label.text = "LV %d" % survivor.level
	role_label.text = Survivor.name_for_kind(survivor.kind).to_upper()
	status_label.text = "● %s" % survivor.status_name()
	status_label.add_theme_color_override("font_color", _status_color(survivor))
	var health_ratio: float = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	health_fill.size = Vector2(124.0 * health_ratio, 7.0)
	if entry["status"] != survivor.status_name():
		entry["status"] = survivor.status_name()
		button.add_theme_stylebox_override("normal", _card_style(survivor))
		button.add_theme_stylebox_override("hover", _card_style(survivor, true))
		button.add_theme_stylebox_override("pressed", _card_style(survivor, true))


func _build_detail_panel() -> void:
	_detail_backdrop = ColorRect.new()
	_detail_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_backdrop.color = Color(0.0, 0.02, 0.025, 0.82)
	_detail_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_backdrop.visible = false
	add_child(_detail_backdrop)

	_detail_panel = PanelContainer.new()
	_detail_panel.anchor_left = 0.08
	_detail_panel.anchor_top = 0.18
	_detail_panel.anchor_right = 0.92
	_detail_panel.anchor_bottom = 0.82
	_detail_panel.add_theme_stylebox_override("panel", _panel_style())
	_detail_backdrop.add_child(_detail_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	_detail_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 28)
	_detail_title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	content.add_child(_detail_title)
	_detail_status = Label.new()
	_detail_status.add_theme_font_size_override("font_size", 18)
	content.add_child(_detail_status)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 12)
	content.add_child(health_row)
	var health_title := Label.new()
	health_title.text = "HEALTH"
	health_title.custom_minimum_size = Vector2(68.0, 24.0)
	health_row.add_child(health_title)
	_detail_health = ProgressBar.new()
	_detail_health.custom_minimum_size = Vector2(210.0, 22.0)
	_detail_health.show_percentage = false
	health_row.add_child(_detail_health)
	_detail_health_text = Label.new()
	health_row.add_child(_detail_health_text)

	_detail_body = Label.new()
	_detail_body.add_theme_font_size_override("font_size", 16)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_detail_body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	_treat_button = Button.new()
	_treat_button.custom_minimum_size = Vector2(180.0, 52.0)
	_treat_button.text = "+  USE DRESSING"
	_treat_button.add_theme_stylebox_override("normal", _action_style(Color(0.08, 0.55, 0.3)))
	_treat_button.pressed.connect(_treat_selected)
	actions.add_child(_treat_button)
	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(130.0, 52.0)
	close_button.text = "CLOSE"
	close_button.pressed.connect(_close_detail)
	actions.add_child(close_button)


func _open_detail(survivor: Survivor) -> void:
	if get_tree().paused:
		return
	_selected = survivor
	_owns_pause = true
	_detail_backdrop.visible = true
	get_tree().paused = true
	_refresh_detail()


func _close_detail() -> void:
	_detail_backdrop.visible = false
	_selected = null
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false


func _treat_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	_player.try_activate_ability(Abilities.Type.FIELD_DRESSING)
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	var current := _selected.health.current_health if _selected.health != null else 0
	var maximum := _selected.health.max_health if _selected.health != null else _selected.max_health
	_detail_title.text = "%s   •   LEVEL %d %s" % [_selected.survivor_name.to_upper(), _selected.level, Survivor.name_for_kind(_selected.kind).to_upper()]
	_detail_status.text = _status_detail(_selected)
	_detail_status.add_theme_color_override("font_color", _status_color(_selected))
	_detail_health.max_value = maximum
	_detail_health.value = current
	_detail_health_text.text = "%d / %d" % [current, maximum]
	_detail_body.text = "EXPERIENCE\n%d / %d to next level\n\nWEAPON\n%s\n\nCOMBAT\nDamage %d   •   Range %.1fm   •   Fire interval %.1fs\n\nHISTORY\n%d kills   •   %d times downed   •   %d bosses survived" % [
		_selected.experience, _selected.experience_per_level,
		Survivor.weapon_name_for_kind(_selected.kind),
		_selected.attack_damage, _selected.attack_range, _selected.attack_interval,
		_selected.kills, _selected.times_downed, _selected.bosses_survived,
	]
	_treat_button.disabled = not _selected.needs_field_dressing() or _player.is_field_dressing_active()


func _status_detail(survivor: Survivor) -> String:
	if survivor.is_downed:
		return "DOWNED  •  Use Field Dressing to revive"
	if survivor.injuries > 0:
		return "INJURED  •  Another defeat may be fatal"
	return "HEALTHY  •  Ready for combat"


func _status_color(survivor: Survivor) -> Color:
	if survivor.is_downed:
		return Color(1.0, 0.35, 0.25)
	if survivor.injuries > 0:
		return Color(1.0, 0.65, 0.2)
	return Color(0.25, 0.95, 0.55)


func _card_style(survivor: Survivor, highlighted := false) -> StyleBoxFlat:
	var role_color: Color = ROLE_COLORS.get(survivor.kind, Color(0.3, 0.7, 0.75))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.06, 0.075, 0.94 if not highlighted else 0.99)
	style.border_color = role_color
	style.set_border_width_all(2 if not highlighted else 3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8.0
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.07, 0.09, 0.99)
	style.border_color = Color(0.2, 0.9, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	return style


func _badge_style(survivor: Survivor) -> StyleBoxFlat:
	var role_color: Color = ROLE_COLORS.get(survivor.kind, Color(0.3, 0.7, 0.75))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(role_color.r * 0.35, role_color.g * 0.35, role_color.b * 0.35, 1.0)
	style.border_color = role_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(19)
	return style


func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style


func _role_icon(kind: Survivor.SurvivorKind) -> String:
	match kind:
		Survivor.SurvivorKind.MEDIC: return "+"
		Survivor.SurvivorKind.SCOUT: return "◎"
		_: return "◆"


func _action_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.3, 1.0, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
