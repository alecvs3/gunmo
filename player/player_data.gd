class_name PlayerData
extends Resource
## Tuning for the player character. Real values live in player/data/*.tres.

@export_range(1, 10000) var max_health: int = 1
## Pixels per second.
@export_range(0.0, 2000.0) var move_speed: float = 1.0
