class_name PlayerStats
extends RefCounted
## Turns base numbers plus upgrade levels into the numbers a player actually uses.
## Gun stats: every level adds the gun's own amount (WeaponData "Per upgrade level"), so levels
## carry over to a new gun and give that gun's amounts. Player stats: the levels of every
## upgrade on that stat add up into one multiplier (1 + sum of per_level × level), applied once
## to the base value. Pure and deterministic, so the host and the predicting owner always
## compute exactly the same stats.

## A reload never gets shorter than this (seconds), however many levels.
const MIN_RELOAD_TIME: float = 0.1


static func multiplier(
	catalog: ShopCatalog, levels: PackedByteArray, stat: UpgradeData.Stat
) -> float:
	var total: float = 1.0
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


## A copy of `base` with the upgrades applied (the shared .tres is never changed).
static func effective_weapon(
	base: WeaponData, catalog: ShopCatalog, levels: PackedByteArray
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
	return weapon


static func effective_player(
	base: PlayerData, catalog: ShopCatalog, levels: PackedByteArray
) -> PlayerData:
	var player: PlayerData = base.duplicate()
	var stat := UpgradeData.Stat
	player.move_speed = base.move_speed * multiplier(catalog, levels, stat.MOVE_SPEED)
	var health: float = base.max_health * multiplier(catalog, levels, stat.MAX_HEALTH)
	player.max_health = maxi(roundi(health), 1)
	return player
