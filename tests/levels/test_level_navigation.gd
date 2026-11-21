extends GutTest
## The arena's navigation is baked from its walls and pillars, so enemies path around them.

const ARENA: PackedScene = preload("res://levels/test_arena.tscn")
## The left pillar in test_arena.tscn (centre 600,600, size 120).
const PILLAR := Rect2(540, 540, 120, 120)

var arena: Level


## The baked polygon reaches the navigation server a few syncs after the level starts.
func before_each() -> void:
	arena = ARENA.instantiate()
	add_child_autofree(arena)
	for i in 30:
		await wait_physics_frames(1)
		var map: RID = arena.navigation_region.get_navigation_map()
		if NavigationServer2D.map_get_iteration_id(map) > 0 and _path_exists(map):
			return


func _path_exists(map: RID) -> bool:
	return (
		NavigationServer2D.map_get_path(map, Vector2(900, 300), Vector2(1100, 300), true).size() > 0
	)


func _path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var map: RID = arena.navigation_region.get_navigation_map()
	return NavigationServer2D.map_get_path(map, from, to, true)


func test_navigation_is_baked_with_walkable_area() -> void:
	var polygon: NavigationPolygon = arena.navigation_region.navigation_polygon
	assert_gt(polygon.get_polygon_count(), 0, "bake produced walkable polygons")
	var map: RID = arena.navigation_region.get_navigation_map()
	assert_gt(NavigationServer2D.map_get_iteration_id(map), 0, "map synced")


func test_path_goes_around_the_pillar() -> void:
	var path: PackedVector2Array = _path(Vector2(450, 600), Vector2(750, 600))
	assert_gt(path.size(), 2, "a straight line would cross the pillar, so the path bends")
	for i in path.size() - 1:
		var crosses: bool = HitGeometry.segment_rect(path[i], path[i + 1], PILLAR) >= 0.0
		assert_false(crosses, "segment %d stays clear of the pillar" % i)


func test_open_floor_path_is_direct() -> void:
	var path: PackedVector2Array = _path(Vector2(900, 300), Vector2(1100, 300))
	assert_eq(path.size(), 2)
