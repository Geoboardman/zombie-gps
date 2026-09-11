class_name AbilityBar
extends Control

# Owns the three AbilityButtonUI nodes, connects their taps to the
# player's abilities, and keeps each button's cooldown wipe in sync every
# frame. This is the single place that knows which button maps to which
# Abilities.Type.

@export var player_path: NodePath
@export var knockback_button_path: NodePath
@export var second_wind_button_path: NodePath
@export var overcharge_button_path: NodePath

var _player: PlayerController
var _buttons: Dictionary = {} # Abilities.Type -> AbilityButtonUI


func _ready() -> void:
	_player = get_node(player_path)

	var knockback_button := get_node(knockback_button_path) as AbilityButtonUI
	var second_wind_button := get_node(second_wind_button_path) as AbilityButtonUI
	var overcharge_button := get_node(overcharge_button_path) as AbilityButtonUI

	_buttons[Abilities.Type.STASIS_PULSE] = knockback_button
	_buttons[Abilities.Type.FIELD_DRESSING] = second_wind_button
	_buttons[Abilities.Type.FRAG_GRENADE] = overcharge_button

	knockback_button.pressed.connect(func(): _player.try_activate_ability(Abilities.Type.STASIS_PULSE))
	second_wind_button.pressed.connect(func(): _player.try_activate_ability(Abilities.Type.FIELD_DRESSING))
	overcharge_button.pressed.connect(func(): _player.try_activate_ability(Abilities.Type.FRAG_GRENADE))


func _process(_delta: float) -> void:
	for type in _buttons.keys():
		var button: AbilityButtonUI = _buttons[type]
		button.set_cooldown_fraction(_player.get_ability_cooldown_fraction(type))
