class_name WaveModifier
extends Resource
## A rule a wave can add to all its enemies ("armored", "fast", "regenerating"...). Real
## values live in modes/waves/data/modifiers/*.tres, listed in the ModifierCatalog. Several can
## be active at once; their multipliers multiply and their regeneration adds up, within the
## catalog's caps. Modifiers named in `conflicts_with` are never picked for the same wave.

@export var display_name: String = ""
## Enemies are tinted toward this color so players can read the wave at a glance.
@export var color: Color = Color.WHITE
@export_range(0.1, 10.0) var health_multiplier: float = 1.0
@export_range(0.1, 10.0) var speed_multiplier: float = 1.0
## Damage of every type enemies take is multiplied by this (1.15 = they take 15% more).
@export_range(0.05, 10.0) var damage_taken_multiplier: float = 1.0
## Traits every enemy of the wave gets on top of its own (enemies/data/traits/): Armored makes
## the whole wave weak to Pierce. Armor a damage type can beat belongs here, not above.
@export var adds_traits: Array[EnemyTrait] = []
## Share of max health healed per second (0.05 = 5%), times each enemy's heal_received.
@export_range(0.0, 1.0) var regen_per_second: float = 0.0
## display_names of modifiers that never share a wave with this one (either side may list it).
@export var conflicts_with: PackedStringArray = []


func conflicts(other: WaveModifier) -> bool:
	return conflicts_with.has(other.display_name) or other.conflicts_with.has(display_name)


## Pure: damage of `type` (a DamageType.Type) enemies take is multiplied by this, on top of
## their own EnemyData.taken.
func taken(type: int) -> float:
	return damage_taken_multiplier * EnemyTrait.product(adds_traits, type)


## An enemy's max health under this modifier (whole points, at least 1).
func scaled_health(base_health: int) -> int:
	return maxi(roundi(base_health * health_multiplier), 1)
