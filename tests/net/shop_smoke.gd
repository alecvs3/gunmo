extends "res://tests/net/smoke_script.gd"
## Headless smoke test of the shop, credits, weapons and wave modifiers with a host and a
## client, using the quick match (1000 starting credits, a modifier from wave 1).
## The client buys the shotgun and a damage level (the host must apply both), then adopts the
## Wizard pet and buys its second tier (the host must apply both and the client see them), tries
## purchases
## the host must refuse, then both clear the waves: the client's shotgun fires 6 pellets per
## trigger pull, its hits are confirmed, it earns credits, and the wave's modifiers reach it.
## The host holds fire in the fight, so the client's shotgun must make the kills (it walks up to
## enemies out of reach). The client stays until the host has checked it and closed the session.
## In the break after wave 1 the client asks for the Path's first node (Fortitude, 1 Core: the
## wave paid 1) and then a second one the host must refuse (one step per break); its snapshot
## must show the node, the Core spent, and +10% max health worked out by its own loadout.
## Usage: -s res://tests/net/shop_smoke.gd -- <shophost|shopclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 110.0
const MATCH_PATH: String = "res://tests/net/data/quick_match.tres"
const SHOTGUN: int = 2
const DAMAGE: int = 0
const KIND_UPGRADE: int = 0
const KIND_WEAPON: int = 1
const KIND_PET: int = 2
const WIZARD: int = 1
const FORTITUDE: int = 0
const QUICK_HANDS: int = 1
## How long each side fights before giving up.
const FIGHT_SECONDS: float = 60.0
## The client walks closer to targets farther than this (the shotgun reaches about 300).
const SHOOT_DISTANCE: float = 150.0

var _state: RefCounted = null
var _predicted: int = 0
var _confirmed: int = 0
var _saw_modifiers: bool = false
var _saw_tinted_enemy: bool = false
var _path_asked: bool = false
var _max_health_before: int = 0


func _initialize() -> void:
	_boot("shophost", 7796, WATCHDOG_SECONDS)


func _run() -> void:
	var bus: Node = root.get_node("EventBus")
	bus.match_state_changed.connect(func(state: RefCounted) -> void: _on_state(state))
	bus.shot_predicted.connect(func(_shot: RefCounted) -> void: _predicted += 1)
	if _role == "shophost":
		await _run_host()
	else:
		await _run_client()
	_finish("")


func _run_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	root.get_node("Main").call("_load_match_settings", MATCH_PATH)
	_check(net.host(_port) == OK, "host() failed")
	await _wait_until(func() -> bool: return net.peers.size() >= 2, 20.0)
	var client_id: int = net.peers.filter(func(id: int) -> bool: return id != 1)[0]
	var bought := func() -> bool: return _loadout_of(client_id) == [SHOTGUN, 1]
	await _wait_until(bought, 15.0)
	var pet_bought := func() -> bool: return _pet_of(client_id) == [WIZARD, 2]
	await _wait_until(pet_bought, 15.0)
	_check(pet_bought.call(), "client's pet not applied on the host: %s" % [_pet_of(client_id)])
	# A Rally on the client that lasts the whole test (the way the Soldier pet gives one).
	var soldier: RefCounted = _mode().get("_powers").get("_soldier")
	soldier.get("_rallied")[client_id] = [1 << 30, 0.3]
	_check(
		bought.call(), "client's purchases not applied on the host: %s" % [_loadout_of(client_id)]
	)
	_mode().call("set_local_ready", true)
	await _fight_until_over()
	_check(_is_phase("VICTORY"), "the team did not clear the waves")
	var path: Array = _path_of(client_id)
	_check(path == [1 << FORTITUDE, 0], "client's Path step not applied on the host: %s" % [path])
	await create_timer(1.0).timeout
	net.leave()
	await create_timer(1.0).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own() != null and _state != null, 15.0)
	await _buy_and_check()
	await _buy_pet_and_check()
	var loadout: Node = _own().get_node("PlayerLoadout")
	var buffed := func() -> bool: return is_equal_approx(loadout.get("fire_rate_bonus"), 0.3)
	await _wait_until(buffed, 5.0)
	_check(buffed.call(), "the host's Rally never reached our own snapshot")
	var rate: float = _own().get_node("WeaponComponent").weapon_data.fire_rate
	_info("rallied fire rate %.2f" % rate)
	await _refused_purchase_check("buying the gun already equipped", KIND_WEAPON, SHOTGUN)
	var hits := root.get_node(_level_path() + "/ProjectileSystem")
	hits.hit_confirmed.connect(func(_key: String, _at: Vector2) -> void: _confirmed += 1)
	_mode().call("set_local_ready", true)
	await _wait_until(func() -> bool: return _is_phase("ACTIVE"), 10.0)
	await _refused_purchase_check("buying during a wave", KIND_UPGRADE, DAMAGE)
	var credits_before: int = _credits()
	await _fight_until_over()
	_info(
		(
			"predicted %d bullets, %d hits confirmed, credits %d -> %d"
			% [_predicted, _confirmed, credits_before, _credits()]
		)
	)
	_check(_predicted >= 6 and _predicted % 6 == 0, "shotgun should fire 6 pellets per shot")
	_check(_confirmed > 0, "no hits confirmed")
	_check(_credits() > credits_before, "kills earned no credits")
	_check(_saw_modifiers, "the wave's modifiers never reached the client")
	_check(_saw_tinted_enemy, "no enemy carried the wave's modifiers")
	_check_path()
	# Stay until the host closes the session: leaving first would remove our player before the
	# host checks our Path.
	await _wait_until(func() -> bool: return not net.peers.has(1), 10.0)


