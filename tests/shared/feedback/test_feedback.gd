extends GutTest
## The "game feel" math: what counts as a hit, big hits, the flash, numbers, bursts, shake and
## the death event's format.

var data: FeedbackData


func before_each() -> void:
	data = FeedbackData.new()


func test_only_lost_health_counts() -> void:
	assert_eq(HitFeedback.lost(-1, 50), 0, "the first look is no hit")
	assert_eq(HitFeedback.lost(100, 88), 12)
	assert_eq(HitFeedback.lost(40, 60), 0, "healing and respawns show nothing")
	assert_eq(HitFeedback.lost(30, 30), 0)


func test_big_hits_are_a_share_of_max_health() -> void:
	data.big_hit_share = 0.3
	assert_true(data.is_big_hit(30, 100))
	assert_false(data.is_big_hit(29, 100))
	assert_true(data.is_big_hit(1, 1), "a one-health enemy")
	assert_false(data.is_big_hit(100, 1000), "bosses need much bigger hits")


func test_flash_fades_to_normal() -> void:
	assert_almost_eq(HitFeedback.flash_weight(0.1, 0.1, 0.8), 0.8, 0.001, "starts white")
	assert_eq(HitFeedback.flash_weight(0.0, 0.1, 0.8), 0.0, "ends at normal")
	assert_almost_eq(HitFeedback.flash_weight(0.05, 0.1, 0.8), 0.4, 0.001)


func test_numbers_pop_then_fade() -> void:
	assert_almost_eq(DamageNumber.pop_scale(0.0, 1.0), 1.6, 0.001)
	assert_almost_eq(DamageNumber.pop_scale(1.0, 1.0), 1.0, 0.001)
	assert_eq(DamageNumber.fade(0.2, 1.0), 1.0)
	assert_almost_eq(DamageNumber.fade(0.75, 1.0), 0.5, 0.001)
	assert_almost_eq(DamageNumber.fade(1.0, 1.0), 0.0, 0.001)


func test_burst_pieces_slow_down() -> void:
	var half: float = DeathBurst.travel(100.0, 0.5, 1.0)
	var full: float = DeathBurst.travel(100.0, 1.0, 1.0)
	assert_almost_eq(full, 50.0, 0.001)
	assert_gt(half, full / 2.0, "most of the distance is covered early")


func test_blast_shake_fades_with_distance() -> void:
	data.shake_on_blast = 0.8
	data.blast_shake_reach = 3.0
	assert_almost_eq(data.blast_shake(0.0, 100.0), 0.8, 0.001)
	assert_almost_eq(data.blast_shake(150.0, 100.0), 0.4, 0.001)
	assert_eq(data.blast_shake(300.0, 100.0), 0.0)
	assert_eq(data.blast_shake(5000.0, 100.0), 0.0)


func test_shake_offset_grows_with_the_square() -> void:
	assert_eq(PlayerCamera.shake_offset(0.0, 12.0, 0.0), Vector2.ZERO)
	assert_almost_eq(PlayerCamera.shake_offset(0.5, 12.0, 0.0).x, 3.0, 0.001)
	assert_almost_eq(PlayerCamera.shake_offset(1.0, 12.0, PI / 2.0).y, 12.0, 0.001)


func test_death_event_round_trip() -> void:
	var color := Color(0.8, 0.2, 0.4, 1.0)
	var payload: PackedByteArray = FeedbackSystem.encode_death(Vector2(10, -20), color, 2.5)
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(payload)
	assert_eq(buffer.get_u8(), FeedbackSystem.EVENT_DEATH)
	var death: Array = FeedbackSystem.decode_death(buffer)
	assert_eq(death[0], Vector2(10, -20))
	assert_eq((death[1] as Color).to_rgba32(), color.to_rgba32())
	assert_almost_eq(death[2], 2.5, 0.001)


func test_bad_death_events_are_dropped() -> void:
	assert_eq(FeedbackSystem.decode_death(NetCodec.buffer_from(PackedByteArray([1, 2]))), [])
	var payload: PackedByteArray = FeedbackSystem.encode_death(Vector2(INF, 0), Color.RED, 1.0)
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(payload)
	buffer.get_u8()
	assert_eq(FeedbackSystem.decode_death(buffer), [], "not a real place")
	payload = FeedbackSystem.encode_death(Vector2.ZERO, Color.RED, 999.0)
	buffer = NetCodec.buffer_from(payload)
	buffer.get_u8()
	assert_eq(FeedbackSystem.decode_death(buffer)[2], FeedbackSystem.MAX_BURST_SCALE, "capped")
