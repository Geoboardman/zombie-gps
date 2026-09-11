class_name Abilities
extends RefCounted

# Same pattern as Upgrades: an enum plus static dispatch functions, so
# adding a new ability later is one enum entry plus a few match branches,
# nothing else touches. Each ability's actual effect lives as a real
# method on PlayerController (stasis_pulse, field_dressing, frag_grenade)
# -- this class just knows the display name, which player field holds
# the cooldown, and which method to call.

enum Type {
	STASIS_PULSE,
	FIELD_DRESSING,
	FRAG_GRENADE,
}


static func display_name(type: Type) -> String:
	match type:
		Type.STASIS_PULSE:
			return "Stasis Pulse"
		Type.FIELD_DRESSING:
			return "Field Dressing"
		Type.FRAG_GRENADE:
			return "Frag Grenade"
		_:
			return "Unknown"


static func cooldown_for(player: PlayerController, type: Type) -> float:
	match type:
		Type.STASIS_PULSE:
			return player.stasis_cooldown
		Type.FIELD_DRESSING:
			return player.field_dressing_cooldown
		Type.FRAG_GRENADE:
			return player.grenade_cooldown
		_:
			return 1.0


# Checked BEFORE cooldown is spent -- lets an ability refuse to activate
# at all when it wouldn't do anything (e.g. healing at full HP), so
# tapping it doesn't waste the cooldown for zero effect.
static func can_activate(player: PlayerController, type: Type) -> bool:
	match type:
		Type.FIELD_DRESSING:
			return player.health.current_health < player.health.max_health and not player.is_field_dressing_active()
		Type.FRAG_GRENADE:
			return player.has_grenade_target()
		_:
			return true


static func activate(player: PlayerController, type: Type) -> String:
	match type:
		Type.STASIS_PULSE:
			player.stasis_pulse()
			return "Stasis Pulse!"
		Type.FIELD_DRESSING:
			player.field_dressing()
			return "Field Dressing!"
		Type.FRAG_GRENADE:
			player.frag_grenade()
			return "Frag Grenade!"
		_:
			return "Unknown ability"
