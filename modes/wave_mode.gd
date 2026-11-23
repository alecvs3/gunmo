class_name WaveMode
extends GameMode
## Co-op waves: players team up against waves that grow every time; clearing the last wins.
## Host only: every tick it tells WaveFlow the facts (players, alive, ready, wave done),
## starts waves with the WaveSpawner, revives the fallen when a wave is cleared (if the match
## settings say so), lets late joiners spectate until the break, keeps the replicated
## MatchState current, and pays credits: each enemy's bounty to its killer and a bonus to
## everyone standing when a wave is cleared. Each wave's enemies come from a seed made of the
## match seed and the wave number, so a match can be replayed exactly.

## NetChannel request topic: [kind (ShopRules.KIND_*), index].
const REQUEST_BUY: int = 2

var _flow := WaveFlow.new()
var _ready_peers: Dictionary = {}
var _match_seed: int = 0
var _modifier_mask: int = 0
var _modifiers: ModifierCatalog = ModifierCatalog.load_default()

@onready var _spawner: WaveSpawner = $WaveSpawner


func _ready() -> void:
	super()
	set_physics_process(multiplayer.is_server())
	EventBus.shop_purchase_requested.connect(_on_shop_purchase_requested)
	if multiplayer.is_server():
		EventBus.enemy_killed.connect(_on_enemy_killed)


## The shop is open in the lobby and in breaks.
func shop_open() -> bool:
	return can_ready_up()


func _physics_process(_delta: float) -> void:
	var players: Array[Player] = level.players()
	var living: int = _count_living(players)
	var wave_done: bool = _spawner.is_finished() and level.enemy_count() == 0
	var ready: int = _count_ready(players)
	_handle(_flow.update(NetworkManager.clock.tick, players.size(), living, ready, wave_done))
	_refresh_state(players.size(), living, ready)


## Host: back to the lobby with everyone alive and no enemies.
func restart() -> void:
	if not multiplayer.is_server():
		return
	level.clear_enemies()
	_start()
	_reset_scores()
	_revive(true)
	for player in level.players():
		_give_starting_kit(player)


func _start() -> void:
	var schedule: WaveSchedule = settings.wave_schedule
	_flow.configure(schedule.total_waves, settings.first_break_seconds, settings.break_seconds)
	_flow.reset()
	_match_seed = randi()
	_ready_peers.clear()
	_spawner.stop()


func _handle(event: WaveFlow.Event) -> void:
	match event:
		WaveFlow.Event.WAVE_STARTED:
			_ready_peers.clear()
			var schedule: WaveSchedule = settings.wave_schedule
			_modifier_mask = _modifiers.pick_for_wave(schedule, _match_seed, _flow.wave)
			var seed_value: int = WaveBudget.wave_seed(_match_seed, _flow.wave)
			_spawner.start_wave(level, schedule, _flow.wave, seed_value, _modifier_mask)
		WaveFlow.Event.WAVE_CLEARED:
			_ready_peers.clear()
			_pay_wave_bonus()
			if settings.revive_at_break:
				_revive(false)
		WaveFlow.Event.VICTORY, WaveFlow.Event.DEFEAT:
			_spawner.stop()


## Brings back the players who are down (or, with `everyone`, resets all of them).
func _revive(everyone: bool) -> void:
	var players: Array[Player] = level.players()
	for i in players.size():
		if everyone or not players[i].is_alive:
			players[i].respawn(level.player_spawn_position(i))


func _on_ready_changed(peer_id: int, is_ready: bool) -> void:
	if is_ready:
		_ready_peers[peer_id] = true
	else:
		_ready_peers.erase(peer_id)


## Joining during a wave: spectate until the break, when everyone down comes back.
func _on_peer_joined(peer_id: int) -> void:
	super(peer_id)
	var joined: Player = level.player(peer_id)
	if joined != null:
		_give_starting_kit(joined)
	var mid_wave: bool = _flow.phase == GameMode.Phase.ACTIVE
	if joined != null and mid_wave and settings.late_joiners_spectate:
		joined.make_spectator()


