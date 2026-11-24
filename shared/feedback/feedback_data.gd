class_name FeedbackData
extends Resource
## Tuning for the "game feel" effects: hit flashes, damage numbers, death bursts and screen
## shake. Looks only: nothing here changes gameplay.

const DEFAULT_PATH: String = "res://shared/feedback/data/default_feedback.tres"

@export_group("Hit flash")
## Seconds a hit flash takes to fade.
@export_range(0.01, 1.0) var flash_seconds: float = 0.12
## How white the flash starts (0 = no flash, 1 = fully white).
@export_range(0.0, 1.0) var flash_amount: float = 0.85

@export_group("Damage numbers")
@export_range(0.1, 3.0) var number_seconds: float = 0.7
## How far a number rises over its life (pixels).
@export_range(0.0, 200.0) var number_rise: float = 36.0
## Random sideways spread so numbers don't stack (pixels).
@export_range(0.0, 50.0) var number_spread: float = 10.0
@export_range(6, 64) var number_size: int = 16
@export var number_color: Color = Color(1, 1, 1)
## A hit taking at least this share of the enemy's max health is a "big hit".
@export_range(0.01, 1.0) var big_hit_share: float = 0.3
@export_range(6, 96) var big_number_size: int = 26
@export var big_number_color: Color = Color(1, 0.82, 0.25)

@export_group("Death burst")
@export_range(0, 64) var burst_pieces: int = 14
@export_range(0.05, 2.0) var burst_seconds: float = 0.45
## How fast the pieces fly out (pixels per second).
@export_range(0.0, 2000.0) var burst_speed: float = 260.0
## Piece size in pixels for an enemy of scale 1.
@export_range(1.0, 32.0) var burst_piece_size: float = 9.0

@export_group("Screen shake")
## Shake added when your own player is hit (0..1, it adds up and caps at 1).
@export_range(0.0, 1.0) var shake_on_hurt: float = 0.35
## Shake from an explosion right next to you; it fades to 0 at blast_shake_reach × its radius.
@export_range(0.0, 1.0) var shake_on_blast: float = 0.7
@export_range(1.0, 10.0) var blast_shake_reach: float = 3.0
## The largest camera offset at full shake (pixels).
@export_range(0.0, 64.0) var shake_max_offset: float = 12.0
## How much shake fades per second.
@export_range(0.1, 20.0) var shake_decay: float = 2.5


static func load_default() -> FeedbackData:
	return load(DEFAULT_PATH)


## Whether losing `amount` health is a big hit for something with `max_health`.
func is_big_hit(amount: int, max_health: int) -> bool:
	return amount >= ceili(big_hit_share * maxf(max_health, 1.0))


## Shake (0..1) from an explosion of `radius` at `distance` from the camera.
func blast_shake(distance: float, radius: float) -> float:
	var reach: float = maxf(radius * blast_shake_reach, 1.0)
	return shake_on_blast * clampf(1.0 - distance / reach, 0.0, 1.0)
