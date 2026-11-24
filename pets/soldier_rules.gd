class_name SoldierRules
extends RefCounted
## The Soldier's tiers as pure rules (numbers from SoldierData). `tier` = tiers owned.

const DRILL: int = 1
const RALLY: int = 2
const COVER: int = 3
const LAST_STAND: int = 4
const AIRSTRIKE: int = 5


## Tier 1: extra damage for the owner, more from tier 2; tier 4 adds Last Stand while a
## teammate is down.
static func damage_bonus(data: SoldierData, tier: int, teammate_down: bool) -> float:
	if tier < DRILL:
		return 0.0
	var bonus: float = data.drill_bonus_upgraded if tier >= RALLY else data.drill_bonus
	if tier >= LAST_STAND and teammate_down:
		bonus += data.last_stand_damage
	return bonus


## Tier 4: extra move speed while a teammate is down.
static func move_bonus(data: SoldierData, tier: int, teammate_down: bool) -> float:
	return data.last_stand_move if tier >= LAST_STAND and teammate_down else 0.0


## Tier 2: whether this many kills since the last Rally calls one.
static func rally_ready(data: SoldierData, tier: int, kills: int) -> bool:
	return tier >= RALLY and kills >= data.rally_kills


## The fire-rate bonus a Rally gives, more from tier 5.
static func rally_fire_rate(data: SoldierData, tier: int) -> float:
	return data.rally_fire_rate_upgraded if tier >= AIRSTRIKE else data.rally_fire_rate


## Whether the owner's own Rally lifts them too (tier 4).
static func rally_includes_owner(tier: int) -> bool:
	return tier >= LAST_STAND


## Tier 3: the pet's shot damage for the owner's gun damage.
static func cover_damage(data: SoldierData, tier: int, gun_damage: int) -> int:
	if tier < COVER:
		return 0
	return maxi(roundi(gun_damage * data.cover_damage_share), 1)


## Tier 5: whether the owner's recent kill ticks (oldest first) call an airstrike.
static func airstrike_ready(data: SoldierData, tier: int, kill_ticks: Array[int], now: int) -> bool:
	if tier < AIRSTRIKE:
		return false
	var window: int = roundi(data.airstrike_window * NetClock.tick_rate())
	var recent: int = 0
	for tick in kill_ticks:
		if now - tick <= window:
			recent += 1
	return recent >= data.airstrike_kills


## The airstrike's damage in `wave` (a smaller share on bosses).
static func airstrike_damage(data: SoldierData, wave: int, boss: bool) -> int:
	var damage: int = data.airstrike_damage + data.airstrike_damage_per_wave * wave
	return maxi(roundi(damage * (data.airstrike_boss_share if boss else 1.0)), 1)


## Whether a point is under the airstrike's line from `from` to `to` (within `width`).
static func under_strike(at: Vector2, from: Vector2, to: Vector2, width: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(at, from, to).distance_to(at) <= width
