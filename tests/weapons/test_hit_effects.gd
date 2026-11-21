extends GutTest


func _burn(dps: float, seconds: float) -> HitEffects:
	var effects := HitEffects.new()
	effects.burn_dps = dps
	effects.burn_seconds = seconds
	return effects


func test_mask_lists_only_effects_that_do_something() -> void:
	var effects := HitEffects.new()
	assert_true(effects.is_empty())
	effects.burn_dps = 5.0
	assert_eq(effects.mask(), 0, "burn without a duration does nothing")
	effects.burn_seconds = 2.0
	effects.shock_chains = 2
	effects.shock_share = 0.5
	effects.shock_range = 100.0
	assert_eq(effects.mask(), HitEffects.BURN | HitEffects.SHOCK)


func test_plus_adds_amounts_and_keeps_longest_duration() -> void:
	var weapon: HitEffects = _burn(10.0, 2.0)
	var perk: HitEffects = _burn(4.0, 3.0)
	var sum: HitEffects = weapon.plus(perk, 2)
	assert_eq(sum.burn_dps, 18.0, "10 + 4 x 2 levels")
	assert_eq(sum.burn_seconds, 3.0, "the longer duration")
	assert_eq(weapon.burn_dps, 10.0, "the originals are not changed")
	assert_eq(perk.burn_dps, 4.0)


func test_plus_null_or_zero_times_is_a_copy() -> void:
	var weapon: HitEffects = _burn(10.0, 2.0)
	assert_eq(weapon.plus(null).burn_dps, 10.0)
	assert_eq(weapon.plus(_burn(4.0, 3.0), 0).burn_dps, 10.0)
	assert_ne(weapon.plus(null), weapon)


func test_carried_drops_arcs_and_blasts() -> void:
	var effects: HitEffects = _burn(5.0, 2.0)
	effects.shock_chains = 3
	effects.shock_share = 0.5
	effects.shock_range = 100.0
	effects.blast_share = 0.5
	effects.blast_radius = 80.0
	assert_eq(effects.carried().mask(), HitEffects.BURN)
	assert_eq(effects.shock_chains, 3, "the original keeps its arcs")


func test_tint_is_plain_without_effects() -> void:
	assert_eq(HitEffects.tint(0), Color(1.0, 0.85, 0.3))
	assert_ne(HitEffects.tint(HitEffects.CHILL), HitEffects.tint(HitEffects.BURN))
	assert_eq(HitEffects.tint(HitEffects.BURN | HitEffects.CHILL).a, 1.0)
