class_name SurvivorNode
extends MapNode

# Free to recruit -- finding someone alive is the reward, no currency
# cost. Picks one random Survivor.SurvivorKind at spawn time and shows it
# on a floating label, same pattern as ShopNode's upgrade preview.

@export var survivor_scene: PackedScene

var _chosen_kind: Survivor.SurvivorKind
var _label: Label3D


func _ready() -> void:
	super._ready() # MapNode's _ready() wires up proximity signals -- don't skip it

	var kinds: Array[int] = []
	kinds.assign(Survivor.SurvivorKind.values())
	_chosen_kind = kinds[randi() % kinds.size()] as Survivor.SurvivorKind

	_label = get_node("RecruitLabel") as Label3D
	_label.text = "Recruit\n%s" % Survivor.name_for_kind(_chosen_kind)


func _on_player_entered(player: PlayerController) -> void:
	if survivor_scene == null:
		push_error("[SurvivorNode] No survivor_scene assigned")
		queue_free()
		return

	var survivor: Survivor = survivor_scene.instantiate()
	survivor.kind = _chosen_kind
	survivor.player = player

	# Spread survivors around the player so they don't all stack on the
	# same spot -- each new recruit gets a different angle around a ring.
	var existing_count := get_tree().get_nodes_in_group("survivors").size()
	survivor.follow_offset_angle = existing_count * (TAU / 6.0)

	# Add to the main scene, not as a child of this node -- this node is
	# about to free itself, which would take a child survivor down with it.
	get_tree().current_scene.add_child(survivor)
	survivor.global_position = player.global_position + Vector3(1.5, 0.0, 1.5)

	print("[SurvivorNode] Recruited a %s!" % Survivor.name_for_kind(_chosen_kind))

	queue_free()
