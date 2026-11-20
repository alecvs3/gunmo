class_name HealthComponent
extends Node
## Health for its owner. Only the host changes it; clients receive current_health through sync.

signal damaged(amount: int, source_id: int)
signal healed(amount: int)
signal died(source_id: int)

@export_range(1, 10000) var max_health: int = 100

var current_health: int = 0


func _ready() -> void:
	current_health = max_health


func is_dead() -> bool:
	return current_health <= 0


## source_id is the attacker's peer id (0 when it was not a player).
func take_damage(amount: int, source_id: int = 0) -> void:
	if not _can_modify() or amount <= 0 or is_dead():
		return
	var dealt: int = mini(amount, current_health)
	current_health -= dealt
	damaged.emit(dealt, source_id)
	if current_health == 0:
		died.emit(source_id)


func heal(amount: int) -> void:
	if not _can_modify() or amount <= 0 or is_dead():
		return
	var restored: int = mini(amount, max_health - current_health)
	if restored == 0:
		return
	current_health += restored
	healed.emit(restored)


## Back to full health, e.g. on respawn.
func reset() -> void:
	if _can_modify():
		current_health = max_health


func _can_modify() -> bool:
	return multiplayer.is_server()
