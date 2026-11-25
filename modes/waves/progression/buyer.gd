class_name Buyer
extends RefCounted
## What a paper player does in a break: one Path step (the first node the rules allow), then
## the shop, in the way their PlayerArchetype spends. Every purchase is checked with ShopRules
## and priced like the game (Path discounts included). A buy's worth is how much it raises
## the player's own progression score against the next wave.

## A safety stop: no break has more purchases than this.
const MAX_BUYS: int = 64


class Option:
	var kind: int = ShopRules.KIND_UPGRADE
	var index: int = 0
	var price: int = 0


## The whole break for `player`, before `next_wave`.
static func take_break(
	player: SimPlayer,
	next_wave: WaveReport.Row,
	difficulty: DifficultyModel,
	model: ProgressionModel,
	settings: MatchSettings
) -> void:
	take_path_step(player)
	var against: WaveReport.Row = next_wave
	if player.archetype.counter_skill < 0.5:
		against = _plain(next_wave)
	var reserve: float = reserve_for(player.archetype, settings)
	for i in MAX_BUYS:
		var choice: Option = pick(player, against, difficulty, model, reserve)
		if choice == null:
			return
		apply(player, choice)


## One Path step: the first node in the tree's order the rules allow now.
static func take_path_step(player: SimPlayer) -> void:
	PathRules.start_break(player.path)
	for i in player.path_tree.nodes.size():
		if PathRules.take(player.path_tree, player.path, i, true):
			return


## Credits a saver keeps back: enough to earn the most interest.
static func reserve_for(who: PlayerArchetype, settings: MatchSettings) -> float:
	if who.spending != PlayerArchetype.Spending.SAVER or settings.interest_per_step <= 0:
		return 0.0
	var steps: int = ceili(float(settings.interest_cap) / settings.interest_per_step)
	return float(steps * settings.interest_step)


## The next purchase (null = nothing affordable helps).
static func pick(
	player: SimPlayer,
	wave: WaveReport.Row,
	difficulty: DifficultyModel,
	model: ProgressionModel,
	reserve: float
) -> Option:
	var base: float = worth(player, wave, difficulty, model)
	var cheapest: bool = player.archetype.spending == PlayerArchetype.Spending.CHEAPEST
	var best: Option = null
	var best_value: float = 0.0
	for option in options(player):
		if option.price > player.credits - reserve:
			continue
		var trial: SimPlayer = player.copy()
		apply(trial, option)
		var gain: float = worth(trial, wave, difficulty, model) - base
		if gain <= 0.0001:
			continue
		var value: float = -option.price if cheapest else gain / maxi(option.price, 1)
		if best == null or value > best_value:
			best = option
			best_value = value
	return best


## Every purchase the shop allows `player` now (credits not checked).
static func options(player: SimPlayer) -> Array[Option]:
	var found: Array[Option] = []
	var catalog: ShopCatalog = player.catalog
	var many: int = 1 << 30
	for i in catalog.upgrades.size():
		if ShopRules.check_upgrade(true, catalog, i, player.levels[i], many).is_empty():
			var price: int = catalog.upgrades[i].cost(player.levels[i], player.shop_discount())
			found.append(_option(ShopRules.KIND_UPGRADE, i, price))
	for i in catalog.weapons.size():
		if ShopRules.check_weapon(true, catalog, i, player.weapon_index, many).is_empty():
			found.append(_option(ShopRules.KIND_WEAPON, i, catalog.weapons[i].price))
	var pet: int = player.pet_index
	if (
		pet >= 0
		and ShopRules.check_pet(true, player.pets, pet, pet, player.pet_tier, many).is_empty()
	):
		var price: int = ShopRules.pet_price(player.pets, pet, pet, player.pet_tier)
		found.append(_option(ShopRules.KIND_PET, pet, price))
	return found


static func apply(player: SimPlayer, option: Option) -> void:
	match option.kind:
		ShopRules.KIND_UPGRADE:
			player.levels[option.index] += 1
		ShopRules.KIND_WEAPON:
			player.weapon_index = option.index
		ShopRules.KIND_PET:
			player.pet_tier += 1
	player.credits -= option.price
	player.spent += option.price


## `player`'s own progression score against `wave`, as a team of one.
static func worth(
	player: SimPlayer, wave: WaveReport.Row, difficulty: DifficultyModel, model: ProgressionModel
) -> float:
	var powers: Array[PlayerPower] = [PlayerPower.of(player, wave, model)]
	return difficulty.length(difficulty.handled_scores(TeamPower.of(powers), model))


static func _option(kind: int, index: int, price: int) -> Option:
	var option := Option.new()
	option.kind = kind
	option.index = index
	option.price = price
	return option


## `wave` without its counters: what a player who ignores the forecast plans for.
static func _plain(wave: WaveReport.Row) -> WaveReport.Row:
	if wave == null:
		return null
	var plain := WaveReport.Row.new()
	plain.wave = wave.wave
	plain.average_health = wave.average_health
	return plain
