class_name SoldierPowers
extends RefCounted
## Host: the Soldier's abilities (PetPowers owns one). Counts its owner's kills for Rally and
## the Airstrike, keeps everyone's buffs current every tick (fire rate and move speed through
## the loadout, which the snapshot carries to the predicting owner; damage on the host), and
## fires the pet's covering shots. SoldierRules decides; this applies it.

var wave: int = 0

var _level: Level
## peer id -> kills since their last Rally; peer id -> recent kill ticks (Airstrike).
var _kills_since: Dictionary = {}
var _kill_ticks: Dictionary = {}
## peer id -> [tick the Rally on them ends, its fire-rate bonus].
var _rallied: Dictionary = {}
## peer id -> next tick their pet may shoot.
var _cover_ready: Dictionary = {}
## Airstrikes waiting for their warning: [tick, owner id, from, to].
var _pending: Array[Array] = []


func _init(level: Level) -> void:
	_level = level


static func soldier_of(player: Player) -> Array:
	if player == null:
		return [null, 0]
	var data := player.get_loadout().pet() as SoldierData
	return [data, player.get_loadout().pet_tier if data != null else 0]


func on_kill(killer: Player, now: int) -> void:
	var soldier: Array = soldier_of(killer)
	if soldier[0] == null:
		return
	var data: SoldierData = soldier[0]
	var id: int = killer.peer_id
	_kills_since[id] = _kills_since.get(id, 0) + 1
	if SoldierRules.rally_ready(data, soldier[1], _kills_since[id]):
		_kills_since[id] = 0
		_rally(killer, data, soldier[1], now)
	var ticks: Array[int] = []
	ticks.assign(_kill_ticks.get(id, []))
	ticks.append(now)
	_kill_ticks[id] = ticks.slice(-data.airstrike_kills)
	if SoldierRules.airstrike_ready(data, soldier[1], _kill_ticks[id], now):
		_kill_ticks[id] = [] as Array[int]
		_call_airstrike(killer, data, now)


## Every tick: buffs on everyone, covering fire, airstrikes whose warning ran out.
func tick(players: Array[Player], now: int) -> void:
	var someone_down: bool = players.any(func(p: Player) -> bool: return p.is_downed())
	for player in players:
		_update_buffs(player, now, someone_down)
		var soldier: Array = soldier_of(player)
		if soldier[0] != null and player.is_alive:
			_cover(player, soldier[0], soldier[1], now)
	_strike_due(now)


func clear() -> void:
	_pending.clear()


func _update_buffs(player: Player, now: int, someone_down: bool) -> void:
	var soldier: Array = soldier_of(player)
	var teammate_down: bool = someone_down and not player.is_downed()
	var damage: float = 0.0
	var move: float = 0.0
	if soldier[0] != null:
		damage = SoldierRules.damage_bonus(soldier[0], soldier[1], teammate_down)
		move = SoldierRules.move_bonus(soldier[0], soldier[1], teammate_down)
	var rally: Array = _rallied.get(player.peer_id, [0, 0.0])
	var fire: float = rally[1] if now < rally[0] else 0.0
	player.damage_bonus = damage
	player.get_loadout().set_buffs(fire, move)


func _rally(owner: Player, data: SoldierData, tier: int, now: int) -> void:
	var until: int = now + roundi(data.rally_seconds * NetClock.tick_rate())
	var bonus: float = SoldierRules.rally_fire_rate(data, tier)
	var places := PackedVector2Array()
	for player in _level.players():
		if not player.is_alive or (player == owner and not SoldierRules.rally_includes_owner(tier)):
			continue
		if player.global_position.distance_to(owner.global_position) > data.rally_reach:
			continue
		var old: Array = _rallied.get(player.peer_id, [0, 0.0])
		_rallied[player.peer_id] = [maxi(old[0], until), maxf(old[1], bonus)]
		places.append(player.global_position)
	if not places.is_empty():
		PetEffects.broadcast(PetEffects.Kind.RALLY, places, 34.0, 0.6)


func _cover(player: Player, data: SoldierData, tier: int, now: int) -> void:
	if tier < SoldierRules.COVER or now < _cover_ready.get(player.peer_id, 0):
		return
	var target: ChaserEnemy = _nearest_enemy(player, data.cover_reach)
	if target == null:
		return
	_cover_ready[player.peer_id] = now + roundi(data.cover_interval * NetClock.tick_rate())
	var gun: int = player.get_loadout().weapon.weapon_data.damage
	target.hitbox().hit(SoldierRules.cover_damage(data, tier, gun), player.peer_id)
	var muzzle: Vector2 = player.global_position + PetFollower.OFFSET
	PetEffects.broadcast(
		PetEffects.Kind.TRACER, PackedVector2Array([muzzle, target.global_position]), 2.0, 0.12
	)


func _call_airstrike(owner: Player, data: SoldierData, now: int) -> void:
	var places: Array[Vector2] = []
	for node in _level.get_tree().get_nodes_in_group(Groups.ENEMIES):
		var enemy := node as ChaserEnemy
		if (
			enemy != null
			and enemy.global_position.distance_to(owner.global_position) < data.airstrike_length
		):
			places.append(enemy.global_position)
	var toward: Vector2 = WizardRules.densest(places, data.airstrike_width * 2.0)
	var direction: Vector2 = Vector2.from_angle(owner.aim)
	if toward != Vector2.INF and not toward.is_equal_approx(owner.global_position):
		direction = owner.global_position.direction_to(toward)
	var from: Vector2 = owner.global_position + direction * 60.0
	var to: Vector2 = from + direction * data.airstrike_length
	var ends := PackedVector2Array([from, to])
	PetEffects.broadcast(
		PetEffects.Kind.STRIKE_WARNING, ends, data.airstrike_width, data.airstrike_warning
	)
	var due: int = now + roundi(data.airstrike_warning * NetClock.tick_rate())
	_pending.append([due, owner.peer_id, from, to])


func _strike_due(now: int) -> void:
	var still: Array[Array] = []
	for strike in _pending:
		if now < strike[0]:
			still.append(strike)
			continue
		var soldier: Array = soldier_of(_level.player(strike[1]))
		if soldier[0] == null:
			continue
		var data: SoldierData = soldier[0]
		PetEffects.broadcast(
			PetEffects.Kind.STRIKE,
			PackedVector2Array([strike[2], strike[3]]),
			data.airstrike_width,
			0.4
		)
		for node in _level.get_tree().get_nodes_in_group(Groups.ENEMIES):
			var enemy := node as ChaserEnemy
			if enemy == null or enemy.is_queued_for_deletion():
				continue
			if SoldierRules.under_strike(
				enemy.global_position, strike[2], strike[3], data.airstrike_width
			):
				var damage: int = SoldierRules.airstrike_damage(
					data, wave, enemy.enemy_data.is_boss()
				)
				enemy.hitbox().hit(damage, strike[1])
	_pending = still


func _nearest_enemy(player: Player, reach: float) -> ChaserEnemy:
	var best: ChaserEnemy = null
	var best_distance: float = reach
	for node in _level.get_tree().get_nodes_in_group(Groups.ENEMIES):
		var enemy := node as ChaserEnemy
		if enemy == null or enemy.is_queued_for_deletion():
			continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance <= best_distance and _clear_line(player.global_position, enemy.global_position):
			best = enemy
			best_distance = distance
	return best


func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, Bullet.WORLD_MASK)
	return _level.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
