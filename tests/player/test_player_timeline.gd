extends GutTest
## PlayerTimeline: each input's view tick (fair contact) is kept with its stamp, and clamped so a
## client can't be judged on an older or a future view than the rules allow.

const MAX_REWIND: int = 15
const VICTIM_REWIND: int = 18


func test_the_view_is_kept_with_its_stamp() -> void:
	var timeline := PlayerTimeline.new(MAX_REWIND, VICTIM_REWIND)
	timeline.record(100.0, 105, Vector2.ZERO, true, 90.0)
	assert_eq(timeline.newest_tick(), 100)
	assert_eq(timeline.view_at(100), 90.0)


func test_an_old_view_is_clamped_to_victim_rewind() -> void:
	var timeline := PlayerTimeline.new(MAX_REWIND, VICTIM_REWIND)
	timeline.record(100.0, 105, Vector2.ZERO, true, 10.0)
	assert_eq(timeline.view_at(100), 82.0, "at most victim_rewind before the stamp")


func test_a_future_view_is_clamped_to_the_stamp() -> void:
	var timeline := PlayerTimeline.new(MAX_REWIND, VICTIM_REWIND)
	timeline.record(100.0, 105, Vector2.ZERO, true, 140.0)
	assert_eq(timeline.view_at(100), 100.0)


func test_an_unknown_view_is_the_stamp_itself() -> void:
	var timeline := PlayerTimeline.new(MAX_REWIND, VICTIM_REWIND)
	timeline.record(100.0, 105, Vector2.ZERO, true)
	assert_eq(timeline.view_at(100), 100.0)
	assert_eq(timeline.view_at(77), 77.0, "never recorded")


func test_old_views_are_forgotten() -> void:
	var timeline := PlayerTimeline.new(MAX_REWIND, VICTIM_REWIND)
	for tick in range(100, 300):
		timeline.record(float(tick), tick, Vector2.ZERO, true, tick - 5.0)
	assert_eq(timeline.view_at(100), 100.0, "dropped long ago")
	assert_eq(timeline.view_at(299), 294.0)
