class_name PlayerStats
extends RefCounted
## Turns base numbers plus upgrade levels into the numbers a player actually uses.
## For each stat the levels of every upgrade on that stat add up into one multiplier
## (1 + sum of per_level × level), applied once to the base value. Pure and deterministic, so
## the host and the predicting owner always compute exactly the same stats.


static func multiplier(
	catalog: ShopCatalog, levels: PackedByteArray, stat: UpgradeData.Stat
) -> float:
	var total: float = 1.0
	for i in mini(catalog.upgrades.size(), levels.size()):
		var upgrade: UpgradeData = catalog.upgrades[i]
		if upgrade.stat == stat:
			total += upgrade.per_level * levels[i]
	return total


## A copy of `base` with the upgrades applied (the shared .tres is never changed).
static func effective_weapon(
	base: WeaponData, catalog: ShopCatalog, levels: PackedByteArray
) -> WeaponData:
	var weapon: WeaponData = base.duplicate()
	var stat := UpgradeData.Stat
	weapon.damage = maxi(roundi(base.damage * multiplier(catalog, levels, stat.DAMAGE)), 1)
	weapon.fire_rate = base.fire_rate * multiplier(catalog, levels, stat.FIRE_RATE)
	var magazine: float = base.magazine_size * multiplier(catalog, levels, stat.MAGAZINE)
	weapon.magazine_size = maxi(roundi(magazine), 1)
	weapon.reload_time = base.reload_time / multiplier(catalog, levels, stat.RELOAD_SPEED)
	weapon.knockback = base.knockback * multiplier(catalog, levels, stat.KNOCKBACK)
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
