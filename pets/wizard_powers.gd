class_name WizardPowers
extends RefCounted
## Host: the Wizard's abilities (PetPowers owns one). Arcs on its owner's hits; on timers per
## owner it drops frost runes, hexes the toughest enemy and calls the tempest. WizardRules
## decides; this applies the result to enemies (EnemyStatus, damage through their hitboxes, so
## kills and bounties go to the owner) and shows it to everyone (PetEffects).

var _level: Level
var _rng := RandomNumberGenerator.new()
## peer id -> next tick each ability may fire: {"arc", "rune", "hex", "tempest"}.
var _ready_at: Dictionary = {}
## Tempest strikes waiting for their warning to run out: [tick, owner id, enemies].
var _pending: Array[Array] = []
## True while dealing arc or tempest damage, so that damage doesn't arc again.
var _dealing: bool = false


func _init(level: Level) -> void:
	_level = level
	_rng.randomize()


## The Wizard data and tier of a player (tier 0 = no Wizard).
static func wizard_of(player: Player) -> Array:
	if player == null:
		return [null, 0]
	var data := player.get_loadout().pet() as WizardData
	return [data, player.get_loadout().pet_tier if data != null else 0]


## Arc Spark: the owner's hit on `enemy` may arc to the enemies around it.
func on_hit(player: Player, enemy: ChaserEnemy, amount: int, now: int) -> void:
	var wizard: Array = wizard_of(player)
	if _dealing or wizard[0] == null or enemy == null:
		return
	var data: WizardData = wizard[0]
	var tier: int = wizard[1]
	var timers: Dictionary = _timers(player.peer_id)
	if now < timers["arc"] or _rng.randf() >= WizardRules.arc_chance(data, tier):
		return
	timers["arc"] = now + _ticks(data.arc_cooldown)
	var origin: ChaserEnemy = _hexed_near(enemy, data.arc_radius * 2.0, now)
	var others: Array[ChaserEnemy] = _enemies_except(origin)
	var places: Array[Vector2] = []
	for other in others:
		places.append(other.global_position)
	var jumps: int = WizardRules.arc_jumps(data, tier, origin.status.is_slowed(now))
	var path := PackedVector2Array([enemy.global_position, origin.global_position])
	for index in WizardRules.chain(origin.global_position, places, jumps, data.arc_radius):
		var target: ChaserEnemy = others[index]
		var slowed: bool = target.status.is_slowed(now)
		_deal(target, WizardRules.arc_damage(data, tier, amount, slowed), player.peer_id)
		path.append(places[index])
	if path.size() > 2:
		PetEffects.broadcast(PetEffects.Kind.ARC, path, 0.0, 0.25)


## Runes, hexes and the tempest on their timers; strikes whose warning has run out.
func tick(players: Array[Player], now: int) -> void:
	for player in players:
		var wizard: Array = wizard_of(player)
		if wizard[0] != null and player.is_alive:
			_cast(player, wizard[0], wizard[1], now)
	_strike_due(now)


func clear() -> void:
	_pending.clear()


func _cast(player: Player, data: WizardData, tier: int, now: int) -> void:
	var timers: Dictionary = _timers(player.peer_id)
	var rune: float = WizardRules.rune_interval(data, tier)
	if rune > 0.0 and now >= timers["rune"] and _drop_rune(player, data, now):
		timers["rune"] = now + _ticks(rune)
	var hex: float = WizardRules.hex_interval(data, tier)
	if hex > 0.0 and now >= timers["hex"] and _hex(player, data, now):
		timers["hex"] = now + _ticks(hex)
	var tempest: float = WizardRules.tempest_interval(data, tier)
	if tempest > 0.0 and now >= timers["tempest"] and _call_tempest(player, data, now):
		timers["tempest"] = now + _ticks(tempest)


