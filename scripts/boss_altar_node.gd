class_name BossAltarNode
extends MapNode

# The one deliberate-choice moment in the game -- everything else is
# hands-off, but starting a boss fight is a real decision, so it's the
# one spot that asks for actual input. Walking into range shows a
# prompt; pressing the interact action summons a real Boss encounter and
# consumes the altar (one-time use).

signal boss_fight_requested
signal boss_defeated
signal interaction_available(altar: BossAltarNode, available: bool)

@export var boss_scene: PackedScene
@export var interact_action := "ui_accept" # default Enter/Space -- swap for a dedicated "interact" action later if you want
@export var victory_screen_path: NodePath # set relative to the main scene, not this node -- see main.tscn wiring

var _player_in_range := false
var _prompted := false
var _player: PlayerController


func _process(_delta: float) -> void:
	if _player_in_range and not _prompted:
		print("[BossAltar] In range -- press %s to summon the boss" % interact_action)
		_prompted = true

	if _player_in_range and Input.is_action_just_pressed(interact_action):
		_summon_boss()


func _on_player_entered(player: PlayerController) -> void:
	_player_in_range = true
	_prompted = false
	_player = player
	interaction_available.emit(self, true)


func _on_player_exited(_player: PlayerController) -> void:
	_player_in_range = false
	_prompted = false
	interaction_available.emit(self, false)


func summon_boss() -> void:
	_summon_boss()


func _summon_boss() -> void:
	if boss_scene == null:
		push_error("[BossAltarNode] No boss_scene assigned")
		return

	boss_fight_requested.emit()
	interaction_available.emit(self, false)
	print("[BossAltar] Boss summoned!")

	var boss: Boss = boss_scene.instantiate()
	get_tree().current_scene.add_child(boss)
	boss.global_position = global_position
	boss.target = _player

	boss.attacked_player.connect(_player.take_damage)
	boss.died.connect(func():
		_player.add_currency(boss.currency_reward)
		boss_defeated.emit()
		if victory_screen_path != NodePath(""):
			var screen := get_tree().current_scene.get_node(victory_screen_path) as BossVictoryScreen
			screen.show_victory(boss.currency_reward)
	)

	# One-time use -- the altar itself disappears once the boss is
	# summoned, so it can't be triggered again.
	queue_free()
