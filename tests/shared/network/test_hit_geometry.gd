extends GutTest


func test_segment_circle_hit_fraction() -> void:
	var t: float = HitGeometry.segment_circle(Vector2.ZERO, Vector2(100, 0), Vector2(50, 0), 10)
	assert_almost_eq(t, 0.4, 0.0001)


func test_segment_circle_miss_and_short() -> void:
	assert_eq(HitGeometry.segment_circle(Vector2.ZERO, Vector2(100, 0), Vector2(50, 20), 10), -1.0)
	assert_eq(HitGeometry.segment_circle(Vector2.ZERO, Vector2(30, 0), Vector2(50, 0), 10), -1.0)


func test_segment_circle_starting_inside() -> void:
	assert_eq(HitGeometry.segment_circle(Vector2(48, 0), Vector2(100, 0), Vector2(50, 0), 10), 0.0)


func test_segment_circle_zero_length_outside() -> void:
	assert_eq(HitGeometry.segment_circle(Vector2.ZERO, Vector2.ZERO, Vector2(50, 0), 10), -1.0)


func test_segment_rect_hit_and_miss() -> void:
	var rect := Rect2(40, -10, 20, 20)
	assert_almost_eq(HitGeometry.segment_rect(Vector2.ZERO, Vector2(100, 0), rect), 0.4, 0.0001)
	assert_eq(HitGeometry.segment_rect(Vector2(0, 50), Vector2(100, 50), rect), -1.0)
	assert_eq(HitGeometry.segment_rect(Vector2.ZERO, Vector2(30, 0), rect), -1.0)


func test_segment_rect_diagonal_and_inside() -> void:
	var rect := Rect2(40, 40, 20, 20)
	assert_almost_eq(HitGeometry.segment_rect(Vector2.ZERO, Vector2(100, 100), rect), 0.4, 0.0001)
	assert_eq(HitGeometry.segment_rect(Vector2(50, 50), Vector2(200, 50), rect), 0.0)


func test_segment_rect_vertical_path() -> void:
	var rect := Rect2(-5, 40, 10, 10)
	assert_almost_eq(HitGeometry.segment_rect(Vector2.ZERO, Vector2(0, 100), rect), 0.4, 0.0001)
	assert_eq(HitGeometry.segment_rect(Vector2(20, 0), Vector2(20, 100), rect), -1.0)
