class_name WeaponComponent
extends Node
## Fire rate, ammo and reloading for one weapon, all read from WeaponData.
## Stepped exactly once per input command, on the host and on the predicting owner alike, so
## both agree on when shots happen; restore() rewinds it to the host's numbers so the owner can
## replay unconfirmed commands. Spread is random but seeded per shot, so both sides draw the
## same bullet path.

## Timers below this count as finished, so float rounding can't add a tick to the fire rate
## (4 shots/s must be exactly every 15 ticks at 60 Hz).
const TIME_EPSILON: float = 0.000001

@export var weapon_data: WeaponData

var ammo: int = 0
var cooldown_left: float = 0.0
var reload_left: float = 0.0


func _ready() -> void:
	ammo = weapon_data.magazine_size


## The same seed on every peer for the same shot.
static func shot_seed(shooter_id: int, shot_id: int) -> int:
	return hash([shooter_id, shot_id])


## Switch to another weapon: full magazine, no cooldown or reload in progress.
func equip(data: WeaponData) -> void:
	weapon_data = data
	ammo = data.magazine_size
	cooldown_left = 0.0
	reload_left = 0.0


func is_reloading() -> bool:
	return reload_left > TIME_EPSILON


## 0..1 through the current reload (0 when not reloading). For the HUD.
func reload_progress() -> float:
	if not is_reloading() or weapon_data.reload_time <= 0.0:
		return 0.0
	return 1.0 - reload_left / weapon_data.reload_time


func can_fire() -> bool:
	return ammo > 0 and cooldown_left <= TIME_EPSILON and not is_reloading()


## One tick of time with these buttons held. Returns true if a shot was fired.
## An empty magazine starts a reload automatically.
func step(delta: float, wants_fire: bool, wants_reload: bool) -> bool:
	_advance_timers(delta)
	if wants_reload:
		start_reload()
	if not wants_fire:
		return false
	if not can_fire():
		if ammo == 0:
			start_reload()
		return false
	ammo -= 1
	cooldown_left = 1.0 / weapon_data.fire_rate
	if ammo == 0:
		start_reload()
	return true


func start_reload() -> void:
	if is_reloading() or ammo == weapon_data.magazine_size:
		return
	reload_left = weapon_data.reload_time


## Back to the host's numbers (prediction replay).
func restore(state_ammo: int, state_cooldown: float, state_reload: float) -> void:
	ammo = state_ammo
	cooldown_left = state_cooldown
	reload_left = state_reload


## The aim rotated by a random angle within +/- half of WeaponData.spread (degrees).
func spread_direction(aim_direction: Vector2, seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half_spread: float = deg_to_rad(weapon_data.spread) * 0.5
	return aim_direction.normalized().rotated(rng.randf_range(-half_spread, half_spread))


func _advance_timers(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if not is_reloading():
		return
	reload_left -= delta
	if reload_left <= TIME_EPSILON:
		reload_left = 0.0
		ammo = weapon_data.magazine_size
