class_name PingTracker
extends Node
## Measures connection quality every NetworkConfig.ping_interval seconds.
## Each peer reads its own ENet stats; the host also shares every peer's ping with everyone.

signal stats_updated

enum Quality { GOOD, OK, BAD }

var config: NetworkConfig
## This peer's round trip to the host in ms (0 on the host).
var own_ping_ms: int = 0
## 0.0–1.0, this peer's packet loss to the host.
var packet_loss: float = 0.0
## Where the host's per-player input numbers live (set by NetworkManager).
var stats: NetStats
var sent_bytes_per_sec: int = 0
var received_bytes_per_sec: int = 0
## peer id -> ping in ms, as measured by the host.
var peer_pings: Dictionary = {}

var _time_left: float = 0.0


static func quality(ping_ms: int, cfg: NetworkConfig) -> Quality:
	if ping_ms <= cfg.ping_good_ms:
		return Quality.GOOD
	if ping_ms <= cfg.ping_ok_ms:
		return Quality.OK
	return Quality.BAD


## Client: the round trip to the host right now (ENet's running average), in ms.
func live_rtt_ms() -> float:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or multiplayer.is_server():
		return 0.0
	if enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return 0.0
	var host_peer: ENetPacketPeer = enet.get_peer(1)
	return 0.0 if host_peer == null else _round_trip_ms(host_peer)


func reset() -> void:
	own_ping_ms = 0
	packet_loss = 0.0
	sent_bytes_per_sec = 0
	received_bytes_per_sec = 0
	peer_pings.clear()
	_time_left = 0.0


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = config.ping_interval
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_sample(enet)
	if multiplayer.is_server():
		_receive_peer_report.rpc(peer_pings, _input_report())
	stats_updated.emit()


func _sample(enet: ENetMultiplayerPeer) -> void:
	var connection: ENetConnection = enet.host
	var sent: float = connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var received: float = connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	sent_bytes_per_sec = roundi(sent / config.ping_interval)
	received_bytes_per_sec = roundi(received / config.ping_interval)
	if multiplayer.is_server():
		peer_pings = {1: 0}
		for peer_id in multiplayer.get_peers():
			var packet_peer: ENetPacketPeer = enet.get_peer(peer_id)
			if packet_peer != null:
				peer_pings[peer_id] = _round_trip_ms(packet_peer)
		return
	var host_peer: ENetPacketPeer = enet.get_peer(1)
	if host_peer != null:
		own_ping_ms = _round_trip_ms(host_peer)
		var loss: float = host_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
		packet_loss = loss / ENetPacketPeer.PACKET_LOSS_SCALE


func _round_trip_ms(packet_peer: ENetPacketPeer) -> int:
	return int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


## Host: every remote player's input numbers (NetStats.peer_inputs) as plain arrays.
func _input_report() -> Dictionary:
	var report: Dictionary = {}
	if stats == null:
		return report
	for peer_id: int in stats.peer_inputs:
		report[peer_id] = (stats.peer_inputs[peer_id] as NetStats.PeerInput).to_array()
	return report


## Clients: pings and input numbers from the host (checked: it is still data from the network).
@rpc("authority", "call_remote", "unreliable")
func _receive_peer_report(pings: Dictionary, inputs: Dictionary) -> void:
	var cleaned: Dictionary = {}
	for peer_id: Variant in pings:
		if peer_id is int and pings[peer_id] is int:
			cleaned[peer_id] = pings[peer_id]
	peer_pings = cleaned
	if stats == null:
		return
	stats.peer_inputs.clear()
	for peer_id: Variant in inputs:
		if peer_id is int:
			stats.peer_inputs[peer_id] = NetStats.PeerInput.from_array(inputs[peer_id])
