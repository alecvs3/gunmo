class_name NetChannel
extends Node
## Our gameplay traffic, separate from Godot's spawn messages:
##   commands  client -> host, every tick, unreliable (each packet repeats recent commands)
##   snapshots host -> client, every snapshot tick, unreliable (newer ones replace older)
##   events    host -> client, reliable, tagged with a topic (e.g. bullets fired / ended)
## Everything passes through the NetSimulator, so fake lag affects all of it the same way.

## Host: a client sent input commands.
signal commands_received(peer_id: int, data: PackedByteArray)
## Client: a snapshot (or part of one) arrived.
signal snapshot_received(data: PackedByteArray)
## Client: a reliable event arrived.
signal event_received(topic: int, data: PackedByteArray)

enum Kind { COMMANDS, SNAPSHOT, EVENT }

var simulator := NetSimulator.new()


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


func reset() -> void:
	simulator.clear()


func _send(packet: Dictionary) -> void:
	packet["outgoing"] = true
	if simulator.is_active():
		simulator.push(Time.get_ticks_msec(), packet, packet["kind"] != Kind.EVENT)
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


func _receive(packet: Dictionary) -> void:
	packet["outgoing"] = false
	if simulator.is_active():
		simulator.push(Time.get_ticks_msec(), packet, packet["kind"] != Kind.EVENT)
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


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_commands(data: PackedByteArray) -> void:
	if multiplayer.is_server():
		var sender: int = multiplayer.get_remote_sender_id()
		_receive({"kind": Kind.COMMANDS, "peer": sender, "data": data})


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snapshot(data: PackedByteArray) -> void:
	_receive({"kind": Kind.SNAPSHOT, "peer": 1, "data": data})


@rpc("authority", "call_remote", "reliable", 2)
func _rpc_event(topic: int, data: PackedByteArray) -> void:
	_receive({"kind": Kind.EVENT, "peer": 1, "topic": topic, "data": data})
