class_name NetChannel
extends Node
## Our gameplay traffic, separate from Godot's spawn messages:
##   commands  client -> host, every tick, unreliable (each packet repeats recent commands)
##   snapshots host -> client, every snapshot tick, unreliable (newer ones replace older)
##   events    host -> client, reliable, tagged with a topic (e.g. bullets fired / ended)
##   requests  client -> host, reliable, tagged with a topic (e.g. ready up); the host checks them
## Everything passes through the NetSimulator, so fake lag affects all of it the same way.
## Packets are read at the start of every physics tick and sent at its end (a TickEdge child
## runs before every other node, this node after every other), not just once per rendered
## frame, so a command or snapshot never waits a frame to leave or to be seen.

## Host: a client sent input commands.
signal commands_received(peer_id: int, data: PackedByteArray)
## Client: a snapshot (or part of one) arrived.
signal snapshot_received(data: PackedByteArray)
## Client: a reliable event arrived.
signal event_received(topic: int, data: PackedByteArray)
## Host: a client asked for something. Never trust it: check it against the rules first.
signal request_received(peer_id: int, topic: int, data: PackedByteArray)

enum Kind { COMMANDS, SNAPSHOT, EVENT, REQUEST }

var simulator := NetSimulator.new()
## Host: how often each client may send commands and requests (set by configure()).
var command_limit := RateLimiter.new(120.0, 40.0)
var request_limit := RateLimiter.new(8.0, 16.0)
var max_request_bytes: int = 64

## Peer id -> when its last drop was logged (msec), so a flood logs once a second, not per packet.
var _drop_logged_at: Dictionary[int, int] = {}


## Runs `on_tick` at the very start of every physics tick.
class TickEdge:
	extends Node
	var on_tick: Callable

	func _physics_process(_delta: float) -> void:
		on_tick.call()


func _ready() -> void:
	process_physics_priority = 1000
	var start := TickEdge.new()
	start.name = "TickStart"
	start.process_physics_priority = -1000
	start.on_tick = _receive_now
	add_child(start)
	multiplayer.peer_disconnected.connect(_forget_peer)


func configure(config: NetworkConfig) -> void:
	command_limit = RateLimiter.new(config.command_packets_per_second, config.command_burst)
	request_limit = RateLimiter.new(config.requests_per_second, config.request_burst)
	max_request_bytes = config.max_request_bytes


## End of the tick: everything this tick queued goes out now.
func _physics_process(_delta: float) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.host != null:
		enet.host.flush()


## Start of the tick: read what arrived since the last poll, so this tick can use it.
func _receive_now() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.poll()


func _process(_delta: float) -> void:
	for packet: Dictionary in simulator.pop_ready(Time.get_ticks_msec()):
		if packet["outgoing"]:
			_send_now(packet)
		else:
			_deliver(packet)


func send_commands(data: PackedByteArray) -> void:
	_send({"kind": Kind.COMMANDS, "peer": 1, "data": data})


func send_snapshot(peer_id: int, data: PackedByteArray) -> void:
	_send({"kind": Kind.SNAPSHOT, "peer": peer_id, "data": data})


func send_event(peer_id: int, topic: int, data: PackedByteArray) -> void:
	_send({"kind": Kind.EVENT, "peer": peer_id, "topic": topic, "data": data})


func send_request(topic: int, data: PackedByteArray) -> void:
	_send({"kind": Kind.REQUEST, "peer": 1, "topic": topic, "data": data})


func reset() -> void:
	simulator.clear()


func _send(packet: Dictionary) -> void:
	packet["outgoing"] = true
	if simulator.is_active():
		simulator.push(Time.get_ticks_msec(), packet, _droppable(packet))
	else:
		_send_now(packet)


func _send_now(packet: Dictionary) -> void:
	if (
		not multiplayer.has_multiplayer_peer()
		or not multiplayer.multiplayer_peer is ENetMultiplayerPeer
	):
		return
	var peer_id: int = packet["peer"]
	match packet["kind"]:
		Kind.COMMANDS:
			_rpc_commands.rpc_id(peer_id, packet["data"])
		Kind.SNAPSHOT:
			_rpc_snapshot.rpc_id(peer_id, packet["data"])
		Kind.EVENT:
			_rpc_event.rpc_id(peer_id, packet["topic"], packet["data"])
		Kind.REQUEST:
			_rpc_request.rpc_id(peer_id, packet["topic"], packet["data"])


func _receive(packet: Dictionary) -> void:
	packet["outgoing"] = false
	if simulator.is_active():
		simulator.push(Time.get_ticks_msec(), packet, _droppable(packet))
	else:
		_deliver(packet)


func _deliver(packet: Dictionary) -> void:
	match packet["kind"]:
		Kind.COMMANDS:
			commands_received.emit(packet["peer"], packet["data"])
		Kind.SNAPSHOT:
			snapshot_received.emit(packet["data"])
		Kind.EVENT:
			event_received.emit(packet["topic"], packet["data"])
		Kind.REQUEST:
			request_received.emit(packet["peer"], packet["topic"], packet["data"])


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_commands(data: PackedByteArray) -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		if accepts_commands(sender, Time.get_ticks_msec()):
			_receive({"kind": Kind.COMMANDS, "peer": sender, "data": data})


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snapshot(data: PackedByteArray) -> void:
	_receive({"kind": Kind.SNAPSHOT, "peer": 1, "data": data})


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_event(topic: int, data: PackedByteArray) -> void:
	_receive({"kind": Kind.EVENT, "peer": 1, "topic": topic, "data": data})


@rpc("any_peer", "call_remote", "reliable", 2)
func _rpc_request(topic: int, data: PackedByteArray) -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		if accepts_request(sender, data, Time.get_ticks_msec()):
			_receive({"kind": Kind.REQUEST, "peer": sender, "topic": topic, "data": data})


## Host: false when this client is sending commands faster than its limit (the packet is dropped).
func accepts_commands(peer_id: int, now_msec: int) -> bool:
	if command_limit.allow(peer_id, now_msec / 1000.0):
		return true
	_log_drop(peer_id, "commands", now_msec)
	return false


## Host: false for an oversized request or one over this client's limit (it is dropped unread).
func accepts_request(peer_id: int, data: PackedByteArray, now_msec: int) -> bool:
	if data.size() > max_request_bytes:
		_log_drop(peer_id, "an oversized request", now_msec)
		return false
	if request_limit.allow(peer_id, now_msec / 1000.0):
		return true
	_log_drop(peer_id, "requests", now_msec)
	return false


func _log_drop(peer_id: int, what: String, now_msec: int) -> void:
	if now_msec - _drop_logged_at.get(peer_id, -1000000) < 1000:
		return
	_drop_logged_at[peer_id] = now_msec
	NetLog.write("peer %d: dropped %s (over the client limit)" % [peer_id, what])


func _forget_peer(peer_id: int) -> void:
	command_limit.forget(peer_id)
	request_limit.forget(peer_id)
	_drop_logged_at.erase(peer_id)


## Unreliable traffic may be dropped by the simulator; events and requests never are.
static func _droppable(packet: Dictionary) -> bool:
	return packet["kind"] == Kind.COMMANDS or packet["kind"] == Kind.SNAPSHOT
