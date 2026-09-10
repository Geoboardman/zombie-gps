class_name Abilities
extends RefCounted

# Same pattern as Upgrades: an enum plus static dispatch functions, so
# adding a new ability later is one enum entry plus a few match branches,
# nothing else touches. Each ability's actual effect lives as a real
# method on PlayerController (knockback_pulse, second_wind, overcharge)
# -- this class just knows the display name, which player field holds
# the cooldown, and which method to call.

enum Type {
	KNOCKBACK_PULSE,
	SECOND_WIND,
	OVERCHARGE,
}


static func display_name(type: Type) -> String:
	match type:
		Type.KNOCKBACK_PULSE:
			return "Knockback Pulse"
		Type.SECOND_WIND:
			return "Second Wind"
		Type.OVERCHARGE:
			return "Overcharge"
		_:
			return "Unknown"


static func cooldown_for(player: PlayerController, type: Type) -> float:
	match type:
		Type.KNOCKBACK_PULSE:
			return player.knockback_cooldown
		Type.SECOND_WIND:
			return player.second_wind_cooldown
		Type.OVERCHARGE:
			return player.overcharge_cooldown
		_:
			return 1.0


# Checked BEFORE cooldown is spent -- lets an ability refuse to activate
# at all when it wouldn't do anything (e.g. healing at full HP), so
# tapping it doesn't waste the cooldown for zero effect.
static func can_activate(player: PlayerController, type: Type) -> bool:
	match type:
		Type.SECOND_WIND:
			return player.health.current_health < player.health.max_health
		_:
			return true


static func activate(player: PlayerController, type: Type) -> String:
	match type:
		Type.KNOCKBACK_PULSE:
			player.knockback_pulse()
			return "Knockback Pulse!"
		Type.SECOND_WIND:
			player.second_wind()
			return "Second Wind!"
		Type.OVERCHARGE:
			player.overcharge()
			return "Overcharge!"
		_:
			return "Unknown ability"
