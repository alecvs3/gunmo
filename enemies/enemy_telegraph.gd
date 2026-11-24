class_name EnemyTelegraph
extends Node2D
## The warning ring of a telegraphed attack: a ring around the enemy that fills as the windup
## runs (progress 0..1, from the host's snapshots on clients). Looks only.

const COLOR := Color(1.0, 0.25, 0.2, 0.85)

## How full the windup is (0 = not winding up: nothing is drawn).
var progress: float = 0.0:
	set(value):
		if not is_equal_approx(value, progress):
			progress = value
			queue_redraw()
## Ring radius (px); bosses scale it with their body.
var radius: float = 30.0


func _draw() -> void:
	if progress <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius * 1.4, 0.0, TAU, 48, Color(COLOR, 0.25), 3.0)
	draw_arc(Vector2.ZERO, radius * 1.4, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, COLOR, 4.0)
	draw_circle(Vector2.ZERO, radius * (0.4 + 0.9 * progress), Color(COLOR, 0.12 * progress))