func _buy_and_check() -> void:
	var bus: Node = root.get_node("EventBus")
	bus.shop_purchase_requested.emit(KIND_WEAPON, SHOTGUN)
	bus.shop_purchase_requested.emit(KIND_UPGRADE, DAMAGE)
	var applied := func() -> bool: return _credits() == 600 and _own_loadout() == [SHOTGUN, 1]
	await _wait_until(applied, 10.0)
	_info("after buying: credits %d, loadout %s" % [_credits(), _own_loadout()])
	_check(applied.call(), "purchases not applied (1000 - 300 shotgun - 100 damage = 600)")
	var magazine: int = _own().get_node("WeaponComponent").weapon_data.magazine_size
	_check(magazine == 6, "shotgun magazine expected, got %d" % magazine)


func _refused_purchase_check(what: String, kind: int, index: int) -> void:
	var before: int = _credits()
	root.get_node("EventBus").shop_purchase_requested.emit(kind, index)
	await create_timer(1.0).timeout
	_check(_credits() == before, "the host allowed %s" % what)


## Shoots the nearest enemy until the match is over. The host holds fire (its pistol would kill
## everything before the client's short-range shotgun gets a hit) and keeps everyone alive.
## Enemies chase whichever player is nearest, and the host stands about one shotgun range away,
## so the client walks up to a target that is out of reach instead of firing from the edge.
func _fight_until_over() -> void:
	var time_left: float = FIGHT_SECONDS
	var shooting: bool = _role == "shopclient"
	while time_left > 0.0 and not (_is_phase("VICTORY") or _is_phase("DEFEAT")) and _own() != null:
		if not shooting:
			for player: Node in root.get_node(_level_path() + "/Players").get_children():
				player.get_node("HealthComponent").invulnerable = true
		var command: RefCounted = _input_command_script.new()
		if shooting:
			_aim_at_nearest_enemy(command)
		_own().get_node("PlayerInputSource").scripted = command
		if shooting and _is_phase("BREAK") and not _path_asked:
			_ask_for_path_steps()
		await create_timer(0.1).timeout
		time_left -= 0.1
	if time_left <= 0.0 and _own() != null:
		_report_timeout()
	if _own() != null:
		_own().get_node("PlayerInputSource").scripted = _input_command_script.new()
	await create_timer(1.0).timeout


## Where we and every enemy still in the level stood when the fight ran out of time.
func _report_timeout() -> void:
	var wave: int = _state.wave if _state != null else -1
	_info("fight timed out in wave %d, standing at %s" % [wave, _own().global_position])
	for enemy: Node2D in root.get_node(_level_path() + "/Enemies").get_children():
		_info("  enemy left at %s (visible %s)" % [enemy.global_position, enemy.visible])


## Fires at the nearest enemy, walking towards it while it is farther than SHOOT_DISTANCE.
func _aim_at_nearest_enemy(command: RefCounted) -> void:
	var target: Node2D = _nearest_enemy()
	if target == null:
		return
	var to_target: Vector2 = target.global_position - _own().global_position
	command.aim = to_target.angle()
	command.buttons = _fire_button
	if to_target.length() > SHOOT_DISTANCE:
		command.move = to_target.normalized()
	_saw_tinted_enemy = _saw_tinted_enemy or target.get("modifier_mask") != 0


