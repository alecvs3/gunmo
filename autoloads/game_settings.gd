extends Node
## Player-facing settings (audio, controls, display). For now: reports the display setup.
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


func _ready() -> void:
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
