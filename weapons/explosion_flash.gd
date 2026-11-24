class_name ExplosionFlash
extends Node2D
## A blast as everyone sees it: a filled ring that grows to the blast radius and fades out.
## Looks only: the host already dealt the damage.

## Seconds on screen.
@export_range(0.05, 2.0) var lifetime: float = 0.35
@export var color: Color = Color(1.0, 0.55, 0.15)

var radius: float = 0.0

var _age: float = 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	z_index = 1  # over the characters: the bullets it shares a parent with draw under them


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = _age / lifetime
	var fade: float = 1.0 - progress
	var size: float = radius * (0.5 + 0.5 * sqrt(progress))
	draw_circle(Vector2.ZERO, size, Color(color, 0.35 * fade))
	draw_circle(Vector2.ZERO, size * 0.45, Color(1.0, 0.9, 0.6, 0.6 * fade))
	draw_arc(Vector2.ZERO, size, 0.0, TAU, 40, Color(color, fade), 3.0)
