class_name StatusMarks
extends Node2D
## Draws what a StatusEffectsComponent's flags say: an orange ring while burning, a blue one
## while chilled, red ticks while shredded. Looks only; every peer draws its own.

const BURN_COLOR := Color(1.0, 0.5, 0.1, 0.9)
const CHILL_COLOR := Color(0.45, 0.85, 1.0, 0.9)
const SHRED_COLOR := Color(1.0, 0.25, 0.35, 0.95)

@export var status: StatusEffectsComponent
## Ring size (px), a little bigger than the body.
@export_range(4.0, 200.0) var radius: float = 20.0

var _drawn_flags: int = -1
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var flags: int = status.flags if status != null else 0
	if flags != _drawn_flags or flags & HitEffects.BURN:
		_drawn_flags = flags
		queue_redraw()


func _draw() -> void:
	if _drawn_flags <= 0:
		return
	if _drawn_flags & HitEffects.CHILL:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 32, CHILL_COLOR, 3.0)
	if _drawn_flags & HitEffects.BURN:
		var flicker: float = 0.75 + 0.25 * sin(_time * 18.0)
		draw_arc(Vector2.ZERO, radius * flicker + 4.0, 0.0, TAU, 24, BURN_COLOR, 2.0)
	if _drawn_flags & HitEffects.SHRED:
		for i in 4:
			var direction: Vector2 = Vector2.from_angle(TAU * i / 4.0 + PI / 4.0)
			draw_line(direction * radius, direction * (radius + 7.0), SHRED_COLOR, 3.0)
