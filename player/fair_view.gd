class_name FairView
extends RefCounted
## Everyone sees the same piece of the world, whatever their window's size or shape: a box of
## PlayerData.view_size world pixels around their player. The camera zooms so that box just
## fits the window; whatever else of the world a wider or taller window would show is covered
## by bars (ui/view_mask.gd), so an ultrawide screen sees no further than anyone else. The HUD
## and menus still use the whole window. Pure, so it is unit-tested.


## Camera2D zoom (same on both axes) that fits a `view_size` box of world into a window whose
## visible canvas is `visible_size` (higher = closer).
static func zoom_for(visible_size: Vector2, view_size: Vector2) -> float:
	if view_size.x <= 0.0 or view_size.y <= 0.0 or visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return 1.0
	return minf(visible_size.x / view_size.x, visible_size.y / view_size.y)


## Where that box sits on the screen (canvas units): centered, touching two opposite edges.
static func box_on_screen(visible_size: Vector2, view_size: Vector2) -> Rect2:
	var size: Vector2 = view_size * zoom_for(visible_size, view_size)
	return Rect2((visible_size - size) * 0.5, size)
