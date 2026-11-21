extends SceneTree
## Headless smoke test of the shop, credits, weapons and wave modifiers with a host and a
## client, using the quick match (1000 starting credits, a modifier from wave 1).
## The client buys the shotgun and a damage level (the host must apply both), tries purchases
## the host must refuse, then both clear the waves: the client's shotgun fires 6 pellets per
## trigger pull, its hits are confirmed, it earns credits, and the wave's modifiers reach it.
## Usage: -s res://tests/net/shop_smoke.gd -- <shophost|shopclient> <port>
## It runs before the autoloads exist, so it names no project classes directly.

const WATCHDOG_SECONDS: float = 110.0
const MATCH_PATH: String = "res://tests/net/data/quick_match.tres"
const SHOTGUN: int = 2
const DAMAGE: int = 0
const KIND_UPGRADE: int = 0
const KIND_WEAPON: int = 1

var _role: String = ""
var _port: int = 7796
var _failures := PackedStringArray()
var _finished: bool = false
var _state: RefCounted = null
var _phase: Dictionary = {}
var _fire_button: int = 0
var _input_command_script: GDScript
var _predicted: int = 0
var _confirmed: int = 0
var _saw_modifiers: bool = false
var _saw_tinted_enemy: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_role = args[0] if args.size() > 0 else "shophost"
	_port = args[1].to_int() if args.size() > 1 else _port
	root.add_child(load("res://main.tscn").instantiate())
	create_timer(WATCHDOG_SECONDS).timeout.connect(_finish.bind("watchdog timeout"))
	_run.call_deferred()


func _run() -> void:
	_phase = load("res://modes/game_mode.gd").get_script_constant_map()["Phase"]
	_input_command_script = load("res://shared/network/input_command.gd")
	_fire_button = _input_command_script.get_script_constant_map()["FIRE"]
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
	_check(
		bought.call(), "client's purchases not applied on the host: %s" % [_loadout_of(client_id)]
	)
	_mode().call("set_local_ready", true)
	await _fight_until_over()
	_check(_is_phase("VICTORY"), "the team did not clear the waves")
	await create_timer(1.0).timeout
	net.leave()
	await create_timer(1.0).timeout


func _run_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	await create_timer(1.0).timeout
	_check(net.join("127.0.0.1", _port) == OK, "join() failed")
	await _wait_until(func() -> bool: return _own() != null and _state != null, 15.0)
	await _buy_and_check()
	await _refused_purchase_check("buying the gun already equipped", KIND_WEAPON, SHOTGUN)
	var hits := root.get_node("Main/LevelContainer/TestArena/ProjectileSystem")
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


## Shoots the nearest enemy until the match is won or lost.
func _fight_until_over() -> void:
	var time_left: float = 60.0
	while time_left > 0.0 and not (_is_phase("VICTORY") or _is_phase("DEFEAT")) and _own() != null:
		var target: Node2D = _nearest_enemy()
		var command: RefCounted = _input_command_script.new()
		if target != null:
			command.aim = (target.global_position - _own().global_position).angle()
			command.buttons = _fire_button
			_saw_tinted_enemy = _saw_tinted_enemy or target.get("modifier_mask") != 0
		_own().get_node("PlayerInputSource").scripted = command
		await create_timer(0.1).timeout
		time_left -= 0.1
	if _own() != null:
		_own().get_node("PlayerInputSource").scripted = _input_command_script.new()
	await create_timer(1.0).timeout


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
	return root.get_node_or_null("Main/LevelContainer/TestArena/Players/%d" % peer_id) as Node2D


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
	for enemy: Node2D in root.get_node("Main/LevelContainer/TestArena/Enemies").get_children():
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


func _wait_until(condition: Callable, timeout: float) -> void:
	var time_left: float = timeout
	while time_left > 0.0 and not condition.call():
		await create_timer(0.1).timeout
		time_left -= 0.1


func _info(text: String) -> void:
	print("SMOKE INFO %s: %s" % [_role, text])


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


func _finish(extra_failure: String) -> void:
	if _finished:
		return
	_finished = true
	if not extra_failure.is_empty():
		_failures.append(extra_failure)
	if _failures.is_empty():
		print("SMOKE PASS %s" % _role)
	else:
		print("SMOKE FAIL %s: %s" % [_role, "; ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)
