class_name SurvivorNode
extends InteractableMapNode

signal recruited(survivor: Survivor)

# Free to recruit -- finding someone alive is the reward, no currency
# cost. Picks one random Survivor.SurvivorKind at spawn time and shows it
# on a floating label, same pattern as ShopNode's upgrade preview.

@export var survivor_scene: PackedScene

var _chosen_kind: Survivor.SurvivorKind
var _chosen_appearance := 0
var _label: Label3D
var _visual: CharacterVisual


func _ready() -> void:
	super._ready() # MapNode's _ready() wires up proximity signals -- don't skip it

	var kinds: Array[int] = []
	kinds.assign(Survivor.SurvivorKind.values())
	_chosen_kind = kinds[randi() % kinds.size()] as Survivor.SurvivorKind
	_chosen_appearance = get_tree().get_nodes_in_group("survivors").size() % Survivor.NAMES.size()

	_label = get_node("RecruitLabel") as Label3D
	for index in range(Survivor.NAMES.size()):
		var preview := get_node_or_null("Visual%d" % index) as CharacterVisual
		if preview != null:
			preview.visible = index == _chosen_appearance
	_visual = get_node("Visual%d" % _chosen_appearance) as CharacterVisual
	_visual.play_clip("Idle_Gun")
	var recruit_name: String = Survivor.NAMES[_chosen_appearance]
	_label.text = "%s\n%s" % [recruit_name, Survivor.name_for_kind(_chosen_kind)]
	action_label = "RECRUIT %s" % recruit_name.to_upper()
	detail_text = _description_for_kind(_chosen_kind)


func _perform_interaction(player: PlayerController) -> void:
	if survivor_scene == null:
		push_error("[SurvivorNode] No survivor_scene assigned")
		queue_free()
		return
	consume()

	var survivor: Survivor = survivor_scene.instantiate()
	survivor.kind = _chosen_kind
	survivor.appearance_index = _chosen_appearance
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
	recruited.emit(survivor)

	queue_free()


func _description_for_kind(value: Survivor.SurvivorKind) -> String:
	return "%s — %s" % [Survivor.name_for_kind(value), Survivor.description_for_kind(value)]
