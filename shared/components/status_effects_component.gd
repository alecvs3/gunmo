class_name StatusEffectsComponent
extends Node
## Timed states a hit can leave on its owner (HitEffects): burning (damage over time, credited
## to whoever lit it), chilled (slower) and shredded (takes more damage from everything,
## burns included). A new hit refreshes the time and keeps the stronger value, so many
## pellets or teammates don't stack one effect without limit.
## Only the host runs the timers; clients just show the flags from snapshots.

## Seconds between burn damage ticks.
const BURN_TICK: float = 0.5

@export var health: HealthComponent
## The most a chill can slow (EnemyData.max_slow).
@export_range(0.0, 1.0) var max_slow: float = 0.6

## HitEffects.BURN / CHILL / SHRED bits that are active now (host: from the timers; clients:
## from snapshots).
var flags: int = 0

var _burn_dps: float = 0.0
var _burn_left: float = 0.0
var _burn_source: int = 0
var _burn_carry: float = 0.0
var _burn_tick_left: float = 0.0
var _slow: float = 0.0
var _chill_left: float = 0.0
var _shred: float = 0.0
var _shred_left: float = 0.0


func _ready() -> void:
	set_physics_process(multiplayer.is_server())


func _physics_process(delta: float) -> void:
	step(delta)


## Host: a hit by `source_id` with these effects.
func apply(effects: HitEffects, source_id: int) -> void:
	if effects == null or (health != null and health.is_dead()):
		return
	if effects.burn_dps > 0.0 and effects.burn_seconds > 0.0:
		if effects.burn_dps >= _burn_dps or _burn_left <= 0.0:
			_burn_dps = effects.burn_dps
			_burn_source = source_id
		_burn_left = maxf(_burn_left, effects.burn_seconds)
	if effects.chill_slow > 0.0 and effects.chill_seconds > 0.0:
		_slow = maxf(_slow if _chill_left > 0.0 else 0.0, minf(effects.chill_slow, max_slow))
		_chill_left = maxf(_chill_left, effects.chill_seconds)
	if effects.shred_bonus > 0.0 and effects.shred_seconds > 0.0:
		_shred = maxf(_shred if _shred_left > 0.0 else 0.0, effects.shred_bonus)
		_shred_left = maxf(_shred_left, effects.shred_seconds)
	_update_flags()


## Host: `delta` seconds pass. Burn damage lands every BURN_TICK.
func step(delta: float) -> void:
	_chill_left = maxf(_chill_left - delta, 0.0)
	_shred_left = maxf(_shred_left - delta, 0.0)
	if _burn_left > 0.0:
		var burning: float = minf(delta, _burn_left)
		_burn_left -= burning
		_burn_carry += _burn_dps * burning
		_burn_tick_left -= delta
		if _burn_tick_left <= 0.0 or _burn_left <= 0.0:
			_burn_tick_left = BURN_TICK
			_deal_burn(_burn_left <= 0.0)
	_update_flags()


func is_burning() -> bool:
	return flags & HitEffects.BURN != 0


## Multiplier on movement speed (1 = not chilled).
func speed_multiplier() -> float:
	return 1.0 - _slow if _chill_left > 0.0 else 1.0


## Multiplier on damage taken (1 = not shredded).
func damage_multiplier() -> float:
	return 1.0 + _shred if _shred_left > 0.0 else 1.0


## Clients: the host's flags from a snapshot.
func show_flags(value: int) -> void:
	flags = value


## `last`: the burn just ran out, so the rest (rounded) lands now.
func _deal_burn(last: bool) -> void:
	var whole: int = roundi(_burn_carry) if last else floori(_burn_carry)
	_burn_carry = 0.0 if last else _burn_carry - whole
	if whole > 0 and health != null:
		health.take_damage(roundi(whole * damage_multiplier()), _burn_source)


func _update_flags() -> void:
	var bits: int = 0
	bits |= HitEffects.BURN if _burn_left > 0.0 else 0
	bits |= HitEffects.CHILL if _chill_left > 0.0 else 0
	bits |= HitEffects.SHRED if _shred_left > 0.0 else 0
	flags = bits