## Starting credits and weapon (new players, and everyone on restart).
func _give_starting_kit(player: Player) -> void:
	player.get_wallet().set_credits(settings.starting_credits)
	player.get_loadout().reset()


func _pay_wave_bonus() -> void:
	var bonus: int = settings.wave_clear_bonus + settings.wave_clear_bonus_per_wave * _flow.wave
	for player in level.players():
		if player.is_alive:
			player.get_wallet().add(bonus)


func _on_enemy_killed(enemy: Node2D, killer_peer_id: int) -> void:
	var killer: Player = level.player(killer_peer_id)
	if killer == null:
		return
	killer.get_score().kills += 1
	var chaser := enemy as ChaserEnemy
	if chaser != null:
		killer.get_wallet().add(chaser.enemy_data.bounty)


## This peer's shop asked to buy: the host applies it, a client asks the host.
func _on_shop_purchase_requested(kind: int, index: int) -> void:
	if multiplayer.is_server():
		_buy(multiplayer.get_unique_id(), kind, index)
	else:
		NetworkManager.channel.send_request(REQUEST_BUY, PackedByteArray([kind, index]))


func _on_request(peer_id: int, topic: int, data: PackedByteArray) -> void:
	if topic == REQUEST_BUY and data.size() == 2:
		_buy(peer_id, data[0], data[1])


## Host: the rules decide; only then are credits taken and the item applied.
func _buy(peer_id: int, kind: int, index: int) -> void:
	var buyer: Player = level.player(peer_id)
	if buyer == null:
		return
	var loadout: PlayerLoadout = buyer.get_loadout()
	var wallet: WalletComponent = buyer.get_wallet()
	var reason: String = _purchase_problem(loadout, wallet, kind, index)
	if not reason.is_empty():
		NetLog.write("purchase by %d refused: %s" % [peer_id, reason])
		return
	wallet.spend(ShopRules.price(loadout.catalog, kind, index, loadout.level(index)))
	if kind == ShopRules.KIND_UPGRADE:
		loadout.add_level(index)
	else:
		loadout.equip_weapon(index)


func _purchase_problem(
	loadout: PlayerLoadout, wallet: WalletComponent, kind: int, index: int
) -> String:
	var catalog: ShopCatalog = loadout.catalog
	if kind == ShopRules.KIND_UPGRADE:
		return ShopRules.check_upgrade(
			shop_open(), catalog, index, loadout.level(index), wallet.credits
		)
	if kind == ShopRules.KIND_WEAPON:
		return ShopRules.check_weapon(
			shop_open(), catalog, index, loadout.weapon_index, wallet.credits
		)
	return "Unknown purchase."


func _on_peer_left(peer_id: int) -> void:
	super(peer_id)
	_ready_peers.erase(peer_id)


func _count_living(players: Array[Player]) -> int:
	var living: int = 0
	for player in players:
		if player.is_alive:
			living += 1
	return living


func _count_ready(players: Array[Player]) -> int:
	var ready: int = 0
	for player in players:
		if _ready_peers.has(player.peer_id):
			ready += 1
	return ready


func _refresh_state(player_count: int, living: int, ready: int) -> void:
	state.mode_kind = MatchNetState.ModeKind.WAVES
	state.shop_open = shop_open()
	state.phase = _flow.phase
	state.wave = _flow.wave
	state.total_waves = _flow.total_waves
	state.phase_end_tick = _flow.phase_end_tick
	state.enemies_left = _spawner.remaining() + level.enemy_count()
	state.player_count = player_count
	state.living_count = living
	state.ready_count = ready
	state.modifier_mask = _modifier_mask if _flow.phase == GameMode.Phase.ACTIVE else 0
	publish_state()
