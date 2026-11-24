class_name MapCheck
extends RefCounted
## The automatic check every map must pass (tests/levels/test_map_check.gd): the level has the
## systems every map needs (bullets, game-feel effects), and every spawn point (player starts,
## respawns, enemy spawns, bot points of interest) stands on the navigation mesh, not inside a
## wall, and can walk to every other one. Needs the level in the tree with its navigation synced.

## A point this far from the navigation mesh is "off" it (px): the mesh keeps a margin from
## walls, so points right next to one sit a little outside it.
const ON_MESH_DISTANCE: float = 40.0
## A path counts as arriving when it ends this close to the target's mesh point (px).
const ARRIVED_DISTANCE: float = 8.0
const WORLD_MASK: int = 1


## Every named point of the level ("RespawnPoints/North" -> position).
static func points(level: Level) -> Dictionary:
	var found: Dictionary = {}
	var roots: Array[Node2D] = [
		level.player_spawn_points,
		level.respawn_points,
		level.enemy_spawn_points,
		level.points_of_interest
	]
	for root in roots:
		if root == null:
			continue
		for marker: Node2D in root.get_children():
			found["%s/%s" % [root.name, marker.name]] = marker.global_position
	return found


## The systems a level is missing: every map needs a ProjectileSystem (bullets) and a
## FeedbackSystem (damage numbers, death bursts, world sounds), each a direct child.
static func missing_systems(level: Level) -> PackedStringArray:
	var has_projectiles: bool = false
	var has_feedback: bool = false
	for child in level.get_children():
		has_projectiles = has_projectiles or child is ProjectileSystem
		has_feedback = has_feedback or child is FeedbackSystem
	var missing := PackedStringArray()
	if not has_projectiles:
		missing.append("no ProjectileSystem")
	if not has_feedback:
		missing.append("no FeedbackSystem")
	return missing


## What is wrong with the map (empty = it passes).
static func problems(level: Level) -> PackedStringArray:
	var found: PackedStringArray = missing_systems(level)
	var all: Dictionary = points(level)
	if all.is_empty() or level.player_spawn_points.get_child_count() == 0:
		found.append("no spawn points")
		return found
	var map: RID = level.navigation_region.get_navigation_map()
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var hub: Vector2 = all.values()[0]
	for label: String in all:
		var at: Vector2 = all[label]
		var on_mesh: Vector2 = NavigationServer2D.map_get_closest_point(map, at)
		if at.distance_to(on_mesh) > ON_MESH_DISTANCE:
			found.append("%s is off the navigation mesh" % label)
		if _inside_wall(space, at):
			found.append("%s is inside a wall" % label)
		if not reaches(map, hub, at) or not reaches(map, at, hub):
			found.append("%s can't be reached from the others" % label)
	return found


## Whether walking from `from` along the mesh arrives at `to`.
static func reaches(map: RID, from: Vector2, to: Vector2) -> bool:
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, from, to, true)
	if path.is_empty():
		return false
	var target: Vector2 = NavigationServer2D.map_get_closest_point(map, to)
	return path[path.size() - 1].distance_to(target) <= ARRIVED_DISTANCE


static func _inside_wall(space: PhysicsDirectSpaceState2D, at: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collision_mask = WORLD_MASK
	query.collide_with_areas = false
	return not space.intersect_point(query, 1).is_empty()
