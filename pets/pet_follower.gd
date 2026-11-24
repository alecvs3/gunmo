class_name PetFollower
extends Node2D
## Every peer: draws its owner player's pet floating behind them (PetLook), easing after them
## as they move. Nothing is sent for it: the pet and tier come from the owner's replicated
## loadout. Hidden while the player has no pet or isn't shown. Looks only.

## Where it floats, relative to its owner (px), and how quickly it catches up (1/s).
const OFFSET := Vector2(-30, -30)
const FOLLOW_RATE: float = 6.0
const RADIUS: float = 11.0

var _owner: Player
var _time: float = 0.0
var _pet: PetData = null
var _tier: int = -1


func _ready() -> void:
	_owner = get_parent() as Player
	top_level = true
	z_index = 5
	if _owner != null:
		global_position = _owner.global_position + OFFSET


func _process(delta: float) -> void:
	if _owner == null:
		return
	var loadout: PlayerLoadout = _owner.get_loadout()
	_pet = loadout.pet()
	_tier = loadout.pet_tier
	visible = _pet != null and _owner.visible
	if not visible:
		return
	_time += delta
	var goal: Vector2 = _owner.global_position + OFFSET
	global_position = global_position.lerp(goal, 1.0 - exp(-FOLLOW_RATE * delta))
	queue_redraw()


func _draw() -> void:
	if _pet != null:
		PetLook.draw(self, _pet, _tier, Vector2.ZERO, RADIUS, _time)
