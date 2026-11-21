extends Node
## Player-facing settings (audio, controls, display). For now: the player's name (saved in
## user://settings.cfg) and a report of the display setup.
## The defaults live in project.godot: adaptive V-Sync (no tearing while the game keeps up,
## never waits when it falls behind), the shortest swapchain for the least input delay, and
## no frame cap, so the game draws at whatever rate the monitor refreshes.
## On laptops Godot asks the driver for the high-performance GPU; if a machine still lands
## on an integrated GPU, this logs a warning saying how to fix it.

const VSYNC_NAMES: Dictionary = {
	DisplayServer.VSYNC_DISABLED: "off",
	DisplayServer.VSYNC_ENABLED: "on",
	DisplayServer.VSYNC_ADAPTIVE: "adaptive",
	DisplayServer.VSYNC_MAILBOX: "mailbox",
}

const SETTINGS_PATH: String = "user://settings.cfg"

## Shown above your player and on the scoreboard ("" = "Player <id>").
var player_name: String = ""


func _ready() -> void:
	_load()
	if DisplayServer.get_name() == "headless":
		return
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


## Cleans and saves the name (it is also what the next session sends to the host).
func set_player_name(new_name: String) -> void:
	var cleaned: String = Handshake.clean_name(new_name)
	if cleaned == player_name:
		return
	player_name = cleaned
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	file.set_value("player", "name", player_name)
	file.save(SETTINGS_PATH)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		player_name = Handshake.clean_name(file.get_value("player", "name", ""))
