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

@export_group("Knockback")
## Push given to a player it touches (px/s, away from the enemy).
@export_range(0.0, 3000.0) var contact_knockback: float = 0.0
## How fast a push on this enemy dies down (px/s lost per second).
@export_range(0.0, 20000.0) var knockback_friction: float = 2000.0
## Share of a push kept when it drives the enemy into a wall (0..1).
@export_range(0.0, 1.0) var knockback_bounce: float = 0.3
## Multiplier on pushes received (0 = immovable; heavy or "armored" enemies use less).
@export_range(0.0, 5.0) var knockback_taken: float = 1.0
