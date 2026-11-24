class_name PetCatalog
extends Resource
## Every pet, in a fixed order: pets travel by index (in purchases and the player snapshot), so
## every peer uses the default catalog at DEFAULT_PATH. Append new pets; never reorder.

const DEFAULT_PATH: String = "res://pets/data/pet_catalog.tres"

@export var pets: Array[PetData] = []


static func load_default() -> PetCatalog:
	return load(DEFAULT_PATH)


func is_pet_index(index: int) -> bool:
	return index >= 0 and index < pets.size() and pets[index] != null


func pet(index: int) -> PetData:
	return pets[index] if is_pet_index(index) else null
