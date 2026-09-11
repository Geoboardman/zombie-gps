class_name PartyHUD
extends Control

@export var player_path: NodePath

const CARD_SIZE := Vector2(164.0, 54.0)
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
	_card_list.size = Vector2(CARD_SIZE.x, 174.0)
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
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(_open_detail.bind(survivor))
	var health_bar := ProgressBar.new()
	health_bar.position = Vector2(10.0, 39.0)
	health_bar.size = Vector2(144.0, 8.0)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(health_bar)
	_card_list.add_child(button)
	_cards[survivor] = {"button": button, "health": health_bar, "status": ""}


func _update_card(survivor: Survivor) -> void:
	var entry: Dictionary = _cards[survivor]
	var button := entry["button"] as Button
	var health_bar := entry["health"] as ProgressBar
	var current := survivor.health.current_health if survivor.health != null else 0
	var maximum := survivor.health.max_health if survivor.health != null else survivor.max_health
	button.text = "  %s   L%d\n  %s  •  %s" % [survivor.survivor_name.to_upper(), survivor.level, Survivor.name_for_kind(survivor.kind), survivor.status_name().capitalize()]
	health_bar.max_value = maximum
	health_bar.value = current
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


func _action_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.3, 1.0, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
