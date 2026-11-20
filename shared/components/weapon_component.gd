class_name WeaponComponent
extends Node
## Fire rate, ammo and reloading for one weapon, all read from WeaponData. Runs on the host.
## It decides whether a shot happens; the owner spawns the bullet when `fired` is emitted.

signal fired(origin: Vector2, direction: Vector2)
signal reload_started
signal reloaded

@export var weapon_data: WeaponData

var ammo: int = 0
var _cooldown_left: float = 0.0
var _reload_left: float = 0.0


## Host only: on clients the synchronizer has already applied the host's ammo by now.
func _ready() -> void:
	var is_host: bool = multiplayer.is_server()
	set_physics_process(is_host)
	if is_host:
		ammo = weapon_data.magazine_size


func _physics_process(delta: float) -> void:
	tick(delta)


func is_reloading() -> bool:
	return _reload_left > 0.0


func can_fire() -> bool:
	return ammo > 0 and _cooldown_left <= 0.0 and not is_reloading()


func tick(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if not is_reloading():
		return
	_reload_left -= delta
	if _reload_left <= 0.0:
		_reload_left = 0.0
		ammo = weapon_data.magazine_size
		reloaded.emit()


## Returns true if a shot was fired. An empty magazine starts a reload automatically.
func try_fire(origin: Vector2, aim_direction: Vector2) -> bool:
	if not can_fire():
		if ammo == 0:
			start_reload()
		return false
	ammo -= 1
	_cooldown_left = 1.0 / weapon_data.fire_rate
	fired.emit(origin, spread_direction(aim_direction))
	if ammo == 0:
		start_reload()
	return true


func start_reload() -> void:
	if is_reloading() or ammo == weapon_data.magazine_size:
		return
	_reload_left = weapon_data.reload_time
	reload_started.emit()


## Rotates the aim randomly within +/- half of WeaponData.spread (degrees).
func spread_direction(aim_direction: Vector2) -> Vector2:
	var half_spread: float = deg_to_rad(weapon_data.spread) * 0.5
	return aim_direction.normalized().rotated(randf_range(-half_spread, half_spread))
