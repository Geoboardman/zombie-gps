class_name Enemy
extends CharacterBody3D

# Common base for anything the player or survivors can auto-target and
# damage -- regular zombies and the boss both extend this. Attack code
# (PlayerController._try_attack, _apply_aura_damage, Survivor's fighter
# loop) loops over the "zombies" group and casts to Enemy, so any enemy
# type automatically works with existing combat without special-casing --
# this is what was missing before, which is why the boss silently took
# zero damage from anything.

var health: Health


func take_damage(amount: int) -> void:
	if health != null:
		health.take_damage(amount)
