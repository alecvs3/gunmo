extends GutTest
## FairView: every window shape sees the same world box.

const VIEW := Vector2(1152, 648)
const CROP: float = 0.12


func _world_seen(visible: Vector2) -> Vector2:
	return visible / FairView.zoom_for(visible, VIEW)


func test_base_window_is_unzoomed() -> void:
	assert_almost_eq(FairView.zoom_for(VIEW, VIEW), 1.0, 0.0001)


func test_every_shape_sees_at_least_the_box_and_matches_it_on_one_axis() -> void:
	for visible in [
		Vector2(1152, 648),
		Vector2(1536, 648),
		Vector2(1152, 864),
		Vector2(768, 432),
		Vector2(2000, 600)
	]:
		var seen: Vector2 = _world_seen(visible)
		assert_true(
			seen.x >= VIEW.x - 0.01 and seen.y >= VIEW.y - 0.01, "%s sees the whole box" % visible
		)
		assert_true(
			is_equal_approx(seen.x, VIEW.x) or is_equal_approx(seen.y, VIEW.y),
			"%s sees no more than the box on its tight axis" % visible
		)


func test_box_on_screen_is_centered_and_bars_cover_the_rest() -> void:
	var ultrawide := Vector2(1536, 648)
	var box: Rect2 = FairView.box_on_screen(ultrawide, VIEW)
	assert_eq(box, Rect2(192, 0, 1152, 648), "bars of 192 on each side")
	var tall := Vector2(1152, 864)
	assert_eq(FairView.box_on_screen(tall, VIEW), Rect2(0, 108, 1152, 648), "bars top and bottom")


func test_near_16_9_windows_are_filled_without_bars() -> void:
	for visible in [Vector2(1233, 648), Vector2(1152, 720)]:  # maximized 1920x1009, 16:10
		assert_eq(
			FairView.box_on_screen(visible, VIEW, CROP),
			Rect2(Vector2.ZERO, visible),
			"%s filled edge to edge" % visible
		)


func test_nobody_sees_more_than_the_box_and_crop_stays_small() -> void:
	for visible in [
		Vector2(1152, 648),
		Vector2(1233, 648),
		Vector2(1152, 720),
		Vector2(1536, 648),
		Vector2(1152, 864),
		Vector2(768, 432),
		Vector2(2000, 500)
	]:
		var zoom: float = FairView.zoom_for(visible, VIEW, CROP)
		var seen: Vector2 = FairView.box_on_screen(visible, VIEW, CROP).size / zoom
		assert_true(
			seen.x <= VIEW.x + 0.5 and seen.y <= VIEW.y + 0.5, "%s sees %s" % [visible, seen]
		)
		var least: float = minf(seen.x / VIEW.x, seen.y / VIEW.y)
		assert_gt(
			least, 1.0 - CROP - 0.001, "%s loses at most %d%%" % [visible, roundi(CROP * 100)]
		)


func test_ultrawide_crops_a_little_then_gets_bars() -> void:
	var box: Rect2 = FairView.box_on_screen(Vector2(1536, 648), VIEW, CROP)
	assert_almost_eq(box.size.y, 648.0, 0.01, "full height")
	assert_lt(box.size.x, 1536.0, "bars at the sides")
	assert_gt(box.size.x, 1152.0, "narrower bars than without the crop")


func test_bad_sizes_do_not_break() -> void:
	assert_eq(FairView.zoom_for(Vector2.ZERO, VIEW), 1.0)
	assert_eq(FairView.zoom_for(VIEW, Vector2.ZERO), 1.0)
