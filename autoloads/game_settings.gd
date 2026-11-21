extends Node
## Player-facing settings (audio, controls, display), saved in user://settings.cfg: the player's
## name, fullscreen (borderless, or exclusive if chosen), the UI scale, and the window's size and
## place (restored on start, kept on a screen that still exists). Also a report of the display.
## F11 or Alt+Enter toggles fullscreen. The window is resizable down to WindowRules.MIN_SIZE;
## nothing in the game depends on its size (WindowRules, FairView).
## The defaults live in project.godot: adaptive V-Sync (no tearing while the game keeps up,
## never waits when it falls behind), the shortest swapchain for the least input delay, and
## no frame cap, so the game draws at whatever rate the monitor refreshes.
## On laptops Godot asks the driver for the high-performance GPU; if a machine still lands
## on an integrated GPU, this logs a warning saying how to fix it.

signal fullscreen_changed(on: bool)
signal ui_scale_changed(scale: float)

const VSYNC_NAMES: Dictionary = {
	DisplayServer.VSYNC_DISABLED: "off",
	DisplayServer.VSYNC_ENABLED: "on",
	DisplayServer.VSYNC_ADAPTIVE: "adaptive",
	DisplayServer.VSYNC_MAILBOX: "mailbox",
}

const SETTINGS_PATH: String = "user://settings.cfg"

## Shown above your player and on the scoreboard ("" = "Player <id>").
var player_name: String = ""
## The game fills the screen instead of a window.
var fullscreen: bool = false
## Fullscreen takes the screen over (exclusive) instead of a borderless window: can cut a
## little latency on some systems, but Alt+Tab is slower.
var fullscreen_exclusive: bool = false
## Menu and HUD size (one of WindowRules.UI_SCALES). The world view stays the same (FairView).
var ui_scale: float = 1.0
## The last windowed size and place (zero size = none saved yet).
var window_rect := Rect2i()
## Where the settings are saved (tests point it at a file of their own).
var settings_path: String = SETTINGS_PATH


func _ready() -> void:
	_load()
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_min_size(WindowRules.MIN_SIZE)
	_restore_window()
	_apply_window_mode()
	_apply_ui_scale()
	print("[display] %s" % display_summary())
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		push_warning(
			(
				(
					"Rendering on an integrated GPU (%s). For best smoothness set Godot / the game to"
					% RenderingServer.get_video_adapter_name()
				)
				+ " 'High performance' in Windows Settings > System > Display > Graphics."
			)
		)


## One line: GPU, graphics API, V-Sync mode and refresh rate.
func display_summary() -> String:
	var vsync: String = VSYNC_NAMES.get(DisplayServer.window_get_vsync_mode(), "?")
	var screen: int = DisplayServer.window_get_current_screen()
	return (
		"%s · %s · V-Sync %s · %.0f Hz"
		% [
			RenderingServer.get_video_adapter_name(),
			RenderingServer.get_current_rendering_driver_name(),
			vsync,
			DisplayServer.screen_get_refresh_rate(screen),
		]
	)


## The window is closing: remember where it was.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_remember_window()


## Before the GUI, so Alt+Enter doesn't also press a focused button.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()


## Cleans and saves the name (it is also what the next session sends to the host).
func set_player_name(new_name: String) -> void:
	var cleaned: String = Handshake.clean_name(new_name)
	if cleaned == player_name:
		return
	player_name = cleaned
	_save_value("player", "name", player_name)


## Switches between fullscreen and a window, and saves the choice.
func set_fullscreen(on: bool) -> void:
	if on == fullscreen:
		return
	if on:
		_remember_window()
	fullscreen = on
	_save_value("display", "fullscreen", fullscreen)
	_apply_window_mode()
	if not on:
		_restore_window()
	fullscreen_changed.emit(fullscreen)


func set_fullscreen_exclusive(on: bool) -> void:
	fullscreen_exclusive = on
	_save_value("display", "fullscreen_exclusive", on)
	_apply_window_mode()


## Saves and applies the nearest scale on offer.
func set_ui_scale(scale: float) -> void:
	var cleaned: float = WindowRules.clean_ui_scale(scale)
	if is_equal_approx(cleaned, ui_scale):
		return
	ui_scale = cleaned
	_save_value("display", "ui_scale", ui_scale)
	_apply_ui_scale()
	ui_scale_changed.emit(ui_scale)


static func window_mode_for(on: bool, exclusive: bool = false) -> DisplayServer.WindowMode:
	return WindowRules.window_mode_for(on, exclusive)


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(window_mode_for(fullscreen, fullscreen_exclusive))


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = ui_scale


## Windowed only: saves the window's size and place.
func _remember_window() -> void:
	if DisplayServer.get_name() == "headless" or fullscreen:
		return
	window_rect = Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	_save_value("display", "window_rect", window_rect)


## Puts the window back where it was saved, on a screen that still exists.
func _restore_window() -> void:
	if DisplayServer.get_name() == "headless" or window_rect.size == Vector2i.ZERO:
		return
	var screens: Array[Rect2i] = []
	for i in DisplayServer.get_screen_count():
		screens.append(DisplayServer.screen_get_usable_rect(i))
	var fitted: Rect2i = WindowRules.fit_window(window_rect, screens)
	DisplayServer.window_set_size(fitted.size)
	DisplayServer.window_set_position(fitted.position)


func _save_value(section: String, key: String, value: Variant) -> void:
	var file := ConfigFile.new()
	file.load(settings_path)
	file.set_value(section, key, value)
	file.save(settings_path)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(settings_path) == OK:
		player_name = Handshake.clean_name(file.get_value("player", "name", ""))
		fullscreen = file.get_value("display", "fullscreen", false) == true
		fullscreen_exclusive = file.get_value("display", "fullscreen_exclusive", false) == true
		var scale: Variant = file.get_value("display", "ui_scale", 1.0)
		ui_scale = WindowRules.clean_ui_scale(
			float(scale) if scale is float or scale is int else 1.0
		)
		var rect: Variant = file.get_value("display", "window_rect", Rect2i())
		window_rect = rect if rect is Rect2i else Rect2i()
