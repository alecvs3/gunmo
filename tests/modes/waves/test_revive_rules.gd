extends GutTest

const REVIVE: float = 3.0


func _run(downed: ReviveRules.Downed, seconds: float, reviving: bool) -> ReviveRules.Result:
	var result: ReviveRules.Result = ReviveRules.Result.DOWN
	var ticks: int = roundi(seconds * 60.0)
	for i in ticks:
		result = ReviveRules.step(downed, 1.0 / 60.0, reviving, REVIVE)
		if result != ReviveRules.Result.DOWN:
			return result
	return result


func test_holding_revive_long_enough_revives() -> void:
	var downed := ReviveRules.Downed.new(20.0)
	assert_eq(_run(downed, 2.9, true), ReviveRules.Result.DOWN)
	assert_eq(_run(downed, 0.2, true), ReviveRules.Result.REVIVED)


func test_letting_go_interrupts_and_empties_the_bar() -> void:
	var downed := ReviveRules.Downed.new(20.0)
	_run(downed, 2.5, true)
	_run(downed, 1.0 / 60.0, false)
	assert_eq(downed.progress, 0.0, "interrupted: start again")
	assert_eq(_run(downed, 2.5, true), ReviveRules.Result.DOWN)


func test_bleeds_out_unless_someone_is_reviving() -> void:
	var downed := ReviveRules.Downed.new(5.0)
	_run(downed, 2.0, true)
	assert_almost_eq(downed.bleed_left, 5.0, 1e-4, "the timer waits while being revived")
	assert_eq(_run(downed, 4.9, false), ReviveRules.Result.DOWN)
	assert_eq(_run(downed, 0.2, false), ReviveRules.Result.BLED_OUT)


func test_range() -> void:
	assert_true(ReviveRules.in_range(Vector2.ZERO, Vector2(70, 0), 70.0))
	assert_false(ReviveRules.in_range(Vector2.ZERO, Vector2(50, 50), 70.0), "71 px")


func test_byte() -> void:
	assert_eq(ReviveRules.to_byte(0.0), 0)
	assert_eq(ReviveRules.to_byte(0.001), 1, "a sliver still shows as downed")
	assert_eq(ReviveRules.to_byte(1.0), 255)


func test_hud_texts() -> void:
	assert_eq(Hud.down_text(255, 0, 0), "You're down · a teammate can revive you (100% left)")
	assert_eq(Hud.down_text(200, 128, 0), "You're down · being revived 50%")
	assert_string_starts_with(Hud.down_text(0, 0, 0), "You're down · nobody left")
	assert_eq(Hud.revive_prompt("Yusuf", 0), "Hold E to revive Yusuf")
	assert_eq(Hud.revive_prompt("Yusuf", 255), "Reviving Yusuf… 100%")


func test_revive_button_survives_sanitizing() -> void:
	var command := InputCommand.new()
	command.buttons = InputCommand.REVIVE | InputCommand.FIRE | 64
	assert_eq(command.sanitized().buttons, InputCommand.REVIVE | InputCommand.FIRE)


func test_default_match_has_downed_and_revive() -> void:
	var settings: MatchSettings = load("res://modes/data/default_match.tres")
	assert_gt(settings.bleed_out_seconds, settings.revive_seconds)
	assert_true(InputMap.has_action("revive"))
