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


func show_choices(player: PlayerController, choices: Array) -> void:
	_player = player
	_choices.clear()
	_choices.assign(choices)
	var title := get_node(title_path) as Label
	title.text = "FIELD KIT RECOVERED — CHOOSE ONE"
	for i in range(_buttons.size()):
		_buttons[i].text = _button_text(_choices[i] as Upgrades.Type)
	visible = true
	get_tree().paused = true


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= _choices.size() or _player == null:
		return
	var type := _choices[index] as Upgrades.Type
	var description := Upgrades.apply(_player, type)
	print("[Opening Reward] %s" % description)
	visible = false
	get_tree().paused = false
	upgrade_chosen.emit(type)


func _button_text(type: Upgrades.Type) -> String:
	match type:
		Upgrades.Type.ATTACK_DAMAGE:
			return "HOLLOW POINTS\n+5 attack damage"
		Upgrades.Type.ATTACK_SPEED:
			return "QUICK HANDS\n15% faster attacks"
		Upgrades.Type.MAX_HEALTH:
			return "FIELD DRESSING\n+20 maximum health"
		_:
			return Upgrades.display_name(type)
