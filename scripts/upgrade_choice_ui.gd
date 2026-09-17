class_name UpgradeChoiceUI
extends Control

signal upgrade_chosen(type: Upgrades.Type)

@export var title_path: NodePath
@export var button_paths: Array[NodePath]

var _player: PlayerController
var _choices: Array[int] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for path in button_paths:
		var button := get_node(path) as Button
		_buttons.append(button)
		button.pressed.connect(_on_button_pressed.bind(_buttons.size() - 1))


func show_choices(player: PlayerController, choices: Array, heading := "FIELD KIT RECOVERED — CHOOSE ONE") -> void:
	_player = player
	_choices.clear()
	_choices.assign(choices)
	var title := get_node(title_path) as Label
	title.text = heading
	for i in range(_buttons.size()):
		var type := _choices[i] as Upgrades.Type
		_buttons[i].text = _button_text(type)
		_buttons[i].add_theme_color_override("font_color", _category_color(type))
		_buttons[i].add_theme_color_override("font_hover_color", _category_color(type).lightened(0.15))
	visible = true
	get_tree().paused = true


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= _choices.size() or _player == null:
		return
	var type := _choices[index] as Upgrades.Type
	var description := Upgrades.apply(_player, type)
	_player.record_upgrade(type)
	print("[Opening Reward] %s" % description)
	visible = false
	get_tree().paused = false
	upgrade_chosen.emit(type)


func _button_text(type: Upgrades.Type) -> String:
	return "%s  •  %s\n%s" % [Upgrades.category(type), Upgrades.display_name(type).to_upper(), Upgrades.choice_description_for(_player, type)]


func _category_color(type: Upgrades.Type) -> Color:
	match Upgrades.category(type):
		"WEAPON": return Color(1.0, 0.72, 0.2)
		"SURVIVAL": return Color(0.25, 0.95, 0.55)
		"ABILITY": return Color(0.3, 0.78, 1.0)
		_: return Color(0.86, 0.9, 0.94)
