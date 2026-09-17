class_name BossAltarNode
extends InteractableMapNode

# The one deliberate-choice moment in the game -- everything else is
# hands-off, but starting a boss fight is a real decision, so it's the
# one spot that asks for actual input. Walking into range shows a
# prompt; pressing the interact action summons a real Boss encounter and
# consumes the altar (one-time use).

signal boss_fight_requested
signal boss_defeated(reward_awarded: int)

@export var boss_scene: PackedScene
@export var interact_action := "ui_accept" # default Enter/Space -- swap for a dedicated "interact" action later if you want
@export var district := 1
var boss_mutation := 0

var _player_in_range := false
var _player: PlayerController


func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed(interact_action):
		interact()


func _on_player_entered(player: PlayerController) -> void:
	super._on_player_entered(player)
	_player_in_range = true
	_player = player
	action_label = "SUMMON BOSS"
	detail_text = "DISTRICT %d  •  %s" % [district, Boss.mutation_name(boss_mutation)]


func _on_player_exited(exiting_player: PlayerController) -> void:
	super._on_player_exited(exiting_player)
	_player_in_range = false


func _perform_interaction(_interacting_player: PlayerController) -> void:
	if boss_scene == null:
		push_error("[BossAltarNode] No boss_scene assigned")
		return

	boss_fight_requested.emit()
	consume()
	# Keep this node alive until the boss dies. The completion callback below is
	# owned by this altar; freeing it here would disconnect that callback and the
	# victory screen would never appear. Hide/disable it during the encounter.
	visible = false
	monitoring = false
	monitorable = false
	print("[BossAltar] Boss summoned!")

	var boss: Boss = boss_scene.instantiate()
	boss.mutation = boss_mutation
	var multiplier := 1.0 + float(district - 1) * 0.5
	boss.max_health = int(round(boss.max_health * multiplier))
	boss.attack_damage = int(round(boss.attack_damage * (1.0 + float(district - 1) * 0.2)))
	boss.slam_damage = int(round(boss.slam_damage * (1.0 + float(district - 1) * 0.2)))
	boss.currency_reward = int(round(boss.currency_reward * multiplier))
	get_tree().current_scene.add_child(boss)
	boss.global_position = global_position
	boss.target = _player

	boss.attacked_player.connect(_player.take_damage)
	boss.died.connect(func():
		var awarded := _player.add_currency(boss.currency_reward)
		boss_defeated.emit(awarded)
		queue_free()
	)
