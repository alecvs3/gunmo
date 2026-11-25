class_name PlayerPower
extends RefCounted
## One paper player's strength against one wave, in the units the difficulty axes read:
## damage per second (counted as Kinetic, so it compares with the Kinetic-based toughness),
## health a wave can take away, and movement. Skill (PlayerArchetype) and the pet are in it.
## These are estimates (ProgressionModel), not the game; the pet's part is PetPower.

## Damage per second: gun and pet, after aim, uptime, counters and going down.
var dps: float = 0.0
## The part of dps that comes in bursts (airstrikes, Tempest).
var burst_dps: float = 0.0
## Health a wave can take before the player goes down, against melee and against shots.
var melee_health: float = 0.0
var ranged_health: float = 0.0
## Move speed over ProgressionModel.reference_speed.
var mobility: float = 0.0
## Team effects of the pet (the strongest of each counts once per team, TeamPower).
var team_fire_rate: float = 0.0
var team_damage: float = 0.0
var team_slow: float = 0.0
var team_heal: float = 0.0


## `player` against `wave` (its counter profile and average health; null = a plain wave).
static func of(player: SimPlayer, wave: WaveReport.Row, model: ProgressionModel) -> PlayerPower:
	var power := PlayerPower.new()
	var weapon: WeaponData = player.weapon()
	var who: PlayerArchetype = player.archetype
	var aim: float = who.accuracy * who.uptime
	var gun: float = gun_dps(weapon, model) * aim * type_factor(wave, weapon.damage_type)
	PetPower.add(power, player, weapon, wave, model)
	power.dps = gun * (1.0 + PetPower.own_damage(player)) + power.dps
	_add_health(power, player, weapon, model)
	power.mobility = player.stats().move_speed / model.reference_speed
	_apply_downs(power, player, model)
	return power


## Sustained damage per second of `weapon`, reloads included, every shot landing.
static func gun_dps(weapon: WeaponData, model: ProgressionModel) -> float:
	var hit: float = weapon.damage * weapon.pellets * (1.0 + weapon.pierce * model.pierce_targets)
	if weapon.explodes():
		hit += weapon.blast_damage * (1.0 + model.blast_targets)
	var shots: float = weapon.magazine_size
	var cycle: float = shots / weapon.fire_rate + weapon.reload_time
	return hit * shots / cycle if cycle > 0.0 else 0.0


## What `damage_type` is worth against `wave` compared with Kinetic (1 = the same).
static func type_factor(wave: WaveReport.Row, damage_type: int) -> float:
	if wave == null or wave.counter == null:
		return 1.0
	var kinetic: float = wave.counter.multiplier(DamageType.Type.KINETIC)
	return wave.counter.multiplier(damage_type) / kinetic if kinetic > 0.0 else 1.0


static func _add_health(
	power: PlayerPower, player: SimPlayer, weapon: WeaponData, model: ProgressionModel
) -> void:
	var dodge: float = player.archetype.dodge
	var health: float = (
		player.stats().max_health * (1.0 + PetPower.heal_share(player, power, model))
	)
	var knockback: float = 1.0 + weapon.knockback / model.knockback_reference
	power.melee_health = health * knockback / (1.0 - dodge * model.melee_dodge)
	power.ranged_health = health / (1.0 - dodge)


## A player who goes down misses part of the wave.
static func _apply_downs(power: PlayerPower, player: SimPlayer, model: ProgressionModel) -> void:
	var down: float = player.archetype.down_chance * (1.0 - PetPower.down_cut(player, model))
	var present: float = 1.0 - down * model.down_cost
	power.dps *= present
	power.burst_dps *= present
	power.melee_health *= present
	power.ranged_health *= present
	power.mobility *= present


## The chance this player is standing at the end of a wave (clear bonus, interest).
static func standing(player: SimPlayer, model: ProgressionModel) -> float:
	return 1.0 - player.archetype.down_chance * (1.0 - PetPower.down_cut(player, model))
