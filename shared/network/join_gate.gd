class_name JoinGate
extends Node
## The login step before a peer enters the game, using SceneMultiplayer authentication.
## Until both sides call complete_auth(), the peer gets no spawns, syncs or RPCs.
## The joiner sends a hello; the host checks it with Handshake and accepts or rejects.

## Client side: the host refused us.
signal join_rejected(reason: String)
## Host side: we refused someone (for the log).
signal peer_rejected(peer_id: int, reason: String)

var config: NetworkConfig
## What we tell the host about ourselves (and, on the host, what joiners must match).
var hello: Dictionary = {}

var _scene_multiplayer: SceneMultiplayer


func setup(scene_multiplayer: SceneMultiplayer, network_config: NetworkConfig) -> void:
	_scene_multiplayer = scene_multiplayer
	config = network_config
	hello = Handshake.make_hello(BuildInfo.version(), BuildInfo.fingerprint())
	_scene_multiplayer.auth_callback = _on_auth_received
	_scene_multiplayer.auth_timeout = config.auth_timeout
	_scene_multiplayer.peer_authenticating.connect(_on_peer_authenticating)


func _on_peer_authenticating(peer_id: int) -> void:
	if not _scene_multiplayer.is_server():
		_scene_multiplayer.send_auth(peer_id, Handshake.encode(hello))


func _on_auth_received(peer_id: int, data: PackedByteArray) -> void:
	var message: Dictionary = Handshake.decode(data)
	if _scene_multiplayer.is_server():
		_judge(peer_id, message)
	elif message.get("ok", false) == true:
		_scene_multiplayer.complete_auth(peer_id)
	else:
		join_rejected.emit(str(message.get("reason", "The host refused the connection.")))


func _judge(peer_id: int, joiner_hello: Dictionary) -> void:
	var player_count: int = _scene_multiplayer.get_peers().size() + 1
	var reason: String = Handshake.check_hello(
		joiner_hello, hello, player_count, config.max_players, config.require_matching_build
	)
	if reason.is_empty():
		_scene_multiplayer.send_auth(peer_id, Handshake.encode(Handshake.accept()))
		_scene_multiplayer.complete_auth(peer_id)
		return
	# The joiner disconnects itself on reading this; auth_timeout drops it otherwise.
	_scene_multiplayer.send_auth(peer_id, Handshake.encode(Handshake.reject(reason)))
	peer_rejected.emit(peer_id, reason)
