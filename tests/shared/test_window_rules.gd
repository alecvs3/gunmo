extends GutTest
## WindowRules: window modes, UI scale choices, and restoring a saved window onto a real screen.

const SCREEN := Rect2i(0, 0, 1920, 1040)
const SECOND := Rect2i(1920, 0, 2560, 1400)


func test_window_modes() -> void:
	assert_eq(WindowRules.window_mode_for(false, true), DisplayServer.WINDOW_MODE_WINDOWED)
	assert_eq(WindowRules.window_mode_for(true, false), DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_eq(
		WindowRules.window_mode_for(true, true), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func test_ui_scale_snaps_to_a_choice() -> void:
	assert_eq(WindowRules.clean_ui_scale(1.0), 1.0)
	assert_eq(WindowRules.clean_ui_scale(1.3), 1.25)
	assert_eq(WindowRules.clean_ui_scale(99.0), 1.5)
	assert_eq(WindowRules.clean_ui_scale(-3.0), 0.85)


func test_saved_window_that_fits_is_kept() -> void:
	var rect := Rect2i(100, 80, 1280, 720)
	assert_eq(WindowRules.fit_window(rect, [SCREEN]), rect)


func test_too_small_or_too_big_is_clamped() -> void:
	assert_eq(WindowRules.fit_window(Rect2i(0, 0, 300, 200), [SCREEN]).size, WindowRules.MIN_SIZE)
	assert_eq(WindowRules.fit_window(Rect2i(0, 0, 5000, 3000), [SCREEN]).size, SCREEN.size)


func test_window_from_an_unplugged_monitor_comes_back() -> void:
	var lost := Rect2i(4000, 200, 1280, 720)
	var fitted: Rect2i = WindowRules.fit_window(lost, [SCREEN])
	assert_true(SCREEN.encloses(fitted), "back on the only screen")


func test_window_stays_on_the_screen_it_overlaps_most() -> void:
	var on_second := Rect2i(2000, 100, 1600, 900)
	assert_eq(WindowRules.fit_window(on_second, [SCREEN, SECOND]), on_second)
