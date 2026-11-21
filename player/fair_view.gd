class_name FairView
extends RefCounted
## Everyone sees at most the same piece of the world, whatever their window's size or shape:
## a box of PlayerData.view_size world pixels around their player. Nobody ever sees more.
## A window close to the box's shape (a maximized window, 16:10) is filled edge to edge by
## showing up to `max_crop` less of the box on one axis. Only a window further off (21:9, a
## tall window) gets bars (ui/view_mask.gd) over what would be extra world. The HUD and menus
## always use the whole window. Pure, so it is unit-tested.


## Camera2D zoom (same on both axes, higher = closer) for a window whose visible canvas is
## `visible_size`: as close to filling it as `max_crop` (0..1) allows.
static func zoom_for(visible_size: Vector2, view_size: Vector2, max_crop: float = 0.0) -> float:
	if view_size.x <= 0.0 or view_size.y <= 0.0 or visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return 1.0
	var fit: float = minf(visible_size.x / view_size.x, visible_size.y / view_size.y)
	var cover: float = maxf(visible_size.x / view_size.x, visible_size.y / view_size.y)
	return minf(cover, fit / (1.0 - clampf(max_crop, 0.0, 0.9)))


## The part of the screen (canvas units) that shows the world: the box at that zoom, centered,
## cut to the window. Everything outside it is covered by bars.
static func box_on_screen(
	visible_size: Vector2, view_size: Vector2, max_crop: float = 0.0
) -> Rect2:
	var size: Vector2 = view_size * zoom_for(visible_size, view_size, max_crop)
	var box := Rect2((visible_size - size) * 0.5, size)
	return box.intersection(Rect2(Vector2.ZERO, visible_size))
