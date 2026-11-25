class_name PathTokenArt
extends RefCounted
## How a Path node is drawn, on the board and in the detail panel: a round token in its look's
## colour with its icon (or first letter), a ring when selected, and a cross when locked out.
## Placeholder art: when real token frames and icons exist, only this file changes.

enum Look { OWNED, AVAILABLE, LOCKED, LOCKED_OUT }

const COLOURS: Array[Color] = [
	Color(0.45, 0.85, 0.5, 1),
	Color(1, 0.85, 0.35, 1),
	Color(0.5, 0.53, 0.58, 1),
	Color(0.88, 0.32, 0.3, 1),
]
const NAMES: Array[String] = ["Owned", "Available", "Locked", "Locked out"]
const SELECTED := Color(0.4, 0.85, 1, 1)
const FACE := Color(0.1, 0.11, 0.14, 1)
const RING_WIDTH: float = 3.0
const RING_POINTS: int = 48


## What a node looks like: its rules status, unless an owned rival shut it for the run.
static func look(status: PathRules.Status, locked_out: bool) -> Look:
	if locked_out:
		return Look.LOCKED_OUT
	return [Look.OWNED, Look.AVAILABLE, Look.LOCKED][status] as Look


## Locked and locked-out tokens are drawn faded.
static func is_dim(shown: Look) -> bool:
	return shown == Look.LOCKED or shown == Look.LOCKED_OUT


static func draw(
	canvas: Control,
	centre: Vector2,
	radius: float,
	path_node: PathNode,
	shown: Look,
	selected: bool
) -> void:
	var colour: Color = COLOURS[shown]
	var dim: bool = is_dim(shown)
	canvas.draw_circle(centre, radius, FACE, true, -1.0, true)
	canvas.draw_circle(centre, radius * 0.84, Color(colour, 0.12 if dim else 0.3), true, -1.0, true)
	var ring := Color(colour, 0.55 if dim else 1.0)
	canvas.draw_arc(centre, radius, 0.0, TAU, RING_POINTS, ring, RING_WIDTH, true)
	if selected:
		canvas.draw_arc(centre, radius + 6.0, 0.0, TAU, RING_POINTS, SELECTED, 2.0, true)
	_draw_face(canvas, centre, radius, path_node, Color(1, 1, 1, 0.45) if dim else Color.WHITE)
	if shown == Look.LOCKED_OUT:
		var reach := Vector2(radius, radius) * 0.55
		var flip := Vector2(reach.x, -reach.y)
		canvas.draw_line(centre - reach, centre + reach, colour, RING_WIDTH, true)
		canvas.draw_line(centre - flip, centre + flip, colour, RING_WIDTH, true)


## `text` centred on `centre_x`, sitting on `baseline`.
static func draw_centred(
	canvas: Control, text: String, centre_x: float, baseline: float, font_size: int, colour: Color
) -> void:
	var font: Font = canvas.get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(
		font,
		Vector2(centre_x - width / 2.0, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		colour
	)


## The node's icon, or its first letter until it has one.
static func _draw_face(
	canvas: Control, centre: Vector2, radius: float, path_node: PathNode, tint: Color
) -> void:
	if path_node.icon != null:
		var side := Vector2.ONE * radius * 1.1
		canvas.draw_texture_rect(path_node.icon, Rect2(centre - side / 2.0, side), false, tint)
		return
	var font_size: int = roundi(radius * 0.9)
	var font: Font = canvas.get_theme_default_font()
	var middle: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var letter: String = path_node.display_name.left(1).to_upper()
	draw_centred(canvas, letter, centre.x, centre.y + middle, font_size, tint)