func _drop_rune(player: Player, data: WizardData, now: int) -> bool:
	var near: Array[ChaserEnemy] = _enemies_near(player.global_position, data.rune_reach)
	if near.is_empty():
		return false
	var places: Array[Vector2] = []
	for enemy in near:
		places.append(enemy.global_position)
	var at: Vector2 = WizardRules.densest(places, data.rune_radius)
	for enemy in _enemies_near(at, data.rune_radius):
		enemy.status.slow(data.rune_slow, now + _ticks(data.rune_seconds), now)
	PetEffects.broadcast(
		PetEffects.Kind.RUNE, PackedVector2Array([at]), data.rune_radius, data.rune_seconds
	)
	return true


func _hex(player: Player, data: WizardData, now: int) -> bool:
	var near: Array[ChaserEnemy] = _enemies_near(player.global_position, data.hex_reach)
	if near.is_empty():
		return false
	var healths: Array[int] = []
	var bosses: Array[bool] = []
	for enemy in near:
		healths.append(enemy.max_health())
		bosses.append(enemy.enemy_data.is_boss())
	var target: ChaserEnemy = near[WizardRules.toughest(healths, bosses)]
	target.status.hex(data.hex_bonus, now + _ticks(data.hex_seconds), now)
	PetEffects.broadcast(PetEffects.Kind.HEX, PackedVector2Array([target.global_position]), 36.0)
	return true


func _call_tempest(player: Player, data: WizardData, now: int) -> bool:
	var near: Array[ChaserEnemy] = _enemies_near(player.global_position, data.tempest_reach)
	if near.is_empty():
		return false
	near.shuffle()
	var struck: Array[ChaserEnemy] = near.slice(0, data.tempest_bolts)
	var places := PackedVector2Array()
	for enemy in struck:
		places.append(enemy.global_position)
	PetEffects.broadcast(PetEffects.Kind.TEMPEST_WARNING, places, 30.0, data.tempest_warning)
	_pending.append([now + _ticks(data.tempest_warning), player.peer_id, struck])
	return true


func _strike_due(now: int) -> void:
	var still: Array[Array] = []
	for strike in _pending:
		if now < strike[0]:
			still.append(strike)
			continue
		var owner: Player = _level.player(strike[1])
		var wizard: Array = wizard_of(owner)
		if wizard[0] == null:
			continue
		for enemy: ChaserEnemy in strike[2]:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				var boss: bool = enemy.enemy_data.is_boss()
				_deal(
					enemy,
					WizardRules.tempest_damage(wizard[0], enemy.max_health(), boss),
					strike[1]
				)
				var sky: Vector2 = enemy.global_position + Vector2(0, -220)
				PetEffects.broadcast(
					PetEffects.Kind.ARC, PackedVector2Array([sky, enemy.global_position]), 0.0, 0.3
				)
	_pending = still


func _deal(enemy: ChaserEnemy, damage: int, owner_id: int) -> void:
	_dealing = true
	enemy.hitbox().hit(damage, owner_id)
	_dealing = false


## The hexed enemy within `reach` of `enemy` (arcs start there), else `enemy` itself.
func _hexed_near(enemy: ChaserEnemy, reach: float, now: int) -> ChaserEnemy:
	for other in _enemies_near(enemy.global_position, reach):
		if other.status.is_hexed(now):
			return other
	return enemy


func _enemies_near(at: Vector2, reach: float) -> Array[ChaserEnemy]:
	var found: Array[ChaserEnemy] = []
	for other in _enemies_except(null):
		if other.global_position.distance_to(at) <= reach:
			found.append(other)
	return found


func _enemies_except(skip: ChaserEnemy) -> Array[ChaserEnemy]:
	var found: Array[ChaserEnemy] = []
	for node in _level.get_tree().get_nodes_in_group(Groups.ENEMIES):
		var enemy := node as ChaserEnemy
		if enemy != null and enemy != skip and not enemy.is_queued_for_deletion():
			found.append(enemy)
	return found


func _timers(peer_id: int) -> Dictionary:
	if not _ready_at.has(peer_id):
		_ready_at[peer_id] = {"arc": 0, "rune": 0, "hex": 0, "tempest": 0}
	return _ready_at[peer_id]


static func _ticks(seconds: float) -> int:
	return roundi(seconds * NetClock.tick_rate())