func _on_state(state: RefCounted) -> void:
	if _state == null or _state.phase != state.phase or _state.wave != state.wave:
		_info(
			(
				"phase %s wave %d (%d alive)"
				% [_phase.find_key(state.phase), state.wave, state.living_count]
			)
		)
	_state = state
	if state.phase == _phase["ACTIVE"] and state.modifier_mask != 0:
		_saw_modifiers = true


func _is_phase(name: String) -> bool:
	return _state != null and _state.phase == _phase[name]


func _mode() -> Node:
	return root.get_node("Main/ModeContainer").get_child(0)


func _player(peer_id: int) -> Node2D:
	return root.get_node_or_null(_level_path() + "/Players/%d" % peer_id) as Node2D


func _own() -> Node2D:
	return _player(root.multiplayer.get_unique_id())


func _loadout_of(peer_id: int) -> Array:
	var player: Node2D = _player(peer_id)
	if player == null:
		return []
	var loadout: Node = player.call("get_loadout")
	return [loadout.get("weapon_index"), loadout.call("level", DAMAGE)]


func _own_loadout() -> Array:
	return _loadout_of(root.multiplayer.get_unique_id())


func _credits() -> int:
	return _own().call("get_wallet").get("credits") if _own() != null else -1


func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var from: Vector2 = _own().global_position
	for enemy: Node2D in root.get_node(_level_path() + "/Enemies").get_children():
		var closer: bool = (
			nearest == null
			or (
				from.distance_squared_to(enemy.global_position)
				< from.distance_squared_to(nearest.global_position)
			)
		)
		if enemy.visible and closer:
			nearest = enemy
	return nearest


## Adopt the Wizard (200) and buy its tier 2 (400): 600 -> 0 credits.
func _buy_pet_and_check() -> void:
	var bus: Node = root.get_node("EventBus")
	bus.shop_purchase_requested.emit(KIND_PET, WIZARD)
	await _wait_until(func() -> bool: return _pet_of(root.multiplayer.get_unique_id())[1] == 1, 5.0)
	bus.shop_purchase_requested.emit(KIND_PET, WIZARD)
	var applied := func() -> bool: return _pet_of(root.multiplayer.get_unique_id()) == [WIZARD, 2]
	await _wait_until(applied, 10.0)
	_info(
		(
			"after the pet: credits %d, pet %s"
			% [_credits(), _pet_of(root.multiplayer.get_unique_id())]
		)
	)
	_check(applied.call(), "the pet purchases did not reach us")
	_check(_credits() == 0, "600 - 200 - 400 = 0 credits, got %d" % _credits())


## In a break: Fortitude (allowed), then Quick hands (refused: this break's step is used).
func _ask_for_path_steps() -> void:
	_path_asked = true
	_max_health_before = _own().get_node("HealthComponent").max_health
	_info("break: asking for Fortitude with %s" % [_path_of(root.multiplayer.get_unique_id())])
	var bus: Node = root.get_node("EventBus")
	bus.path_step_requested.emit(FORTITUDE)
	bus.path_step_requested.emit(QUICK_HANDS)


## Our own snapshot shows the step, and our loadout applies Fortitude itself.
func _check_path() -> void:
	if _own() == null:
		_check(false, "own player gone before the Path check (left the match or the host closed)")
		return
	var path: Array = _path_of(root.multiplayer.get_unique_id())
	var max_health: int = _own().get_node("HealthComponent").max_health
	_info("Path %s, max health %d -> %d" % [path, _max_health_before, max_health])
	_check(_path_asked, "never saw a break to take a Path step in")
	_check(
		path == [1 << FORTITUDE, 0], "expected Fortitude owned and 0 Cores left, got %s" % [path]
	)
	_check(max_health == roundi(_max_health_before * 1.1), "Fortitude should add 10% max health")


## [owned mask, Cores] of a player's Path.
func _path_of(peer_id: int) -> Array:
	var player: Node = root.get_node_or_null(_level_path() + "/Players/%d" % peer_id)
	if player == null:
		return [-1, -1]
	var path: RefCounted = player.get_node("PlayerLoadout").get("path")
	return [path.get("owned"), path.get("cores")]


## [pet index, tier] of a player's loadout.
func _pet_of(peer_id: int) -> Array:
	var player: Node = root.get_node_or_null(_level_path() + "/Players/%d" % peer_id)
	if player == null:
		return [-1, 0]
	var loadout: Node = player.get_node("PlayerLoadout")
	return [loadout.get("pet_index"), loadout.get("pet_tier")]
