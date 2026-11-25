class_name EnemyTrait
extends Resource
## Something an enemy is (Armored, Swarm...) that changes how much of each damage type it
## takes. Real values live in enemies/data/traits/*.tres. An enemy's own traits
## (EnemyData.traits) and its wave's (WaveModifier.adds_traits) all apply: their multipliers
## multiply, so a trait listed twice counts twice.

@export var display_name: String = ""
@export_range(0.05, 5.0) var kinetic: float = 1.0
@export_range(0.05, 5.0) var pierce: float = 1.0
@export_range(0.05, 5.0) var blast: float = 1.0
@export_range(0.05, 5.0) var arcane: float = 1.0


## Damage of `type` it takes is multiplied by this.
func multiplier(type: int) -> float:
	match type:
		DamageType.Type.PIERCE:
			return pierce
		DamageType.Type.BLAST:
			return blast
		DamageType.Type.ARCANE:
			return arcane
	return kinetic


## Pure: what `traits` together do to damage of `type` (1.0 for none).
static func product(traits: Array[EnemyTrait], type: int) -> float:
	var result: float = 1.0
	for each in traits:
		result *= each.multiplier(type)
	return result


## Pure: `product` for every type, indexed by DamageType.Type (HealthComponent.type_multipliers).
static func profile(traits: Array[EnemyTrait]) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for type in DamageType.COUNT:
		result.append(product(traits, type))
	return result
