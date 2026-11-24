class_name ShopSeen
extends RefCounted
## What the shop showed last refresh: the equipped weapon and every upgrade level. Comparing it
## with the next one tells which purchase the host just confirmed, so only that card or dot pops.

var weapon_index: int = 0
var levels: Array[int] = []


static func from_loadout(loadout: PlayerLoadout, upgrade_count: int) -> ShopSeen:
	var seen := ShopSeen.new()
	seen.weapon_index = loadout.weapon_index
	for i in upgrade_count:
		seen.levels.append(loadout.level(i))
	return seen


## The weapon index bought since this was seen, or -1 if the weapon is the same.
func weapon_bought(now: ShopSeen) -> int:
	return now.weapon_index if now.weapon_index != weapon_index else -1


## Whether upgrade `index` gained a level since this was seen.
func level_bought(now: ShopSeen, index: int) -> bool:
	if index < 0 or index >= levels.size() or index >= now.levels.size():
		return false
	return now.levels[index] > levels[index]
