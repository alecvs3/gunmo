extends GutTest

var state: MatchNetState


func before_each() -> void:
	state = MatchNetState.new()
	state.total_waves = 25
	state.player_count = 2


func test_lobby_without_timer() -> void:
	state.phase = GameMode.Phase.LOBBY
	var lines: Array[String] = Hud.match_lines(state, 0.0, false)
	assert_eq(lines[0], "Waiting for players")
	assert_eq(lines[1], "Press F when ready (0/2 ready)")
	assert_eq(Hud.wave_title(state), "Get ready")


func test_break_countdown_and_ready() -> void:
	state.phase = GameMode.Phase.BREAK
	state.wave = 3
	state.ready_count = 1
	state.phase_end_tick = 1000.0 + 12.2 * NetClock.tick_rate()
	var lines: Array[String] = Hud.match_lines(state, 1000.0, true)
	assert_eq(lines[0], "Next wave in 13 s", "rounds up so it never shows 0 early")
	assert_eq(lines[1], "Ready! (1/2 ready) · F to cancel")
	assert_eq(Hud.wave_title(state), "Wave 3 / 25")


func test_active_wave_shows_enemies_left() -> void:
	state.phase = GameMode.Phase.ACTIVE
	state.enemies_left = 17
	assert_eq(Hud.match_lines(state, 0.0, false)[0], "Enemies left: 17")


func test_early_call_prompt_and_modifiers_both_show() -> void:
	state.phase = GameMode.Phase.ACTIVE
	state.call_open = true
	state.call_votes = 1
	var prompt: String = Hud.match_lines(state, 0.0, false)[1]
	assert_eq(prompt, "G: call the next wave early for bonus credits (1/2)")
	assert_eq(Hud.stack_lines("Armored · Fast", prompt), "Armored · Fast\n" + prompt)
	assert_eq(Hud.stack_lines("", prompt), prompt, "no modifiers: just the prompt")
	assert_eq(Hud.stack_lines("Armored", ""), "Armored", "calling closed: just the modifiers")


func test_banners() -> void:
	state.phase = GameMode.Phase.ACTIVE
	state.wave = 4
	assert_eq(Hud.banner_for(GameMode.Phase.BREAK, 3, state), "Wave 4")
	assert_eq(Hud.banner_for(GameMode.Phase.ACTIVE, 4, state), "", "no repeat")
	state.phase = GameMode.Phase.BREAK
	assert_eq(Hud.banner_for(GameMode.Phase.ACTIVE, 4, state), "Wave 4 cleared!")
	state.phase = GameMode.Phase.VICTORY
	assert_eq(Hud.banner_for(GameMode.Phase.ACTIVE, 25, state), "Victory!")
	state.phase = GameMode.Phase.DEFEAT
	assert_eq(Hud.banner_for(GameMode.Phase.ACTIVE, 4, state), "Defeat")


func test_results_detail() -> void:
	state.phase = GameMode.Phase.VICTORY
	assert_eq(ResultsScreen.detail_text(state), "All 25 waves cleared.")
	state.phase = GameMode.Phase.DEFEAT
	state.wave = 9
	assert_eq(ResultsScreen.detail_text(state), "The team fell on wave 9 of 25.")


func test_forecast_line_shows_the_strongest_axes_modifiers_and_boss() -> void:
	var model: DifficultyModel = DifficultyModel.load_default()
	var catalog: ModifierCatalog = ModifierCatalog.load_default()
	assert_eq(Hud.forecast_line(state, model, catalog), "", "no forecast, no line")
	var next := WaveForecast.new()
	next.scores = PackedFloat32Array([9.0, 2.0, 1.0, 5.0, 0.0])
	next.modifier_mask = 0b1
	next.boss = true
	state.set_forecast(next)
	var armored: String = catalog.names(0b1)
	assert_eq(
		Hud.forecast_line(state, model, catalog),
		"Next: Toughness ▲▲ · Ranged ▲ · %s · Boss" % armored
	)
