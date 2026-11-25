class_name EnemyDash
extends RefCounted
## Host: a Charger's dash (ChargeAttack) as pure rules; the chaser keeps one. It goes straight
## along a locked direction until it hits a player or has gone its full distance (then it
## recovers briefly), or runs head-on into a wall (then it is stunned and takes more damage).
## While busy the enemy neither walks nor starts other attacks.

enum State { IDLE, DASHING, STUNNED, RECOVERING }

## A wall stuns only when hit closer to head-on than this (the wall's normal against the dash
## direction, -1 = straight on); scraping along a wall doesn't.
const HEAD_ON: float = -0.5

var state: State = State.IDLE
## The attack being performed (its numbers), or null before the first dash.
var attack: ChargeAttack
## Which way it dashes (unit length).
var direction: Vector2 = Vector2.ZERO

var _travelled: float = 0.0
var _time_left: float = 0.0


## Starts a dash of `with` towards `towards`.
func start(with: ChargeAttack, towards: Vector2) -> void:
	attack = with
	direction = towards.normalized()
	_travelled = 0.0
	state = State.DASHING


func is_busy() -> bool:
	return state != State.IDLE


func is_dashing() -> bool:
	return state == State.DASHING


func is_stunned() -> bool:
	return state == State.STUNNED


## How fast it moves on its own now (px/s).
func velocity() -> Vector2:
	return direction * attack.dash_speed if is_dashing() else Vector2.ZERO


## It ran into a wall whose surface faces `normal`. True = it is stunned now.
func hit_wall(normal: Vector2) -> bool:
	if not is_dashing() or normal.dot(direction) > HEAD_ON:
		return false
	_finish(State.STUNNED, attack.stun_seconds)
	return true


## It hit a player: the dash ends.
func hit_player() -> void:
	if is_dashing():
		_finish(State.RECOVERING, attack.recover_seconds)


func step(delta: float) -> void:
	if is_dashing():
		_travelled += attack.dash_speed * delta
		if _travelled >= attack.dash_distance:
			_finish(State.RECOVERING, attack.recover_seconds)
	elif is_busy():
		_time_left -= delta
		if _time_left <= 0.0:
			state = State.IDLE


## Multiplier on the damage it takes now.
func damage_factor() -> float:
	return 1.0 + attack.stun_damage_bonus if is_stunned() else 1.0


func _finish(next: State, seconds: float) -> void:
	state = next
	_time_left = seconds
