class_name EnemyStatus
extends RefCounted
## What pets have done to an enemy, as pure rules (the host's chaser keeps one): slowed (it
## moves slower until a tick) and hexed (it takes more damage until a tick). A new slow or hex
## keeps the stronger effect and the later end. Clients only see the flags (the enemy snapshot).

const FLAG_SLOWED: int = 1
const FLAG_HEXED: int = 2

var _slow_until: int = 0
var _slow: float = 0.0
var _hex_until: int = 0
var _hex: float = 0.0


## Slowed by `share` (0.35 = 35% slower) until `until` (a host tick).
func slow(share: float, until: int, now: int) -> void:
	if now >= _slow_until:
		_slow = 0.0
	_slow = maxf(_slow, clampf(share, 0.0, 0.9))
	_slow_until = maxi(_slow_until, until)


## Takes `bonus` more damage (0.2 = +20%) until `until`.
func hex(bonus: float, until: int, now: int) -> void:
	if now >= _hex_until:
		_hex = 0.0
	_hex = maxf(_hex, maxf(bonus, 0.0))
	_hex_until = maxi(_hex_until, until)


func is_slowed(now: int) -> bool:
	return now < _slow_until


func is_hexed(now: int) -> bool:
	return now < _hex_until


## Multiplier on its speed now.
func speed_factor(now: int) -> float:
	return 1.0 - _slow if is_slowed(now) else 1.0


## Multiplier on the damage it takes now.
func damage_factor(now: int) -> float:
	return 1.0 + _hex if is_hexed(now) else 1.0


## FLAG_* bits for the snapshot.
func flags(now: int) -> int:
	return (FLAG_SLOWED if is_slowed(now) else 0) | (FLAG_HEXED if is_hexed(now) else 0)
