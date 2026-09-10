class_name ShopNode
extends MapNode

# Picks one random upgrade type at spawn time and displays it above the
# node, so which shop to walk to becomes a real decision instead of "any
# node is the same node." Still fully passive on the actual purchase --
# walking into range with enough gold auto-buys it.

@export var upgrade_cost := 50

# Leave empty to allow any upgrade type; fill in specific Upgrades.Type
# values to restrict what this particular node can roll (e.g. for a
# themed shop later).
@export var possible_types: Array[int] = []

var _chosen_type: Upgrades.Type
var _label: Label3D


func _ready() -> void:
	super._ready() # MapNode's _ready() wires up the body_entered/exited proximity signals -- don't skip it

	var types: Array[int] = possible_types.duplicate()
	if types.is_empty():
		types.assign(Upgrades.Type.values())

	_chosen_type = types[randi() % types.size()] as Upgrades.Type

	_label = get_node("UpgradeLabel") as Label3D
	_label.text = "%s\n%dg" % [Upgrades.display_name(_chosen_type), upgrade_cost]


func _on_player_entered(player: PlayerController) -> void:
	if player.try_spend_currency(upgrade_cost):
		var description := Upgrades.apply(player, _chosen_type)
		print("[ShopNode] Purchased! %s" % description)
	else:
		print("[ShopNode] Not enough gold (have %d, need %d) -- walk away and come back once you've got more" % [player.currency, upgrade_cost])
		return # don't consume the node -- let the player come back later

	queue_free()
