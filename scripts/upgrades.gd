class_name Upgrades
extends RefCounted

# Central definition of every upgrade type a shop node can offer. Adding
# a new upgrade later means adding one enum entry plus one match branch
# in each of display_name() and apply() -- nothing else needs to change.

enum Type {
	ATTACK_DAMAGE,
	ATTACK_SPEED,
	ATTACK_RANGE,
	MAX_HEALTH,
	KNOCKBACK_POWER,
	AURA_POWER,
	GOLD_GAIN,
	REGEN,
	LIFESTEAL,
	ARMOR,
}


static func display_name(type: Type) -> String:
	match type:
		Type.ATTACK_DAMAGE:
			return "Attack Damage"
		Type.ATTACK_SPEED:
			return "Attack Speed"
		Type.ATTACK_RANGE:
			return "Attack Range"
		Type.MAX_HEALTH:
			return "Max Health"
		Type.KNOCKBACK_POWER:
			return "Knockback Power"
		Type.AURA_POWER:
			return "Damage Aura"
		Type.GOLD_GAIN:
			return "Gold Gain"
		Type.REGEN:
			return "Health Regen"
		Type.LIFESTEAL:
			return "Lifesteal"
		Type.ARMOR:
			return "Armor"
		_:
			return "Unknown"


# Mutates the player's stats for the given upgrade type and returns a
# short human-readable description of what changed (for logging/UI).
static func apply(player: PlayerController, type: Type) -> String:
	match type:
		Type.ATTACK_DAMAGE:
			player.attack_damage += 5
			return "Attack Damage +5 (now %d)" % player.attack_damage

		Type.ATTACK_SPEED:
			player.attack_interval = max(0.2, player.attack_interval * 0.85)
			return "Attack Speed up (interval now %.2fs)" % player.attack_interval

		Type.ATTACK_RANGE:
			player.attack_range += 1.0
			return "Attack Range +1m (now %.1fm)" % player.attack_range

		Type.MAX_HEALTH:
			player.health.max_health += 20
			player.health.heal(20)
			return "Max Health +20 (now %d)" % player.health.max_health

		Type.KNOCKBACK_POWER:
			player.knockback_radius += 1.0
			player.knockback_force += 0.75
			return "Knockback Power up (radius %.1fm, force %.1f)" % [player.knockback_radius, player.knockback_force]

		Type.AURA_POWER:
			player.aura_radius += 0.5
			player.aura_damage_per_tick += 2
			return "Damage Aura up (radius %.1fm, %d dmg/tick)" % [player.aura_radius, player.aura_damage_per_tick]

		Type.GOLD_GAIN:
			player.currency_gain_multiplier += 0.15
			return "Gold Gain up (now %.0f%% of base)" % (player.currency_gain_multiplier * 100.0)

		Type.REGEN:
			player.regen_per_second += 0.5
			return "Health Regen up (now %.1f HP/sec)" % player.regen_per_second

		Type.LIFESTEAL:
			player.lifesteal_percent += 0.05
			return "Lifesteal up (now %.0f%% of damage dealt)" % (player.lifesteal_percent * 100.0)

		Type.ARMOR:
			player.damage_reduction_percent = min(0.75, player.damage_reduction_percent + 0.10)
			return "Armor up (now %.0f%% damage reduction)" % (player.damage_reduction_percent * 100.0)

		_:
			return "Unknown upgrade"
