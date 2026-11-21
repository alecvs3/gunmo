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

## Seconds the camera takes to catch up with the player. 0 = locked on (no camera lag).
@export_range(0.0, 1.0) var camera_follow_time: float = 0.0

@export_group("Knockback")
## How fast a push dies down (px/s lost per second). 2400 stops a 350 px/s push in ~0.15 s.
@export_range(0.0, 20000.0) var knockback_friction: float = 2400.0
## Share of a push kept when it drives the player into a wall (0..1).
@export_range(0.0, 1.0) var knockback_bounce: float = 0.3
## Multiplier on pushes received (0 = immovable).
@export_range(0.0, 5.0) var knockback_taken: float = 1.0
