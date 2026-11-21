extends GutTest
## FairView: every window shape sees the same world box.

const VIEW := Vector2(1152, 648)


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


func test_bad_sizes_do_not_break() -> void:
	assert_eq(FairView.zoom_for(Vector2.ZERO, VIEW), 1.0)
	assert_eq(FairView.zoom_for(VIEW, Vector2.ZERO), 1.0)
