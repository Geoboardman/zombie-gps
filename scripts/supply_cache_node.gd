class_name SupplyCacheNode
extends InteractableMapNode

signal collected(gold_found: int, healing_found: int)

@export var gold_reward := 35
@export var heal_amount := 20
@export var cache_name := "SUPPLY CACHE"


func configure_variant(variant: int) -> void:
	match variant:
		1:
			cache_name = "MEDICAL CACHE"
			gold_reward = 20
			heal_amount = 45
		2:
			cache_name = "SALVAGE CACHE"
			gold_reward = 60
			heal_amount = 5
		_:
			cache_name = "SUPPLY CACHE"
			gold_reward = 35
			heal_amount = 20

func _ready() -> void:
	action_label = "SEARCH CACHE"
	detail_text = "+%d GOLD  •  HEALS %d" % [gold_reward, heal_amount]
	var world_label := get_node_or_null("Label3D") as Label3D
	if world_label != null:
		world_label.text = cache_name
	super._ready()


func _perform_interaction(player: PlayerController) -> void:
	consume()
	player.add_currency(gold_reward)
	player.health.heal(heal_amount)
	collected.emit(gold_reward, heal_amount)
	queue_free()
