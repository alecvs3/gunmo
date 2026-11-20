extends Node
## Owns the ENet connection: host, join, leave, and the list of connected peer ids.

signal hosting_started
signal joined_host
signal join_failed
signal host_disconnected
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 7

## Every connected peer id, including our own. The host is always id 1.
var peers: Array[int] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	peers = [multiplayer.get_unique_id()]
	hosting_started.emit()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers.clear()


func is_online() -> bool:
	return not peers.is_empty()


func _on_peer_connected(peer_id: int) -> void:
	peers.append(peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peers.erase(peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	peers.append(multiplayer.get_unique_id())
	joined_host.emit()


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	host_disconnected.emit()
