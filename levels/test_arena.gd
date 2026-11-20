extends Node2D
## Test level. On the host: spawns a player per connected peer, removes players who leave,
## and (temporary Milestone 1 rule) respawns dead players after respawn_delay.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

@export var respawn_delay: float = 3.0

@onready var _players: Node2D = $Players
@onready var _spawn_points: Node2D = $PlayerSpawnPoints


func _ready() -> void:
	if not multiplayer.is_server():
		return
	for peer_id in NetworkManager.peers:
		_spawn_player(peer_id)
	NetworkManager.peer_joined.connect(_spawn_player)
	NetworkManager.peer_left.connect(_remove_player)
	EventBus.player_died.connect(_on_player_died)


func _spawn_player(peer_id: int) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	var points: Array[Node] = _spawn_points.get_children()
	player.position = (points[_players.get_child_count() % points.size()] as Node2D).position
	_players.add_child(player, true)


func _remove_player(peer_id: int) -> void:
	var player: Node = _players.get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()


func _on_player_died(peer_id: int) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	var player := _players.get_node_or_null(str(peer_id)) as Player
	if player != null:
		player.respawn(_pick_spawn_point())


func _pick_spawn_point() -> Vector2:
	var point: Node2D = _spawn_points.get_children().pick_random()
	return point.position
