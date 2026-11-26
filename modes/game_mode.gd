class_name GameMode
extends Node
## Base for every game mode (Waves, Gun Game). One mode node lives under
## Main/ModeContainer on every peer:
##   host     runs the rules, spawns players into the level, keeps `state` up to date
##   clients  receive `state` (newest only, through NetEntity) and send requests to the host
## Everything else (HUD, results screen) listens to EventBus.match_state_changed and never
## asks which mode is running (rule 7); MatchNetState.mode_kind only picks their layout.
## The base keeps every player's kills and deaths; modes add their own scoring on top.

enum Phase { LOBBY, BREAK, ACTIVE, VICTORY, DEFEAT }

## NetChannel request topics (client -> host).
const REQUEST_READY: int = 1
## Bot profile when the match settings name none.
const FALLBACK_BOT_PROFILE: String = "res://bots/profiles/normal.tres"

## How this mode hides latency (modes/data/*_latency.tres). Set on the mode scene, so every peer
## has the same one without sending it; handed to NetworkManager while the mode is in the tree.
@export var latency_policy: LatencyPolicy

var settings: MatchSettings
var level: Level
## Host: the live state. Clients: the newest state from the host.
var state := MatchNetState.new()
## This peer pressed ready in the current lobby or break.
var local_ready: bool = false

var _published := MatchNetState.new()


## Host only, before the mode enters the tree.
func setup(map: Level, match_settings: MatchSettings) -> void:
	level = map
	settings = match_settings


## Every peer: this mode's latency policy applies while it runs.
func _enter_tree() -> void:
	NetworkManager.use_latency_policy(latency_policy)


func _exit_tree() -> void:
	NetworkManager.use_latency_policy(null)


func _ready() -> void:
	if not multiplayer.is_server():
		($NetEntity as NetEntity).use_latest_states()
		return
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.channel.request_received.connect(_on_request_received)
	EventBus.match_restart_requested.connect(restart)
	EventBus.player_killed.connect(_on_player_killed)
	_start()
	for peer_id in NetworkManager.peers:
		_on_peer_joined(peer_id)
	publish_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ready") and can_ready_up():
		set_local_ready(not local_ready)
		get_viewport().set_input_as_handled()
	elif _on_input(event):
		get_viewport().set_input_as_handled()


## Hook: a mode's own keys (true = it used the event).
func _on_input(_event: InputEvent) -> bool:
	return false


func can_ready_up() -> bool:
	return state.phase == Phase.LOBBY or state.phase == Phase.BREAK


## Ready up (or take it back). The host applies it; a client asks the host.
func set_local_ready(is_ready: bool) -> void:
	local_ready = is_ready
	EventBus.local_ready_changed.emit(local_ready)
	if multiplayer.is_server():
		_on_ready_changed(multiplayer.get_unique_id(), is_ready)
	else:
		var data := PackedByteArray([1 if is_ready else 0])
		NetworkManager.channel.send_request(REQUEST_READY, data)


func capture_net_state() -> NetState:
	return state.copy()


func receive_authoritative_state(_tick: int, new_state: NetState) -> void:
	_accept_state(new_state as MatchNetState)


## Host: call after changing `state`; local listeners hear about it when something changed.
func publish_state() -> void:
	if not state.equals(_published):
		_accept_state(state)


## Host: starts the match from scratch. Subclasses override.
func restart() -> void:
	pass


## Host: the mode's first moment (before players are spawned). Subclasses override.
func _start() -> void:
	pass


## Host: a player readied up or took it back. Subclasses override.
func _on_ready_changed(_peer_id: int, _is_ready: bool) -> void:
	pass


## Host: a peer arrived. By default it gets a player (a dedicated server gets none).
func _on_peer_joined(peer_id: int) -> void:
	if peer_id == 1 and NetworkManager.is_dedicated:
		return
	level.spawn_player(peer_id, NetworkManager.display_name(peer_id))


## Host: a death for the victim and, unless it was a suicide or not a player, a kill for the
## killer. Returns the killer's player (null when there is none to credit).
func _on_player_killed(victim: Node2D, killer_id: int) -> Player:
	var victim_player := victim as Player
	if victim_player == null:
		return null
	victim_player.get_score().deaths += 1
	var killer: Player = level.player(killer_id)
	if killer == null or killer == victim_player:
		return null
	killer.get_score().kills += 1
	return killer


## Host: adds or removes bots so humans + bots = bot_fill_to (never removes humans).
func _sync_bots() -> void:
	var bots: Array[Player] = []
	var humans: int = 0
	for player in level.players():
		if player.is_bot:
			bots.append(player)
		else:
			humans += 1
	var wanted: int = maxi(settings.bot_fill_to - humans, 0)
	while bots.size() > wanted:
		var leaving: Player = bots.pop_back()
		_on_bot_removed(leaving.peer_id)
		level.remove_player(leaving.peer_id)
	while bots.size() < wanted:
		bots.append(_add_bot())


## Hooks: a bot joined (give it what a new player gets) or is about to leave.
func _prepare_new_bot(_bot: Player) -> void:
	pass


func _on_bot_removed(_peer_id: int) -> void:
	pass


func _add_bot() -> Player:
	var number: int = 1
	while level.player(-number) != null:
		number += 1
	var profile: BotProfile = _bot_profile(number)
	var name_text: String = "Bot %d · %s" % [number, profile.display_name]
	var bot: Player = level.spawn_bot(-number, name_text, profile)
	_prepare_new_bot(bot)
	return bot


func _bot_profile(number: int) -> BotProfile:
	if settings.bot_profiles.is_empty():
		return load(FALLBACK_BOT_PROFILE)
	return settings.bot_profiles[(number - 1) % settings.bot_profiles.size()]


## Host: every player's score back to zero (a restart).
func _reset_scores() -> void:
	for player in level.players():
		player.get_score().reset()


func _on_peer_left(peer_id: int) -> void:
	level.remove_player(peer_id)


## Requests come from clients: they are only honoured when the rules allow them. Ready-up is
## handled here; other topics go to the mode (_on_request).
func _on_request_received(peer_id: int, topic: int, data: PackedByteArray) -> void:
	if level.player(peer_id) == null:
		return
	if topic != REQUEST_READY:
		_on_request(peer_id, topic, data)
	elif data.size() == 1 and can_ready_up():
		_on_ready_changed(peer_id, data[0] == 1)


## Host: a request this base class doesn't handle. Subclasses override.
func _on_request(_peer_id: int, _topic: int, _data: PackedByteArray) -> void:
	pass


## A new phase or wave clears this peer's ready flag.
func _accept_state(new_state: MatchNetState) -> void:
	var moved_on: bool = new_state.phase != _published.phase or new_state.wave != _published.wave
	_published = new_state.copy()
	state = new_state
	if moved_on and local_ready:
		local_ready = false
		EventBus.local_ready_changed.emit(false)
	EventBus.match_state_changed.emit(state)
