class_name Level
extends Node2D
## A map: where players and enemies live and spawn. Game modes decide *when* things spawn
## (rule 7); the level only knows *where*. Spawning helpers are host only; the level's
## MultiplayerSpawners replicate what they add.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

@export var players_root: Node2D
@export var enemies_root: Node2D
@export var player_spawn_points: Node2D
@export var enemy_spawn_points: Node2D
## Where enemies can walk. Baked on the host when the level starts, from the static colliders
## in the "navigation_obstacles" group (walls, pillars); clients don't need it.
@export var navigation_region: NavigationRegion2D


func _ready() -> void:
	if multiplayer.is_server() and navigation_region != null:
		navigation_region.bake_navigation_polygon(false)


## `display_name` reaches every client with the spawn.
func spawn_player(peer_id: int, display_name: String = "") -> Player:
	var new_player: Player = PLAYER_SCENE.instantiate()
	new_player.name = str(peer_id)
	new_player.display_name = display_name
	new_player.position = player_spawn_position(players_root.get_child_count())
	players_root.add_child(new_player, true)
	return new_player


func remove_player(peer_id: int) -> void:
	var leaving: Player = player(peer_id)
	if leaving != null:
		leaving.queue_free()


func player(peer_id: int) -> Player:
	return players_root.get_node_or_null(str(peer_id)) as Player


func players() -> Array[Player]:
	var found: Array[Player] = []
	for child in players_root.get_children():
		if child is Player and not child.is_queued_for_deletion():
			found.append(child)
	return found


## Spawn points are used in turn, so players start apart.
func player_spawn_position(index: int) -> Vector2:
	var points: Array[Node] = player_spawn_points.get_children()
	return (points[index % points.size()] as Node2D).position


func enemy_spawn_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for point: Node2D in enemy_spawn_points.get_children():
		positions.append(point.position)
	return positions


func add_enemy(enemy: Node2D) -> void:
	enemies_root.add_child(enemy, true)


## Enemies still in the fight (ones being freed don't count).
func enemy_count() -> int:
	var count: int = 0
	for enemy in enemies_root.get_children():
		if not enemy.is_queued_for_deletion():
			count += 1
	return count


func clear_enemies() -> void:
	for enemy in enemies_root.get_children():
		enemy.queue_free()
