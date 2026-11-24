extends GutTest
## The automatic map check (MapCheck) for every map in levels/data/: every spawn point is on
## the navigation mesh, not inside a wall, and can reach every other one.

const MAPS_FOLDER: String = "res://levels/data/"


func _maps() -> Array[MapData]:
	var found: Array[MapData] = []
	for file in DirAccess.get_files_at(MAPS_FOLDER):
		if file.ends_with(".tres"):
			var map := load(MAPS_FOLDER + file) as MapData
			if map != null:
				found.append(map)
	return found


## Adds the map's level and waits for its baked navigation to reach the server.
func _load(map: MapData) -> Level:
	var level: Level = map.scene.instantiate()
	add_child_autofree(level)
	var hub: Vector2 = level.player_spawn_points.get_child(0).global_position
	for i in 40:
		await wait_physics_frames(1)
		var nav: RID = level.navigation_region.get_navigation_map()
		if NavigationServer2D.map_get_iteration_id(nav) > 0:
			if MapCheck.reaches(nav, hub, hub + Vector2(1, 0)):
				break
	await wait_physics_frames(2)
	return level


func test_every_map_passes_the_map_check() -> void:
	var maps: Array[MapData] = _maps()
	assert_gt(maps.size(), 0, "found the maps")
	for map in maps:
		assert_false(map.display_name.is_empty(), "%s has a name" % map.resource_path)
		assert_true(map.supports_waves or map.supports_gun_game, map.display_name + " has a mode")
		var level: Level = await _load(map)
		assert_eq(MapCheck.problems(level), PackedStringArray(), map.display_name)
		assert_gt(MapCheck.points(level).size(), 4, map.display_name + " has spawn points")
		level.queue_free()
		await wait_physics_frames(1)


func test_the_check_catches_a_spawn_inside_a_wall() -> void:
	var arena: Level = await _load(load(MAPS_FOLDER + "test_arena.tres"))
	var bad := Marker2D.new()
	bad.name = "InPillar"
	bad.position = Vector2(600, 600)
	arena.respawn_points.add_child(bad)
	await wait_physics_frames(1)
	var found: PackedStringArray = MapCheck.problems(arena)
	assert_has(found, "RespawnPoints/InPillar is inside a wall")


func test_the_check_catches_a_missing_system() -> void:
	var arena: Level = load(MAPS_FOLDER + "test_arena.tres").scene.instantiate()
	add_child_autofree(arena)
	assert_eq(MapCheck.missing_systems(arena), PackedStringArray())
	var feedback: Node = arena.get_node("FeedbackSystem")
	arena.remove_child(feedback)
	feedback.free()
	assert_eq(MapCheck.missing_systems(arena), PackedStringArray(["no FeedbackSystem"]))


func test_the_check_catches_bullets_drawn_over_characters() -> void:
	var arena: Level = load(MAPS_FOLDER + "test_arena.tres").scene.instantiate()
	add_child_autofree(arena)
	assert_eq(MapCheck.draw_order_problems(arena), PackedStringArray())
	arena.move_child(arena.get_node("Projectiles"), -1)
	assert_eq(
		MapCheck.draw_order_problems(arena),
		PackedStringArray(["Projectiles draws over Players", "Projectiles draws over Enemies"])
	)


func test_match_settings_pick_a_map() -> void:
	for path in ["res://modes/data/default_match.tres", "res://modes/data/gun_game_match.tres"]:
		var settings: MatchSettings = load(path)
		assert_not_null(settings.map, path + " names its map")
		assert_true(settings.map.scene.can_instantiate())
