extends GutTest

var data: HealerData


func before_each() -> void:
	data = load("res://pets/data/healer.tres")


func test_mending_from_tier_1_stronger_from_2() -> void:
	assert_eq(HealerRules.mending_share(data, 0), 0.0)
	assert_eq(HealerRules.mending_share(data, 1), data.mending_share)
	assert_eq(HealerRules.mending_share(data, 2), data.mending_share_upgraded)
	assert_gt(data.mending_share_upgraded, data.mending_share)


func test_mending_waits_for_half_the_wave() -> void:
	assert_false(HealerRules.mending_ready(data, 499, 1000))
	assert_true(HealerRules.mending_ready(data, 500, 1000))
	assert_false(HealerRules.mending_ready(data, 500, 0), "no wave health: never")


func test_wave_end_from_tier_2() -> void:
	assert_eq(HealerRules.wave_end_share(data, 1), 0.0)
	assert_eq(HealerRules.wave_end_share(data, 2), data.wave_end_share)
	assert_eq(HealerRules.wave_end_share(data, 3), data.wave_end_share_upgraded)


func test_triage_from_tier_3() -> void:
	assert_eq(HealerRules.revive_speed(data, 2), 1.0)
	assert_eq(HealerRules.revive_speed(data, 3), data.triage_revive_speed)
	assert_eq(HealerRules.revive_bonus(data, 2), 0.0)
	assert_eq(HealerRules.revive_bonus(data, 3), data.triage_health_bonus)


func test_siphon_heals_a_share_of_damage_up_to_a_cap() -> void:
	assert_eq(HealerRules.siphon_heal(data, 3, 1000, 0, 100), 0, "not before tier 4")
	assert_eq(HealerRules.siphon_heal(data, 4, 200, 0, 100), 4, "2% of 200")
	assert_eq(HealerRules.siphon_heal(data, 4, 5000, 0, 100), 10, "capped at 10% of 100")
	assert_eq(HealerRules.siphon_heal(data, 4, 5000, 8, 100), 2, "only what's left of the cap")
	assert_eq(HealerRules.siphon_heal(data, 4, 5000, 10, 100), 0, "cap reached")
	assert_eq(HealerRules.siphon_heal(data, 5, 5000, 10, 100), 5, "tier 5 cap: 15%")


func test_guardian_once_a_wave_at_tier_5() -> void:
	assert_false(HealerRules.guardian_saves(4, false))
	assert_true(HealerRules.guardian_saves(5, false))
	assert_false(HealerRules.guardian_saves(5, true), "already used this wave")


func test_heal_amounts_are_shares_of_max_health() -> void:
	assert_eq(HealerRules.amount(0.12, 100), 12)
	assert_eq(HealerRules.amount(0.12, 250), 30)
	assert_eq(HealerRules.amount(0.001, 100), 1, "at least 1")


func test_effect_events_round_trip_and_junk_is_dropped() -> void:
	var points := PackedVector2Array([Vector2(10, 20), Vector2(30, 40)])
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(PetEffects.Kind.ARC)
	buffer.put_float(5.0)
	buffer.put_float(0.4)
	buffer.put_u8(points.size())
	for at in points:
		NetCodec.put_vector2(buffer, at)
	var decoded: Array = PetEffects.decode(buffer.data_array)
	assert_eq(decoded.slice(0, 3), [PetEffects.Kind.ARC, points, 5.0])
	assert_almost_eq(decoded[3], 0.4, 1e-6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var junk := PackedByteArray()
		junk.resize(rng.randi_range(0, 60))
		for j in junk.size():
			junk[j] = rng.randi_range(0, 255)
		var result: Array = PetEffects.decode(junk)
		if not result.is_empty():
			assert_lt(result[0], PetEffects.Kind.size())
			assert_lte((result[1] as PackedVector2Array).size(), PetEffects.MAX_POINTS)
