class_name Level
extends Node2D
## A map: where players and enemies live and spawn. Game modes decide *when* things spawn
## (rule 7); the level only knows *where*. Spawning helpers are host only; the level's
## MultiplayerSpawners replicate what they add. Every peer's level draws pet effects
## (PetEffects), like its ProjectileSystem draws bullets.

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const BOT_CONTROLLER: Script = preload("res://bots/bot_controller.gd")

@export var players_root: Node2D
@export var enemies_root: Node2D
@export var player_spawn_points: Node2D
@export var enemy_spawn_points: Node2D
## Spread around the whole map; free-for-all respawns pick the one farthest from everyone.
## Falls back to the player spawn points when empty.
@export var respawn_points: Node2D
## Bot points of interest: spots worth going to (cover behind pillars, chokepoints). Bots
## hunt and take cover around these and the respawn points. May be empty.
@export var points_of_interest: Node2D
## Where enemies can walk. Baked on the host when the level starts, from the static colliders
## in the "navigation_obstacles" group (walls, pillars); clients don't need it.
@export var navigation_region: NavigationRegion2D


func _ready() -> void:
	add_child(PetEffects.new())
	if multiplayer.is_server() and navigation_region != null:
		navigation_region.bake_navigation_polygon(false)


## `display_name` reaches every client with the spawn.
func spawn_player(peer_id: int, display_name: String = "") -> Player:
	var new_player: Player = PLAYER_SCENE.instantiate()
	new_player.name = str(peer_id)
	new_player.display_name = display_name
	new_player.look_index = _free_look(new_player, false)
	new_player.position = player_spawn_position(players_root.get_child_count())
	players_root.add_child(new_player, true)
	return new_player


## A bot: a normal player (negative id) driven by a BotController that only the host has.
func spawn_bot(bot_id: int, display_name: String, profile: BotProfile) -> Player:
	var new_bot: Player = PLAYER_SCENE.instantiate()
	new_bot.name = str(bot_id)
	new_bot.display_name = display_name
	new_bot.is_bot = true
	new_bot.look_index = _free_look(new_bot, true)
	var controller: BotController = BOT_CONTROLLER.new()
	controller.name = "BotController"
	controller.profile = profile
	controller.roam_points = _respawn_positions() + interest_positions()
	new_bot.bot = controller
	new_bot.add_child(controller)
	players_root.add_child(new_bot, true)
	return new_bot


## A character nobody in the level has yet (CharacterAssignment).
func _free_look(joining: Player, for_bot: bool) -> int:
	var taken: Array[int] = []
	for other: Player in players_root.get_children():
		if not other.is_queued_for_deletion():
			taken.append(other.look_index)
	var data: PlayerData = joining.player_data
	return CharacterAssignment.pick(
		taken, data.preferred_looks(for_bot), data.all_looks().size(), absi(joining.name.to_int())
	)


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


## The respawn point whose nearest other player is farthest away.
func farthest_respawn_point(others: Array[Vector2]) -> Vector2:
	return farthest_from(_respawn_positions(), others)


## Of `candidates`, the one with the largest distance to its nearest point in `others`
## (the first candidate when there is nobody to avoid).
static func farthest_from(candidates: Array[Vector2], others: Array[Vector2]) -> Vector2:
	var best: Vector2 = candidates[0]
	var best_distance: float = -1.0
	for candidate in candidates:
		var nearest: float = INF
		for other in others:
			nearest = minf(nearest, candidate.distance_squared_to(other))
		if nearest > best_distance:
			best = candidate
			best_distance = nearest
	return best


func _respawn_positions() -> Array[Vector2]:
	var root: Node2D = respawn_points if respawn_points != null else player_spawn_points
	if root.get_child_count() == 0:
		root = player_spawn_points
	var positions: Array[Vector2] = []
	for point: Node2D in root.get_children():
		positions.append(point.position)
	return positions


func interest_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if points_of_interest != null:
		for point: Node2D in points_of_interest.get_children():
			positions.append(point.position)
	return positions


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
