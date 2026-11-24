extends GutTest

const LOBBY: int = GameMode.Phase.LOBBY
const BREAK: int = GameMode.Phase.BREAK
const ACTIVE: int = GameMode.Phase.ACTIVE

var flow: WaveFlow
var lobby_ticks: int
var break_ticks: int


func before_each() -> void:
	flow = WaveFlow.new()
	flow.configure(3, 2.0, 1.0)
	flow.reset()
	lobby_ticks = 2 * NetClock.tick_rate()
	break_ticks = NetClock.tick_rate()


func _start_wave_one() -> void:
	flow.update(0, 2, 2, 2, false)


func test_lobby_waits_for_a_player_before_the_timer_runs() -> void:
	for tick in range(0, 1000, 100):
		assert_eq(flow.update(tick, 0, 0, 0, false), WaveFlow.Event.NONE)
	assert_eq(flow.phase_end_tick, -1.0, "no timer without players")
	flow.update(1000, 1, 1, 0, false)
	assert_eq(flow.phase_end_tick, float(1000 + lobby_ticks))


func test_lobby_ends_when_its_timer_runs_out() -> void:
	flow.update(0, 2, 2, 0, false)
	assert_eq(flow.update(lobby_ticks - 1, 2, 2, 0, false), WaveFlow.Event.NONE)
	assert_eq(flow.update(lobby_ticks, 2, 2, 0, false), WaveFlow.Event.WAVE_STARTED)
	assert_eq([flow.phase, flow.wave], [ACTIVE, 1])
	assert_eq(flow.phase_end_tick, -1.0)


func test_everyone_ready_skips_the_wait() -> void:
	assert_eq(flow.update(5, 2, 2, 1, false), WaveFlow.Event.NONE, "one of two ready")
	assert_eq(flow.update(6, 2, 2, 2, false), WaveFlow.Event.WAVE_STARTED)


func test_wave_clears_into_a_timed_break() -> void:
	_start_wave_one()
	assert_eq(flow.update(100, 2, 2, 0, false), WaveFlow.Event.NONE, "enemies left")
	assert_eq(flow.update(200, 2, 1, 0, true), WaveFlow.Event.WAVE_CLEARED)
	assert_eq(flow.phase, BREAK)
	assert_eq(flow.phase_end_tick, float(200 + break_ticks))
	assert_eq(flow.update(200 + break_ticks, 2, 2, 0, false), WaveFlow.Event.WAVE_STARTED)
	assert_eq(flow.wave, 2)


func test_last_wave_cleared_is_victory() -> void:
	for wave in 3:
		flow.update(wave * 1000, 1, 1, 1, false)
		var event: WaveFlow.Event = flow.update(wave * 1000 + 10, 1, 1, 1, true)
		if wave < 2:
			assert_eq(event, WaveFlow.Event.WAVE_CLEARED)
		else:
			assert_eq(event, WaveFlow.Event.VICTORY)
	assert_eq(flow.phase, GameMode.Phase.VICTORY)
	assert_eq(flow.update(99999, 1, 1, 1, true), WaveFlow.Event.NONE, "victory waits for restart")


func test_everyone_down_is_defeat_even_with_enemies_left() -> void:
	_start_wave_one()
	assert_eq(flow.update(50, 2, 0, 0, false), WaveFlow.Event.DEFEAT)
	assert_eq(flow.phase, GameMode.Phase.DEFEAT)


func test_defeat_beats_a_simultaneous_clear() -> void:
	_start_wave_one()
	assert_eq(flow.update(50, 2, 0, 0, true), WaveFlow.Event.DEFEAT)


func test_empty_server_mid_wave_is_not_defeat() -> void:
	_start_wave_one()
	assert_eq(flow.update(50, 0, 0, 0, false), WaveFlow.Event.NONE)
	assert_eq(flow.phase, ACTIVE)


func test_reset_returns_to_the_lobby() -> void:
	_start_wave_one()
	flow.update(10, 2, 0, 0, false)
	flow.reset()
	assert_eq([flow.phase, flow.wave, flow.phase_end_tick], [LOBBY, 0, -1.0])


func test_default_match_settings() -> void:
	var settings: MatchSettings = load("res://modes/data/default_match.tres")
	assert_eq(settings.first_break_seconds, 30.0)
	assert_eq(settings.break_seconds, 20.0)
	assert_not_null(settings.wave_schedule)
	assert_eq(settings.wave_schedule.total_waves, 25)


func test_bots_are_ready_once_every_human_is() -> void:
	assert_eq(WaveFlow.ready_with_bots(2, 2, 3), 5)
	assert_eq(WaveFlow.ready_with_bots(2, 1, 3), 1, "a human not ready: bots wait too")
	assert_eq(WaveFlow.ready_with_bots(0, 0, 4), 0, "bots alone never skip the lobby")
