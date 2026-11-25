class_name HornsLook
extends EnemyLook
## A Charger's look: two curved horns growing from the sides of its head and pointing forward,
## and dust kicked up behind it while it moves fast (a dash).

## Where the head is in the sprite.
const HEAD := Vector2(-3.0, 0.0)
## One horn (the right-hand one; the other is its mirror), from the head forward.
const HORN: Array[Vector2] = [
	Vector2(-7.0, 5.0),
	Vector2(-2.0, 12.0),
	Vector2(6.0, 15.0),
	Vector2(15.0, 12.0),
	Vector2(5.0, 10.0),
	Vector2(-1.0, 6.0),
]
## Dust puffs behind it.
const PUFFS: int = 3

@export var horn_color: Color = Color(0.96, 0.92, 0.8)
@export var outline_color: Color = Color(0.25, 0.18, 0.12)
## Horn size (1 = the shape above).
@export_range(0.2, 3.0) var horn_scale: float = 1.0
## Moving faster than this (px/s) kicks up dust.
@export_range(0.0, 3000.0) var dust_speed: float = 300.0
@export var dust_color: Color = Color(0.78, 0.68, 0.52, 0.55)


func draw(canvas: CanvasItem, speed: float, _windup: float) -> void:
	if speed > dust_speed:
		_draw_dust(canvas)
	for side: float in [-1.0, 1.0]:
		var horn := PackedVector2Array()
		for point in HORN:
			horn.append(HEAD + Vector2(point.x, point.y * side) * horn_scale)
		canvas.draw_colored_polygon(horn, horn_color)
		horn.append(horn[0])
		canvas.draw_polyline(horn, outline_color, 1.5, true)


func _draw_dust(canvas: CanvasItem) -> void:
	var wobble: float = Time.get_ticks_msec() / 60.0
	for index in PUFFS:
		var back := Vector2(-20.0 - index * 9.0, sin(wobble + index * 2.1) * 4.0)
		var faded := Color(dust_color, dust_color.a * (1.0 - index / float(PUFFS)))
		canvas.draw_circle(back, 7.0 - index * 1.5, faded)
