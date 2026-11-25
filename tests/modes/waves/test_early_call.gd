extends GutTest

var settings: MatchSettings


func before_each() -> void:
	settings = MatchSettings.new()
	settings.early_call_bonus_per_enemy = 6
	settings.early_call_bonus_per_second = 3


func test_only_once_the_wave_has_spawned_and_not_on_the_last() -> void:
	assert_true(EarlyCall.can_call(true, 3, 25, true, 255))
	assert_false(EarlyCall.can_call(true, 3, 25, false, 255), "still spawning")
	assert_false(EarlyCall.can_call(false, 3, 25, true, 255), "not during a break")
	assert_false(EarlyCall.can_call(true, 25, 25, true, 255), "nothing after the last wave")


func test_only_the_early_waves_can_be_started_early() -> void:
	assert_true(EarlyCall.can_call(true, 4, 25, true, 5), "calling into wave 5 is fine")
	assert_false(EarlyCall.can_call(true, 5, 25, true, 5), "wave 6 always gets its break")
	assert_false(EarlyCall.can_call(true, 25, 25, true, 5), "nor after the last wave")
	assert_false(EarlyCall.can_call(true, 3, 3, true, 255), "no limit still stops at the end")


func test_leftovers_from_earlier_waves_are_not_paid_again() -> void:
	var alive: Node = autofree(Node.new())
	var killed: Node = Node.new()
	var dying: Node = autofree(Node.new())
	var spawned: Array[Node] = [alive, killed, dying]
	killed.free()
	dying.queue_free()
	assert_eq(WaveSpawner.count_alive(spawned), 1, "only this wave's enemies still standing")
	var spawner: WaveSpawner = autofree(WaveSpawner.new())
	assert_eq(spawner.alive_count(), 0, "older waves' enemies are in no list of this wave")


func test_the_vote_needs_everyone() -> void:
	assert_true(EarlyCall.passes(2, 2))
	assert_false(EarlyCall.passes(1, 2))
	assert_false(EarlyCall.passes(0, 0), "nobody there")
	assert_eq(WaveFlow.ready_with_bots(1, 1, 3), 4, "bots vote with the humans")


func test_bonus_grows_with_enemies_alive_and_break_skipped() -> void:
	assert_eq(EarlyCall.bonus(0, 15.0, settings), 45)
	assert_eq(EarlyCall.bonus(10, 15.0, settings), 105)


func test_flow_starts_the_next_wave_without_a_break() -> void:
	var flow := WaveFlow.new()
	flow.configure(3, 1.0, 1.0)
	flow.reset()
	flow.update(0, 1, 1, 1, false)
	assert_eq(flow.wave, 1)
	assert_eq(flow.call_early(), WaveFlow.Event.EARLY_CALLED)
	assert_eq([flow.phase, flow.wave], [GameMode.Phase.ACTIVE, 2])
	flow.call_early()
	assert_eq(flow.call_early(), WaveFlow.Event.NONE, "the last wave can't be called past")
	assert_eq(flow.wave, 3)


func test_hud_prompt() -> void:
	var state := MatchNetState.new()
	state.player_count = 2
	assert_eq(Hud.call_line(state, false), "")
	state.call_open = true
	state.call_votes = 1
	assert_eq(Hud.call_line(state, false), "G: call the next wave early for bonus credits (1/2)")
	assert_string_starts_with(Hud.call_line(state, true), "Calling the next wave early (1/2)")


func test_default_match_pays_for_calling_early() -> void:
	var real: MatchSettings = load("res://modes/data/default_match.tres")
	assert_gt(real.early_call_bonus_per_enemy, 0)
	assert_eq(real.early_call_last_wave, 5, "the break before wave 6 always happens")
	assert_eq(MatchSettings.new().early_call_last_wave, 255, "no limit unless a match sets one")
	assert_true(InputMap.has_action("call_wave"))
