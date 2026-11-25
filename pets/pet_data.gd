class_name PetData
extends Resource
## A pet: who it is (name, role, colour, how it's drawn) and its five tiers. A pet's ability
## numbers live in its kind's own data (HealerData, ...), so this file is only what the menu
## and the follower need. Real values live in pets/data/*.tres, listed in the PetCatalog.

enum Kind { HEALER, WIZARD, SOLDIER }

const TIERS: int = 5

@export var display_name: String = ""
## One word for the menu ("Support", "Control", "Offense").
@export var role: String = ""
@export_multiline var blurb: String = ""
@export var kind: Kind = Kind.HEALER
@export var color: Color = Color.WHITE
## What kind of damage its abilities deal (enemy traits take more or less of it).
@export var damage_type: DamageType.Type = DamageType.Type.KINETIC
@export var tiers: Array[PetTier] = []


## What the next tier costs when you have `owned` tiers of this pet (-1 = all bought).
func next_price(owned: int) -> int:
	if owned < 0 or owned >= tiers.size():
		return -1
	return tiers[owned].price


## Credits for every tier.
func total_price() -> int:
	var total: int = 0
	for tier in tiers:
		total += tier.price
	return total
