class_name GunGameMode
extends GameMode
## Free-for-all up a weapon ladder: every kill counts toward your current gun, enough kills
## move you to the next one, and the first to finish the last gun wins. Host only: gives
## every player a team of its own, equips each player's tier gun, respawns the dead at the
## spawn point farthest from everyone else with a moment of spawn protection, and keeps the
## replicated MatchState current. Empty slots are filled with bots up to bot_fill_to (they
## leave again as humans join). The ladder, kill targets, timings and bot profiles come from
## MatchSettings. Every kill is reported to every peer for the kill feed.

## NetChannel event topic for the kill feed (ProjectileSystem uses 1): [i32 killer, i32 victim,
## i8 weapon index (-1 = none)].
const KILL_FEED_TOPIC: int = 3
const KILL_FEED_SIZE: int = 9

## Ladder guns as ShopCatalog weapon indices (what PlayerLoadout equips and snapshots carry).
var _ladder_weapons: Array[int] = []
var _ladder := GunGameLadder.new()
var _winner_id: int = 0
## peer id -> host tick the player comes back on.
var _respawn_at: Dictionary = {}
## peer id -> host tick their spawn protection ends on.
var _protected_until: Dictionary = {}


func _ready() -> void:
	super()
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server():
		EventBus.shot_fired.connect(_on_shot_fired)
	else:
		NetworkManager.channel.event_received.connect(_on_event_received)


func _physics_process(_delta: float) -> void:
	var now: int = NetworkManager.clock.tick
	for peer_id: int in _respawn_at.keys():
		if now >= _respawn_at[peer_id]:
			_respawn_at.erase(peer_id)
			_bring_back(level.player(peer_id))
	for peer_id: int in _protected_until.keys():
		if not SpawnProtection.is_on(now, _protected_until[peer_id]):
			_protected_until.erase(peer_id)
			var player: Player = level.player(peer_id)
			if player != null:
				player.is_protected = false
	_refresh_state()


## Host: everyone back to the first gun with no kills.
func restart() -> void:
	if not multiplayer.is_server():
		return
	_start()
	for player in level.players():
		_prepare(player)


func _start() -> void:
	_ladder_weapons = _catalog_indices(settings.ladder)
	_ladder.configure(_ladder_weapons.size(), settings.kills_per_tier, settings.final_tier_kills)
	_winner_id = 0
	_respawn_at.clear()
	_protected_until.clear()
	_refresh_state()


func _on_peer_joined(peer_id: int) -> void:
	super(peer_id)
	var joined: Player = level.player(peer_id)
	if joined != null:
		_prepare(joined)
	_sync_bots()


func _on_peer_left(peer_id: int) -> void:
	super(peer_id)
	_forget(peer_id)
	_sync_bots()


func _forget(peer_id: int) -> void:
	_respawn_at.erase(peer_id)
	_protected_until.erase(peer_id)


## A new bot gets the same fresh start as anyone.
func _prepare_new_bot(bot: Player) -> void:
	_prepare(bot)


func _on_bot_removed(peer_id: int) -> void:
	_forget(peer_id)


## A fresh start for one player: own team, first gun, no score, a spawn away from others.
func _prepare(player: Player) -> void:
	player.team_id = player.peer_id
	player.get_score().reset()
	player.get_loadout().reset()
	player.get_wallet().set_credits(0)
	_respawn_at.erase(player.peer_id)
	_bring_back(player)


func _bring_back(player: Player) -> void:
	if player == null:
		return
	player.get_loadout().equip_weapon(_tier_weapon(player.get_score().tier))
	player.respawn(level.farthest_respawn_point(_positions_except(player)))
	player.is_protected = settings.spawn_protection_seconds > 0.0
	_protected_until[player.peer_id] = SpawnProtection.until_after_spawn(
		NetworkManager.clock.tick, settings.spawn_protection_seconds
	)


