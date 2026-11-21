extends Node
## Player-facing settings (audio, controls, display). For now: the player's name and fullscreen
## (both saved in user://settings.cfg) and a report of the display setup.
## Fullscreen is borderless (covers the screen, quick Alt+Tab); F11 or Alt+Enter toggles it.
## The defaults live in project.godot: adaptive V-Sync (no tearing while the game keeps up,
## never waits when it falls behind), the shortest swapchain for the least input delay, and
## no frame cap, so the game draws at whatever rate the monitor refreshes.
## On laptops Godot asks the driver for the high-performance GPU; if a machine still lands
## on an integrated GPU, this logs a warning saying how to fix it.

signal fullscreen_changed(on: bool)

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
## Where the settings are saved (tests point it at a file of their own).
var settings_path: String = SETTINGS_PATH


func _ready() -> void:
	_load()
	if DisplayServer.get_name() == "headless":
		return
	_apply_window_mode()
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
	fullscreen = on
	_save_value("display", "fullscreen", fullscreen)
	_apply_window_mode()
	fullscreen_changed.emit(fullscreen)


static func window_mode_for(on: bool) -> DisplayServer.WindowMode:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(window_mode_for(fullscreen))


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
