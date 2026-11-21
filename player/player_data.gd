class_name PlayerData
extends Resource
## Tuning for the player character. Real values live in player/data/*.tres.

@export_range(1, 10000) var max_health: int = 1
## Top speed in pixels per second.
@export_range(0.0, 2000.0) var move_speed: float = 1.0
## Draw your own player one tick of motion ahead (about 8 ms fresher; see OwnPlayerDrawing).
@export var draw_ahead: bool = false
## Seconds from standing still to top speed (0 = instant).
@export_range(0.0, 2.0) var acceleration_time: float = 0.0
## Seconds from top speed to a stop after letting go (0 = instant).
@export_range(0.0, 2.0) var deceleration_time: float = 0.0

## Seconds the camera takes to catch up with the player. 0 = locked on (no camera lag).
@export_range(0.0, 1.0) var camera_follow_time: float = 0.0
## Seconds the camera takes to catch up with a teammate you spectate while down.
@export_range(0.0, 1.0) var spectate_follow_time: float = 0.0
## How much of the world everyone sees around their player (world pixels), whatever their
## window's size or shape (FairView). Wider or taller windows get bars, not more map.
@export var view_size: Vector2 = Vector2(1152, 648)

@export_group("Looks")
## Characters for human players, picked by peer id (so every peer picks the same one).
@export var player_looks: Array[CharacterLook] = []
## Characters for bots.
@export var bot_looks: Array[CharacterLook] = []

@export_group("Knockback")
## How fast a push dies down (px/s lost per second). 2400 stops a 350 px/s push in ~0.15 s.
@export_range(0.0, 20000.0) var knockback_friction: float = 2400.0
## Share of a push kept when it drives the player into a wall (0..1).
@export_range(0.0, 1.0) var knockback_bounce: float = 0.3
## Multiplier on pushes received (0 = immovable).
@export_range(0.0, 5.0) var knockback_taken: float = 1.0


## The character for a peer: bots (negative ids) from bot_looks, humans from player_looks.
func look_for(peer_id: int) -> CharacterLook:
	var looks: Array[CharacterLook] = bot_looks if peer_id < 0 else player_looks
	if looks.is_empty():
		return null
	return looks[absi(peer_id) % looks.size()]