## Host: firing ends your own spawn protection.
func _on_shot_fired(shot: RefCounted) -> void:
	var shooter: int = (shot as Shot).shooter_id
	if _protected_until.has(shooter):
		_protected_until[shooter] = SpawnProtection.until_after_shot(
			_protected_until[shooter], NetworkManager.clock.tick
		)


func _on_player_killed(victim: Node2D, killer_id: int) -> Player:
	var killer: Player = super(victim, killer_id)
	var victim_player := victim as Player
	if victim_player != null:
		var delay: int = roundi(settings.respawn_seconds * NetClock.tick_rate())
		_respawn_at[victim_player.peer_id] = NetworkManager.clock.tick + delay
		_protected_until.erase(victim_player.peer_id)
		victim_player.is_protected = false
	if victim_player != null and _winner_id == 0:
		_report_kill(killer, victim_player)
	if killer != null and _winner_id == 0:
		_advance(killer)
	return killer


## Host: tells every peer (and our own HUD) who killed whom with what, for the kill feed.
func _report_kill(killer: Player, victim: Player) -> void:
	var killer_id: int = killer.peer_id if killer != null else 0
	var weapon: int = killer.get_loadout().weapon_index if killer != null else -1
	EventBus.kill_reported.emit(killer_id, victim.peer_id, weapon)
	var buffer := StreamPeerBuffer.new()
	buffer.put_32(killer_id)
	buffer.put_32(victim.peer_id)
	buffer.put_8(clampi(weapon, -1, 127))
	for peer_id in multiplayer.get_peers():
		NetworkManager.channel.send_event(peer_id, KILL_FEED_TOPIC, buffer.data_array)


## Clients: the host's kill reports (trusted: events only come from the host).
func _on_event_received(topic: int, data: PackedByteArray) -> void:
	if topic != KILL_FEED_TOPIC or data.size() != KILL_FEED_SIZE:
		return
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(data)
	var killer_id: int = buffer.get_32()
	var victim_id: int = buffer.get_32()
	EventBus.kill_reported.emit(killer_id, victim_id, buffer.get_8())


func _advance(killer: Player) -> void:
	match _ladder.record_kill(killer.get_score()):
		GunGameLadder.Result.ADVANCED:
			killer.get_loadout().equip_weapon(_tier_weapon(killer.get_score().tier))
		GunGameLadder.Result.FINISHED:
			_winner_id = killer.peer_id
			NetLog.write("gun game won by %s" % killer.display_name)


func _tier_weapon(tier: int) -> int:
	return _ladder_weapons[clampi(tier, 0, _ladder_weapons.size() - 1)]


func _positions_except(player: Player) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for other in level.players():
		if other != player and other.is_alive:
			positions.append(other.position)
	return positions


## The ladder's guns as catalog indices; guns the catalog doesn't sell are skipped (the
## catalog is what every peer can name by index).
static func _catalog_indices(ladder: Array[WeaponData]) -> Array[int]:
	var catalog: ShopCatalog = ShopCatalog.load_default()
	var indices: Array[int] = []
	for weapon in ladder:
		var index: int = catalog.weapons.find(weapon)
		if index >= 0:
			indices.append(index)
		else:
			push_error("Gun Game ladder: %s is not in the shop catalog." % weapon.resource_path)
	if indices.is_empty():
		indices.append(0)
	return indices


func _refresh_state() -> void:
	var players: Array[Player] = level.players()
	var living: int = 0
	for player in players:
		living += 1 if player.is_alive else 0
	state.mode_kind = MatchNetState.ModeKind.GUN_GAME
	state.phase = GameMode.Phase.VICTORY if _winner_id != 0 else GameMode.Phase.ACTIVE
	state.winner_id = _winner_id
	state.player_count = players.size()
	state.living_count = living
	state.shop_open = false
	state.phase_end_tick = -1.0
	state.ladder_length = _ladder.length
	state.kills_per_tier = _ladder.kills_per_tier
	state.final_tier_kills = _ladder.final_tier_kills
	publish_state()
