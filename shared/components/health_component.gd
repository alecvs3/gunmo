class_name HealthComponent
extends Node
## Health for its owner. Only the host changes it; clients receive current_health through sync.

signal damaged(amount: int, source_id: int)
signal healed(amount: int)
signal died(source_id: int)

@export_range(1, 10000) var max_health: int = 100
## Incoming damage is multiplied by this (armor); every hit still does at least 1.
var damage_taken_multiplier: float = 1.0
## Host: incoming damage is also multiplied by the entry for its DamageType (an enemy's traits,
## EnemyTrait.profile). Empty = 1.0 for every type (players).
var type_multipliers := PackedFloat64Array()
## Host: no damage at all while set (spawn protection).
var invulnerable: bool = false

var current_health: int = 0


## Host only: on clients the synchronizer has already applied the host's value by now.
func _ready() -> void:
	reset()


func is_dead() -> bool:
	return current_health <= 0


## source_id is the attacker's peer id (0 when it was not a player). damage_type is a
## DamageType.Type.
func take_damage(
	amount: int, source_id: int = 0, damage_type: int = DamageType.Type.KINETIC
) -> void:
	if not _can_modify() or amount <= 0 or is_dead() or invulnerable:
		return
	var scaled: int = scaled_damage(amount, damage_taken_multiplier * type_factor(damage_type))
	var dealt: int = mini(scaled, current_health)
	current_health -= dealt
	damaged.emit(dealt, source_id)
	if current_health == 0:
		died.emit(source_id)


## Pure: what a hit of `amount` does at `multiplier` (whole points, at least 1).
static func scaled_damage(amount: int, multiplier: float) -> int:
	return maxi(roundi(amount * multiplier), 1)


## What damage of `damage_type` is multiplied by on top of damage_taken_multiplier.
func type_factor(damage_type: int) -> float:
	if damage_type < 0 or damage_type >= type_multipliers.size():
		return 1.0
	return type_multipliers[damage_type]


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


## Host: set health directly (a revive brings a player back with part of it).
func set_health(value: int) -> void:
	if _can_modify():
		current_health = clampi(value, 1, max_health)


## Clients: show the host's value from a snapshot. Never used to decide anything.
func apply_replicated(value: int) -> void:
	current_health = clampi(value, 0, max_health)


func _can_modify() -> bool:
	return multiplayer.is_server()
