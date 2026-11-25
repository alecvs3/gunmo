class_name EnemyTelegraph
extends Node2D
## A ring that fills with `progress` (0..1, from the host's snapshots on clients): the warning
## of an enemy's telegraphed attack, or a teammate's revive over a downed player. Looks only.
## A Charger's windup also draws a line along its dash, and a stunned enemy circling stars.

## Stars over a stunned enemy, and how fast they circle (radians per second).
const STARS: int = 3
const STAR_SPIN: float = 4.0

var color := Color(1.0, 0.25, 0.2, 0.85)

## How full the windup is (0 = not winding up: nothing is drawn).
var progress: float = 0.0:
	set(value):
		if not is_equal_approx(value, progress):
			progress = value
			queue_redraw()
## Ring radius (px); bosses scale it with their body.
var radius: float = 30.0
## A Wizard's hex: a purple diamond above it.
var hexed: bool = false:
	set(value):
		if value != hexed:
			hexed = value
			queue_redraw()
## Length (px) of the dash line drawn during a windup (0 = no line: not a Charger).
var line_length: float = 0.0
## Which way the dash line points (radians).
var line_angle: float = 0.0:
	set(value):
		if not is_equal_approx(value, line_angle):
			line_angle = value
			if progress > 0.0 and line_length > 0.0:
				queue_redraw()
## Stunned (a Charger that ran into a wall): stars circle above it.
var stunned: bool = false:
	set(value):
		if value != stunned:
			stunned = value
			set_process(stunned)
			queue_redraw()


func _ready() -> void:
	set_process(stunned)


## Only while stunned: the stars move.
func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hexed:
		var top := Vector2(0, -radius * 1.9)
		var mark := PackedVector2Array(
			[top + Vector2(0, -9), top + Vector2(7, 0), top + Vector2(0, 9), top + Vector2(-7, 0)]
		)
		draw_colored_polygon(mark, Color(0.8, 0.4, 1, 0.9))
	if stunned:
		_draw_stars()
	if progress <= 0.0:
		return
	if line_length > 0.0:
		_draw_dash_line()
	draw_arc(Vector2.ZERO, radius * 1.4, 0.0, TAU, 48, Color(color, 0.25), 3.0)
	draw_arc(Vector2.ZERO, radius * 1.4, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, color, 4.0)
	draw_circle(Vector2.ZERO, radius * (0.4 + 0.9 * progress), Color(color, 0.12 * progress))


## Where a Charger will dash: a faint lane the length of the dash, filling as the windup does.
func _draw_dash_line() -> void:
	var ahead: Vector2 = Vector2.from_angle(line_angle) * line_length
	draw_line(Vector2.ZERO, ahead, Color(color, 0.16), radius * 1.6)
	draw_line(Vector2.ZERO, ahead * progress, Color(color, 0.4), radius * 0.5)
	draw_circle(ahead, radius * 0.35, Color(color, 0.5 * progress))


func _draw_stars() -> void:
	var spin: float = Time.get_ticks_msec() / 1000.0 * STAR_SPIN
	var center := Vector2(0, -radius * 1.5)
	for index in STARS:
		var angle: float = spin + TAU * index / STARS
		var at: Vector2 = center + Vector2(cos(angle) * radius * 0.7, sin(angle) * radius * 0.25)
		var star := PackedVector2Array(
			[
				at + Vector2(0, -5),
				at + Vector2(1.5, -1.5),
				at + Vector2(5, 0),
				at + Vector2(1.5, 1.5),
				at + Vector2(0, 5),
				at + Vector2(-1.5, 1.5),
				at + Vector2(-5, 0),
				at + Vector2(-1.5, -1.5)
			]
		)
		draw_colored_polygon(star, Color(1.0, 0.92, 0.35, 0.95))
