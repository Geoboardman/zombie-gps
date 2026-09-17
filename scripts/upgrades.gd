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
	DOUBLE_TAP,
	PIERCING_ROUNDS,
	EXECUTIONER,
	BURNING_PRESENCE,
	ADRENAL_RESPONSE,
	CLUSTER_GRENADE,
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
			return "Stasis Capacity"
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
		Type.DOUBLE_TAP:
			return "Double Tap"
		Type.PIERCING_ROUNDS:
			return "Piercing Rounds"
		Type.EXECUTIONER:
			return "Executioner"
		Type.BURNING_PRESENCE:
			return "Burning Presence"
		Type.ADRENAL_RESPONSE:
			return "Adrenal Response"
		Type.CLUSTER_GRENADE:
			return "Cluster Grenade"
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
			player.stasis_radius += 0.75
			player.stasis_duration += 0.4
			return "Stasis Pulse improved (radius %.1fm, duration %.1fs)" % [player.stasis_radius, player.stasis_duration]

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

		Type.DOUBLE_TAP:
			player.double_tap_level += 1
			return "Every attack fires a follow-up shot"

		Type.PIERCING_ROUNDS:
			player.piercing_targets += 1
			return "Shots damage %d additional nearby target(s)" % player.piercing_targets

		Type.EXECUTIONER:
			player.execution_damage_multiplier += 0.35
			return "Damage to enemies below 30%% HP increased"

		Type.BURNING_PRESENCE:
			player.aura_bonus_damage += 3
			return "Damage Aura burns for +3 damage per tick"

		Type.ADRENAL_RESPONSE:
			player.adrenaline_attack_multiplier = max(0.4, player.adrenaline_attack_multiplier - 0.15)
			return "Attack faster while below 35%% HP"

		Type.CLUSTER_GRENADE:
			player.grenade_cluster_count += 3
			return "Grenades release three secondary blasts"

		_:
			return "Unknown upgrade"


static func short_name(type: Type) -> String:
	match type:
		Type.ATTACK_DAMAGE: return "Damage"
		Type.ATTACK_SPEED: return "Fire Rate"
		Type.ATTACK_RANGE: return "Range"
		Type.MAX_HEALTH: return "Health"
		Type.KNOCKBACK_POWER: return "Stasis Range"
		Type.AURA_POWER: return "Aura"
		Type.GOLD_GAIN: return "Scavenger"
		Type.REGEN: return "Regen"
		Type.LIFESTEAL: return "Lifesteal"
		Type.ARMOR: return "Armor"
		Type.DOUBLE_TAP: return "Double Tap"
		Type.PIERCING_ROUNDS: return "Piercing"
		Type.EXECUTIONER: return "Executioner"
		Type.BURNING_PRESENCE: return "Burning Aura"
		Type.ADRENAL_RESPONSE: return "Adrenaline"
		Type.CLUSTER_GRENADE: return "Cluster Frag"
		_: return "Unknown"


static func choice_description(type: Type) -> String:
	match type:
		Type.ATTACK_DAMAGE: return "+5 attack damage"
		Type.ATTACK_SPEED: return "15% faster attacks"
		Type.ATTACK_RANGE: return "+1m attack range"
		Type.MAX_HEALTH: return "+20 maximum health"
		Type.KNOCKBACK_POWER: return "larger, longer Stasis Pulse"
		Type.AURA_POWER: return "larger and stronger damage aura"
		Type.GOLD_GAIN: return "+15% gold rewards"
		Type.REGEN: return "+0.5 health per second"
		Type.LIFESTEAL: return "heal from weapon damage"
		Type.ARMOR: return "10% damage reduction"
		Type.DOUBLE_TAP: return "fire a follow-up shot"
		Type.PIERCING_ROUNDS: return "hit an additional enemy"
		Type.EXECUTIONER: return "finish low-health enemies faster"
		Type.BURNING_PRESENCE: return "aura deals +3 damage per tick"
		Type.ADRENAL_RESPONSE: return "fire faster below 35% health"
		Type.CLUSTER_GRENADE: return "three secondary explosions"
		_: return "Unknown effect"


static func choice_description_for(player: PlayerController, type: Type) -> String:
	match type:
		Type.ATTACK_DAMAGE:
			return "%d → %d damage per shot" % [player.attack_damage, player.attack_damage + 5]
		Type.ATTACK_SPEED:
			var next_interval: float = maxf(0.2, player.attack_interval * 0.85)
			return "%.2f → %.2f shots/sec" % [1.0 / player.attack_interval, 1.0 / next_interval]
		Type.ATTACK_RANGE:
			return "%.1f → %.1fm weapon range" % [player.attack_range, player.attack_range + 1.0]
		Type.MAX_HEALTH:
			return "%d → %d maximum health" % [player.health.max_health, player.health.max_health + 20]
		Type.AURA_POWER:
			return "%d → %d aura damage/tick" % [player.aura_damage_per_tick + player.aura_bonus_damage, player.aura_damage_per_tick + player.aura_bonus_damage + 2]
		Type.REGEN:
			return "%.1f → %.1f health/sec" % [player.regen_per_second, player.regen_per_second + 0.5]
		Type.LIFESTEAL:
			return "%.0f%% → %.0f%% weapon lifesteal" % [player.lifesteal_percent * 100.0, (player.lifesteal_percent + 0.05) * 100.0]
		Type.ARMOR:
			return "%.0f%% → %.0f%% damage reduction" % [player.damage_reduction_percent * 100.0, minf(0.75, player.damage_reduction_percent + 0.10) * 100.0]
		_:
			var level: int = player.get_upgrade_count(type)
			return "LV %d → LV %d  •  %s" % [level, level + 1, choice_description(type)]


static func category(type: Type) -> String:
	match type:
		Type.ATTACK_DAMAGE, Type.ATTACK_SPEED, Type.ATTACK_RANGE, Type.DOUBLE_TAP, Type.PIERCING_ROUNDS, Type.EXECUTIONER:
			return "WEAPON"
		Type.MAX_HEALTH, Type.REGEN, Type.LIFESTEAL, Type.ARMOR, Type.ADRENAL_RESPONSE:
			return "SURVIVAL"
		Type.KNOCKBACK_POWER, Type.AURA_POWER, Type.BURNING_PRESENCE, Type.CLUSTER_GRENADE:
			return "ABILITY"
		Type.GOLD_GAIN:
			return "UTILITY"
		_:
			return "OTHER"


static func random_choices(count: int) -> Array[int]:
	var pool: Array[int] = []
	pool.assign(Type.values())
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
