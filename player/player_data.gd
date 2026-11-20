class_name PlayerData
extends Resource
## Tuning for the player character. Real values live in player/data/*.tres.

@export_range(1, 10000) var max_health: int = 1
## Top speed in pixels per second.
@export_range(0.0, 2000.0) var move_speed: float = 1.0
## Seconds from standing still to top speed (0 = instant).
@export_range(0.0, 2.0) var acceleration_time: float = 0.0
## Seconds from top speed to a stop after letting go (0 = instant).
@export_range(0.0, 2.0) var deceleration_time: float = 0.0
