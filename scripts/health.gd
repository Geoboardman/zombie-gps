class_name Health
extends RefCounted

# Small reusable health tracker. Not a Node -- just plain state with
# signals, so both the player and zombies can each own one without any
# extra scene-tree wiring.

signal health_changed(current: int, max: int)
signal died

var max_health: int
var current_health: int


func _init(max_hp: int = 100) -> void:
	max_health = max_hp
	current_health = max_hp


func take_damage(amount: int) -> void:
	if current_health <= 0:
		return # already dead, ignore further hits

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
