class_name DamageType
extends RefCounted
## The kinds of damage a hit can deal. A weapon (WeaponData.damage_type) or a pet picks one;
## enemy traits (EnemyTrait) take more or less of each. Host only: the type is never sent.
## Append new types at the end (recipe add-damage-type): traits and data name them by number.

enum Type { KINETIC, PIERCE, BLAST, ARCANE }

## How many types there are (the size of a per-type multiplier list).
const COUNT: int = 4
const NAMES: PackedStringArray = ["Kinetic", "Pierce", "Blast", "Arcane"]


## "Pierce" for the HUD.
static func name_of(type: int) -> String:
	return NAMES[type]
