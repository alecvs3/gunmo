extends GutTest

const GameSettingsScript: GDScript = preload("res://autoloads/game_settings.gd")
## Never the real user://settings.cfg.
const TEST_PATH: String = "user://test_game_settings.cfg"

var _real_path: String = ""
var _real_fullscreen: bool = false


func before_each() -> void:
	_remove_test_file()
	_real_path = GameSettings.settings_path
	_real_fullscreen = GameSettings.fullscreen
	GameSettings.settings_path = TEST_PATH


func after_each() -> void:
	GameSettings.fullscreen = _real_fullscreen
	GameSettings.settings_path = _real_path
	_remove_test_file()


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## A fresh settings node that loads from the test file, as the game would on start.
func _fresh_settings() -> Node:
	var settings: Node = GameSettingsScript.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	return settings


func test_window_mode_for() -> void:
	assert_eq(GameSettingsScript.window_mode_for(true), DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(GameSettingsScript.window_mode_for(false), DisplayServer.WINDOW_MODE_WINDOWED)


func test_starts_windowed_without_a_saved_choice() -> void:
	assert_false(_fresh_settings().fullscreen)


func test_fullscreen_is_remembered() -> void:
	_fresh_settings().set_fullscreen(true)
	assert_true(_fresh_settings().fullscreen, "loaded on the next start")


func test_name_and_fullscreen_do_not_overwrite_each_other() -> void:
	var settings: Node = _fresh_settings()
	settings.set_player_name("Yusuf")
	settings.set_fullscreen(true)
	settings.set_player_name("Alex")
	var reloaded: Node = _fresh_settings()
	assert_eq(reloaded.player_name, "Alex")
	assert_true(reloaded.fullscreen)


func test_change_is_announced_once() -> void:
	var settings: Node = _fresh_settings()
	watch_signals(settings)
	settings.set_fullscreen(true)
	settings.set_fullscreen(true)
	assert_signal_emit_count(settings, "fullscreen_changed", 1)
	assert_signal_emitted_with_parameters(settings, "fullscreen_changed", [true])


func test_ui_scale_exclusive_and_window_are_remembered() -> void:
	var settings: Node = _fresh_settings()
	settings.set_ui_scale(1.3)
	settings.set_fullscreen_exclusive(true)
	settings._save_value("display", "window_rect", Rect2i(50, 60, 1280, 720))
	var reloaded: Node = _fresh_settings()
	assert_eq(reloaded.ui_scale, 1.25, "snapped to a choice")
	assert_true(reloaded.fullscreen_exclusive)
	assert_eq(reloaded.window_rect, Rect2i(50, 60, 1280, 720))
	settings.get_tree().root.content_scale_factor = 1.0


func test_bad_saved_ui_scale_falls_back() -> void:
	_fresh_settings()._save_value("display", "ui_scale", "huge")
	assert_eq(_fresh_settings().ui_scale, 1.0)


func test_ui_scale_picker_follows_and_changes_the_setting() -> void:
	var real_scale: float = GameSettings.ui_scale
	var picker := UiScaleOption.new()
	add_child_autofree(picker)
	GameSettings.set_ui_scale(1.5)
	assert_eq(picker.selected, 3, "follows the other menu")
	picker.item_selected.emit(0)
	assert_eq(GameSettings.ui_scale, 0.85, "picking changes the setting")
	GameSettings.set_ui_scale(real_scale)
	get_tree().root.content_scale_factor = 1.0


func test_checkbox_follows_and_changes_the_setting() -> void:
	GameSettings.set_fullscreen(false)
	var check := FullscreenCheck.new()
	add_child_autofree(check)
	assert_false(check.button_pressed)
	GameSettings.set_fullscreen(true)
	assert_true(check.button_pressed, "follows F11 / the other menu")
	check.button_pressed = false
	assert_false(GameSettings.fullscreen, "clicking it changes the setting")
