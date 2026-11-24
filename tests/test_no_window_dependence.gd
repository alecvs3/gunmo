extends GutTest
## Gameplay never depends on the window: movement, shooting, hits, bots, enemies, modes and the
## netcode run on ticks in world units, so a big window, a small one, fullscreen or a different
## frame rate all play the same and every peer agrees. This fails if gameplay code reads the
## window, the viewport's size or the frame rate. Drawing and input code may (see ALLOWED).

const GAMEPLAY_FOLDERS: Array[String] = [
	"res://player",
	"res://weapons",
	"res://enemies",
	"res://bots",
	"res://modes",
	"res://upgrades",
	"res://levels",
	"res://shared",
]
const FORBIDDEN: Array[String] = [
	"get_viewport",
	"get_window",
	"DisplayServer.",
	"get_frames_per_second",
	"get_visible_rect",
	"content_scale",
]
## Files that only draw or read the owner's input, and why they may look at the screen.
const ALLOWED: Dictionary = {
	"res://player/player_input_source.gd": "turns the mouse into an aim angle (world space)",
	"res://player/player_camera.gd": "zooms to the fair view box (FairView)",
	"res://modes/game_mode.gd": "marks the ready key as handled",
	"res://shared/network/net_log.gd": "skips log files when headless",
	"res://shared/feedback/sound_playback.gd": "stays silent when headless (sounds only)",
	"res://shared/window_rules.gd": "the window's own rules (modes, size), used by GameSettings",
}


func test_gameplay_code_does_not_read_the_window() -> void:
	var checked: int = 0
	for folder in GAMEPLAY_FOLDERS:
		for path in _scripts(folder):
			checked += 1
			if ALLOWED.has(path):
				continue
			var text: String = FileAccess.get_file_as_string(path)
			for word in FORBIDDEN:
				assert_false(word in text, "%s uses %s" % [path, word])
	assert_gt(checked, 50, "the gameplay scripts were found")


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(child)))
	return found
