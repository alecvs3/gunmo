extends Node
## Owns the connection: host, join, leave, kick, the connection state and the peer list.
## Child nodes do the rest (they are services, not extra autoloads):
##   JoinGate        the join check            PingTracker     ping, loss, bandwidth
##   NetClock        shared tick time          NetChannel      commands/snapshots/events
##   Replicator      entity snapshots          LagCompensator  hit tests in the past

signal hosting_started
signal joined_host
signal join_failed(reason: String)
## We went offline after being in a session (host left, connection lost, kicked, or we left).
signal session_ended(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

enum State { OFFLINE, HOSTING, JOINING, CONNECTED }

const DEFAULT_CONFIG: NetworkConfig = preload("res://shared/network/default_network_config.tres")
const DEFAULT_LATENCY_POLICY: LatencyPolicy = preload(
	"res://shared/network/default_latency_policy.tres"
)

var config: NetworkConfig = DEFAULT_CONFIG
## How this match hides latency: the running mode's policy (GameMode sets it on every peer), or
## the default with everything off. Shared code reads this, never which mode is running.
var latency_policy: LatencyPolicy = DEFAULT_LATENCY_POLICY
var state: State = State.OFFLINE
## Every connected peer id, including our own. The host is always id 1.
var peers: Array[int] = []
## True when this host is a dedicated server (no local player).
var is_dedicated: bool = false
var stats := NetStats.new()
var gate: JoinGate
var ping: PingTracker
var clock: NetClock
var channel: NetChannel
var replicator: Replicator
var lag_compensator: LagCompensator

var _join_target: String = ""
## Set when the host tells us why it is about to disconnect us.
var _notice_from_host: String = ""
var _host_closing: bool = false
var _join_timer: Timer


func _ready() -> void:
	_create_children()
	configure_simulator(config.sim_latency_ms, config.sim_jitter_ms, config.sim_loss)
	var scene_multiplayer := multiplayer as SceneMultiplayer
	gate.setup(scene_multiplayer, config)
	gate.join_rejected.connect(_fail_join)
	gate.peer_rejected.connect(_on_peer_rejected)
	scene_multiplayer.peer_authenticating.connect(_apply_peer_timeouts)
	scene_multiplayer.peer_authentication_failed.connect(_on_authentication_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	NetLog.close()


## port 0 means config.default_port. A dedicated host runs the game without a player of its own.
func host(port: int = 0, dedicated: bool = false) -> Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	port = port if port > 0 else config.default_port
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, config.max_players)
	if err != OK:
		NetLog.write("could not host on port %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	state = State.HOSTING
	is_dedicated = dedicated
	peers = [1]
	var role: String = "dedicated server" if dedicated else "hosting"
	NetLog.write("%s on port %d, build %s" % [role, port, gate.hello["build"]])
	hosting_started.emit()
	return OK


## port 0 means config.default_port. Success or failure arrives as joined_host / join_failed.
func join(address: String, port: int = 0) -> Error:
	if state != State.OFFLINE:
		return ERR_ALREADY_IN_USE
	port = port if port > 0 else config.default_port
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	clock.reset()
	state = State.JOINING
	_join_target = "%s:%d" % [address, port]
	_join_timer.start(config.join_timeout)
	NetLog.write("joining %s, build %s" % [_join_target, gate.hello["build"]])
	return OK


func cancel_join() -> void:
	_fail_join("Join cancelled.")


## Leaves whatever we are doing. A host tells its clients first.
func leave() -> void:
	match state:
		State.JOINING:
			cancel_join()
		State.CONNECTED:
			_end_session("You left the session.")
		State.HOSTING:
			_close_as_host()


## Host only: tells the peer why, then disconnects it.
func kick(peer_id: int, reason: String) -> void:
	if state != State.HOSTING or peer_id == 1 or peer_id not in peers:
		return
	NetLog.write("kicking peer %d: %s" % [peer_id, reason])
	_receive_notice.rpc_id(peer_id, "Kicked by the host: %s" % reason)
	await get_tree().create_timer(config.close_flush_time).timeout
	if peer_id in multiplayer.get_peers():
		(multiplayer as SceneMultiplayer).disconnect_peer(peer_id)


## Sent to the host when we join (and used for our own player when we host).
func set_local_name(player_name: String) -> void:
	gate.set_local_name(player_name)


## Host: the name a peer chose, or "Player <id>" when it sent none.
func display_name(peer_id: int) -> String:
	var chosen: String = (
		str(gate.hello["name"]) if peer_id == 1 else str(gate.names.get(peer_id, ""))
	)
	return chosen if not chosen.is_empty() else "Player %d" % peer_id


func is_online() -> bool:
	return state == State.HOSTING or state == State.CONNECTED


func is_host() -> bool:
	return state == State.HOSTING


## Fake latency/jitter/loss on this peer's gameplay packets (testing); zeros turn it off.
func configure_simulator(latency_ms: int, jitter_ms: int, loss: float) -> void:
	channel.simulator.configure(latency_ms, jitter_ms, loss)
	if channel.simulator.is_active():
		NetLog.write(
			"network simulator: +%d ms ±%d ms, %.0f%% loss" % [latency_ms, jitter_ms, loss * 100.0]
		)


## The running mode's latency policy; null puts back the default (everything off).
func use_latency_policy(policy: LatencyPolicy) -> void:
	latency_policy = policy if policy != null else DEFAULT_LATENCY_POLICY


func _create_children() -> void:
	gate = JoinGate.new()
	gate.name = "JoinGate"
	add_child(gate)
	ping = PingTracker.new()
	ping.name = "PingTracker"
	ping.config = config
	ping.stats = stats
	add_child(ping)
	clock = _add_service(NetClock.new(), "NetClock")
	clock.config = config
	channel = _add_service(NetChannel.new(), "NetChannel")
	channel.configure(config)
	replicator = _add_service(Replicator.new(), "Replicator")
	replicator.config = config
	replicator.stats = stats
	replicator.setup(channel, clock, ping)
	lag_compensator = _add_service(LagCompensator.new(), "LagCompensator")
	lag_compensator.config = config
	lag_compensator.setup(clock)
	_join_timer = Timer.new()
	_join_timer.one_shot = true
	_join_timer.timeout.connect(_on_join_timed_out)
	add_child(_join_timer)


func _add_service(service: Node, service_name: String) -> Node:
	service.name = service_name
	add_child(service)
	return service


func _close_as_host() -> void:
	if _host_closing:
		return
	_host_closing = true
	_receive_notice.rpc("The host closed the session.")
	await get_tree().create_timer(config.close_flush_time).timeout
	_end_session("You closed the session.")


func _fail_join(reason: String) -> void:
	if state != State.JOINING:
		return
	_close()
	NetLog.write("join failed: %s" % reason)
	join_failed.emit(reason)


func _end_session(reason: String) -> void:
	_close()
	NetLog.write("session ended: %s" % reason)
	session_ended.emit(reason)


## Closing can emit disconnect signals right away, so state goes OFFLINE first.
func _close() -> void:
	state = State.OFFLINE
	_join_timer.stop()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers.clear()
	gate.names.clear()
	ping.reset()
	clock.reset()
	channel.reset()
	replicator.reset()
	stats.reset()
	is_dedicated = false
	_notice_from_host = ""
	_host_closing = false


func _apply_peer_timeouts(peer_id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer: ENetPacketPeer = enet.get_peer(peer_id) if enet != null else null
	if packet_peer != null:
		packet_peer.set_timeout(
			config.peer_timeout_factor, config.peer_timeout_min_ms, config.peer_timeout_max_ms
		)


@rpc("authority", "call_remote", "reliable")
func _receive_notice(reason: String) -> void:
	_notice_from_host = reason


func _on_peer_connected(peer_id: int) -> void:
	if peer_id not in peers:
		peers.append(peer_id)
	NetLog.write("peer %d connected" % peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peers.erase(peer_id)
	gate.names.erase(peer_id)
	NetLog.write("peer %d disconnected" % peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	_join_timer.stop()
	state = State.CONNECTED
	var own_id: int = multiplayer.get_unique_id()
	if own_id not in peers:
		peers.append(own_id)
	NetLog.write("joined %s as peer %d" % [_join_target, own_id])
	joined_host.emit()


func _on_connection_failed() -> void:
	_fail_join("Could not reach %s. Is it hosting, and is Tailscale connected?" % _join_target)


func _on_join_timed_out() -> void:
	_fail_join(
		(
			"No answer from %s after %d s. Is it hosting, and is Tailscale connected?"
			% [_join_target, roundi(config.join_timeout)]
		)
	)


func _on_authentication_failed(peer_id: int) -> void:
	if state == State.JOINING:
		_fail_join(
			(
				"The host did not answer the join check. It may be running an older build:"
				+ " pull the same commit on both PCs."
			)
		)
	elif state == State.HOSTING:
		NetLog.write("peer %d dropped during the join check" % peer_id)


func _on_peer_rejected(peer_id: int, reason: String) -> void:
	NetLog.write("refused peer %d: %s" % [peer_id, reason])


func _on_server_disconnected() -> void:
	if state != State.CONNECTED:
		return
	var reason: String = _notice_from_host
	_end_session(reason if not reason.is_empty() else "Lost connection to the host.")
