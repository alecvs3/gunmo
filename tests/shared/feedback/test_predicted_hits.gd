extends GutTest
## PredictedHits: hits we already showed are matched with the host's drops, oldest first, and
## forgotten once too old.

const WINDOW: float = 0.5


func test_a_predicted_hit_covers_the_hosts_drop_once() -> void:
	var hits := PredictedHits.new()
	hits.add(1.0, WINDOW)
	assert_true(hits.consume(1.2, WINDOW), "the host's drop for it")
	assert_false(hits.consume(1.3, WINDOW), "a second drop was not predicted")


func test_no_prediction_covers_nothing() -> void:
	assert_false(PredictedHits.new().consume(1.0, WINDOW))


func test_two_pellets_are_used_up_one_at_a_time() -> void:
	var hits := PredictedHits.new()
	hits.add(1.0, WINDOW)
	hits.add(1.0, WINDOW)
	assert_eq(hits.pending(1.1, WINDOW), 2)
	assert_true(hits.consume(1.2, WINDOW))
	assert_eq(hits.pending(1.2, WINDOW), 1)
	assert_true(hits.consume(1.25, WINDOW))
	assert_false(hits.consume(1.3, WINDOW))


func test_an_expired_prediction_is_not_used() -> void:
	var hits := PredictedHits.new()
	hits.add(1.0, WINDOW)
	assert_false(hits.consume(1.6, WINDOW), "the host never confirmed it in time")
	assert_eq(hits.pending(1.6, WINDOW), 0)


func test_the_oldest_expires_first() -> void:
	var hits := PredictedHits.new()
	hits.add(1.0, WINDOW)
	hits.add(1.4, WINDOW)
	assert_eq(hits.pending(1.6, WINDOW), 1, "only the newer one is still waiting")
	assert_true(hits.consume(1.6, WINDOW))


func test_adding_drops_old_entries() -> void:
	var hits := PredictedHits.new()
	for i in 100:
		hits.add(float(i), WINDOW)
	assert_eq(hits.pending(99.0, WINDOW), 1, "a long run of mispredictions doesn't pile up")
