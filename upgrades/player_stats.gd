class_name PlayerStats
extends RefCounted
## Turns base numbers plus upgrade levels into the numbers a player actually uses.
## Gun stats: every level adds the gun's own amount (WeaponData "Per upgrade level"), so levels
## carry over to a new gun and give that gun's amounts. Player stats: the levels of every
## upgrade on that stat add up into one multiplier (1 + sum of per_level × level), applied once
## to the base value. Pure and deterministic, so the host and the predicting owner always
## compute exactly the same stats.
## Path bonuses (`bonuses`, one per UpgradeData.Stat, from PathTree.stat_bonuses): on a player
## stat they add to the same multiplier; on a gun stat they scale the result (0.2 on reload
## speed = reload time / 1.2).

## A reload never gets shorter than this (seconds), however many levels.
const MIN_RELOAD_TIME: float = 0.1


static func multiplier(
	catalog: ShopCatalog, levels: PackedByteArray, stat: UpgradeData.Stat, extra: float = 0.0
) -> float:
	var total: float = 1.0 + extra
	for i in mini(catalog.upgrades.size(), levels.size()):
		var upgrade: UpgradeData = catalog.upgrades[i]
		if upgrade.stat == stat:
			total += upgrade.per_level * levels[i]
	return total


## Total levels the player has on `stat` (several upgrades may share a stat).
static func levels_on(catalog: ShopCatalog, levels: PackedByteArray, stat: UpgradeData.Stat) -> int:
	var total: int = 0
	for i in mini(catalog.upgrades.size(), levels.size()):
		if catalog.upgrades[i].stat == stat:
			total += levels[i]
	return total


## The Path's bonus on `stat` (0 when `bonuses` has none).
static func bonus(bonuses: PackedFloat32Array, stat: UpgradeData.Stat) -> float:
	return bonuses[stat] if stat < bonuses.size() else 0.0


## A copy of `base` with the upgrades and Path bonuses applied (the shared .tres is never
## changed).
static func effective_weapon(
	base: WeaponData, catalog: ShopCatalog, levels: PackedByteArray, bonuses := PackedFloat32Array()
) -> WeaponData:
	var weapon: WeaponData = base.duplicate()
	var stat := UpgradeData.Stat
	var damage: int = levels_on(catalog, levels, stat.DAMAGE)
	weapon.damage = base.damage + base.damage_per_level * damage
	weapon.blast_damage = base.blast_damage + base.blast_damage_per_level * damage
	var fire_rate: int = levels_on(catalog, levels, stat.FIRE_RATE)
	weapon.fire_rate = base.fire_rate + base.fire_rate_per_level * fire_rate
	var magazine: int = levels_on(catalog, levels, stat.MAGAZINE)
	weapon.magazine_size = base.magazine_size + base.magazine_per_level * magazine
	var reload: int = levels_on(catalog, levels, stat.RELOAD_SPEED)
	var faster: float = base.reload_per_level * reload
	weapon.reload_time = maxf(base.reload_time - faster, minf(base.reload_time, MIN_RELOAD_TIME))
	var knockback: int = levels_on(catalog, levels, stat.KNOCKBACK)
	weapon.knockback = base.knockback + base.knockback_per_level * knockback
	if not bonuses.is_empty():
		_apply_weapon_bonuses(weapon, bonuses)
	return weapon


static func _apply_weapon_bonuses(weapon: WeaponData, bonuses: PackedFloat32Array) -> void:
	var stat := UpgradeData.Stat
	var damage: float = 1.0 + bonus(bonuses, stat.DAMAGE)
	weapon.damage = roundi(weapon.damage * damage)
	weapon.blast_damage = roundi(weapon.blast_damage * damage)
	weapon.fire_rate *= 1.0 + bonus(bonuses, stat.FIRE_RATE)
	weapon.magazine_size = roundi(weapon.magazine_size * (1.0 + bonus(bonuses, stat.MAGAZINE)))
	var reload: float = weapon.reload_time / (1.0 + bonus(bonuses, stat.RELOAD_SPEED))
	weapon.reload_time = maxf(reload, minf(weapon.reload_time, MIN_RELOAD_TIME))
	weapon.knockback *= 1.0 + bonus(bonuses, stat.KNOCKBACK)


static func effective_player(
	base: PlayerData, catalog: ShopCatalog, levels: PackedByteArray, bonuses := PackedFloat32Array()
) -> PlayerData:
	var player: PlayerData = base.duplicate()
	var stat := UpgradeData.Stat
	var move: float = multiplier(catalog, levels, stat.MOVE_SPEED, bonus(bonuses, stat.MOVE_SPEED))
	player.move_speed = base.move_speed * move
	var more_health: float = bonus(bonuses, stat.MAX_HEALTH)
	var health: float = base.max_health * multiplier(catalog, levels, stat.MAX_HEALTH, more_health)
	player.max_health = maxi(roundi(health), 1)
	return player
