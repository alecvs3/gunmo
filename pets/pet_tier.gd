class_name PetTier
extends Resource
## One of a pet's five tiers: the ability it adds (or what it improves), and what it costs.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(0, 100000) var price: int = 0
