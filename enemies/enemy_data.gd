class_name EnemyData
extends Resource
## Tuning for one enemy type. Real values live in enemies/data/*.tres.

@export_range(1, 100000) var max_health: int = 1
## Pixels per second.
@export_range(0.0, 2000.0) var move_speed: float = 1.0
## Damage per touch.
@export_range(0, 1000) var contact_damage: int = 1
## Seconds between touches.
@export_range(0.05, 10.0) var contact_interval: float = 1.0
