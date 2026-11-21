extends GutTest
## Gun Game HUD lines, the scoreboard's order and cells, and the results text.

var state: MatchNetState


func before_each() -> void:
	state = MatchNetState.new()
	state.mode_kind = MatchNetState.ModeKind.GUN_GAME
	state.ladder_length = 4
	state.kills_per_tier = 3
	state.final_tier_kills = 2


func _row(id: int, name: String, tier: int, tier_kills: int, kills: int, deaths: int) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"kills": kills,
		"deaths": deaths,
		"tier": tier,
		"tier_kills": tier_kills,
		"bot": id < 0,
		"local": false,
	}


func test_title_and_progress() -> void:
	assert_eq(GunGameHudText.title(state, 1, "Rifle"), "Gun 2 / 4 · Rifle")
	assert_eq(GunGameHudText.progress(state, 1, 2), "Kills 2 / 3")
	assert_eq(GunGameHudText.progress(state, 3, 1), "Kills 1 / 2 · last gun!")


func test_leader_line() -> void:
	var ranked: Array[Dictionary] = [_row(-1, "Bot 1", 2, 0, 6, 1), _row(5, "Alex", 1, 0, 3, 2)]
	assert_eq(GunGameHudText.leader_line(ranked, 5), "Leader: Bot 1 · gun 3")
	assert_eq(GunGameHudText.leader_line(ranked, -1), "You're in the lead")
	assert_eq(GunGameHudText.leader_line([] as Array[Dictionary], 5), "")


func test_winner_title() -> void:
	assert_eq(GunGameHudText.winner_title("Yusuf", false), "Yusuf wins!")
	assert_eq(GunGameHudText.winner_title("Alex", true), "You win!")


func test_gun_game_ranks_by_gun_then_kills_on_it() -> void:
	var rows: Array[Dictionary] = [
		_row(1, "A", 1, 2, 5, 0),
		_row(2, "B", 2, 0, 6, 9),
		_row(3, "C", 1, 2, 7, 0),
		_row(4, "D", 1, 0, 9, 0),
	]
	var order: Array = Scoreboard.rank(rows, MatchNetState.ModeKind.GUN_GAME).map(
		func(row: Dictionary) -> String: return row["name"]
	)
	assert_eq(order, ["B", "C", "A", "D"])


func test_waves_ranks_by_kills_then_fewest_deaths_then_name() -> void:
	var rows: Array[Dictionary] = [
		_row(1, "Zed", 0, 0, 10, 1), _row(2, "Amy", 0, 0, 10, 1), _row(3, "Bo", 0, 0, 10, 0)
	]
	var order: Array = Scoreboard.rank(rows, MatchNetState.ModeKind.WAVES).map(
		func(row: Dictionary) -> String: return row["name"]
	)
	assert_eq(order, ["Bo", "Amy", "Zed"])


func test_cells_and_headers_per_mode() -> void:
	var bot: Dictionary = _row(-2, "Bot 2 · Hard", 3, 1, 8, 4)
	assert_eq(Scoreboard.headers(MatchNetState.ModeKind.GUN_GAME).size(), 4)
	assert_eq(
		Scoreboard.cells(bot, MatchNetState.ModeKind.GUN_GAME),
		["Bot 2 · Hard (bot)", "4", "8", "4"] as Array[String]
	)
	assert_eq(
		Scoreboard.cells(bot, MatchNetState.ModeKind.WAVES),
		["Bot 2 · Hard (bot)", "8", "4"] as Array[String]
	)


func test_results_detail_for_gun_game() -> void:
	state.phase = GameMode.Phase.VICTORY
	assert_eq(ResultsScreen.detail_text(state), "First to finish all 4 guns.")
