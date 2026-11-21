class_name WindowRules
extends RefCounted
## The rules for the game window, pure so they are unit-tested (GameSettings applies them).
## The game itself never depends on the window: movement, shooting and aim run on ticks in
## world units, and FairView gives every window the same view of the world.

## Smallest window the menus are laid out for (at UI scale 1).
const MIN_SIZE := Vector2i(960, 540)
## UI scale choices (menu and HUD size), smallest first.
const UI_SCALES: Array[float] = [0.85, 1.0, 1.25, 1.5]


static func window_mode_for(fullscreen: bool, exclusive: bool) -> DisplayServer.WindowMode:
	if not fullscreen:
		return DisplayServer.WINDOW_MODE_WINDOWED
	if exclusive:
		return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_FULLSCREEN


## The nearest UI scale on offer (a hand-edited settings file can hold anything).
static func clean_ui_scale(scale: float) -> float:
	var best: float = 1.0
	for choice in UI_SCALES:
		if absf(choice - scale) < absf(best - scale):
			best = choice
	return best


## A saved window `rect` made usable on these `screens` (their usable areas): at least
## MIN_SIZE, at most a screen, and moved back onto the screen it overlaps most (or the first
## one) so a window saved on an unplugged monitor doesn't open off-screen.
static func fit_window(rect: Rect2i, screens: Array[Rect2i]) -> Rect2i:
	if screens.is_empty():
		return rect
	var screen: Rect2i = screens[0]
	var best_overlap: int = -1
	for candidate in screens:
		var overlap: Rect2i = candidate.intersection(rect)
		if overlap.get_area() > best_overlap:
			best_overlap = overlap.get_area()
			screen = candidate
	var size := Vector2i(
		clampi(rect.size.x, mini(MIN_SIZE.x, screen.size.x), screen.size.x),
		clampi(rect.size.y, mini(MIN_SIZE.y, screen.size.y), screen.size.y)
	)
	var position := Vector2i(
		clampi(rect.position.x, screen.position.x, screen.end.x - size.x),
		clampi(rect.position.y, screen.position.y, screen.end.y - size.y)
	)
	return Rect2i(position, size)
