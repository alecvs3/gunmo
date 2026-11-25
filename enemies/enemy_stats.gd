class_name EnemyStats
extends RefCounted
## One enemy type's numbers for the wave difficulty score (modes/waves/difficulty/): what it
## can take, deal, heal and add per second, from its own data only (no players, no modifiers).
## Each attack behaviour reports its own part (EnemyAttack.add_stats). A boss's phases count by
## the share of its health they cover; the enemies it splits into count as part of it.
## Values are keyed by name, so a new stat needs no new field: an attack sets it in add_stats
## and an axis reads it from the WaveSheet.

## Effective health against Kinetic damage: max_health / taken(KINETIC). The score never
## depends on the players' guns, so Kinetic is its baseline.
const HEALTH := &"health"
## Effective health × heal_received (what regeneration can restore).
const HEALABLE := &"healable"
## Normal (not boss) bodies, and their effective health (what a support pulse heals).
const BODIES := &"bodies"
const BODY_HEALTH := &"body_health"
## move_speed × body_scale, summed over its bodies (px/s).
const MOVE := &"move"
const MELEE_DPS := &"melee_dps"
## Expected projectile damage per second (shots that can hit).
const RANGED_DPS := &"ranged_dps"
## Share of nearby enemies' max health healed per second.
const HEAL_SHARE := &"heal_share"
## Effective health it adds to the wave per second (summons).
const SUMMONED_HEALTH := &"summoned_health"
## Splits and summons are followed this many levels deep.
const MAX_DEPTH: int = 3

var values: Dictionary[StringName, float] = {}
## Shots of a fan or ring count as landing when within this cone (degrees) around the aim.
var aim_cone_degrees: float = 30.0
## How many splits or summons deep this is (summons of summons stop at MAX_DEPTH).
var depth: int = 0


static func of(data: EnemyData, cone_degrees: float = 30.0, level: int = 0) -> EnemyStats:
	var stats := EnemyStats.new()
	stats.aim_cone_degrees = cone_degrees
	stats.depth = level
	if data == null or level > MAX_DEPTH:
		return stats
	var health: float = data.max_health / data.taken(DamageType.Type.KINETIC)
	stats.add(HEALTH, health)
	stats.add(HEALABLE, health * data.heal_received)
	if not data.is_boss():
		stats.add(BODIES, 1.0)
		stats.add(BODY_HEALTH, health)
	var weights: PackedFloat32Array = phase_weights(data)
	for i in weights.size():
		stats.add(MOVE, weights[i] * data.move_speed * data.speed_in(i) * data.body_scale)
		var attack: EnemyAttack = data.attack_in(i)
		if attack != null:
			attack.add_stats(stats, weights[i])
	if data.split_into != null and data.split_count > 0:
		stats.merge(of(data.split_into, cone_degrees, level + 1), data.split_count)
	return stats


## The share of its health each boss phase covers (from its threshold down to the next one's);
## [1.0] for an enemy without phases.
static func phase_weights(data: EnemyData) -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	if data.phases.is_empty():
		weights.append(1.0)
		return weights
	for i in data.phases.size():
		var below: float = data.phases[i + 1].health_below if i + 1 < data.phases.size() else 0.0
		weights.append(maxf(data.phases[i].health_below - below, 0.0))
	return weights


func value(key: StringName) -> float:
	return values.get(key, 0.0)


func add(key: StringName, amount: float) -> void:
	values[key] = value(key) + amount


## Adds `other`'s values `times` over (an enemy's split children).
func merge(other: EnemyStats, times: float = 1.0) -> void:
	for key in other.values:
		add(key, other.values[key] * times)
