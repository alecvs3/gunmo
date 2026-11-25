class_name BombLook
extends EnemyLook
## A Bomber's look: a round bomb strapped to its back with a short fuse. The fuse's spark
## blinks slowly while it walks and faster and faster while the fuse burns (its windup).

## Where the bomb sits (behind the head) and where its fuse ends.
const BOMB_AT := Vector2(-16.0, 0.0)
const FUSE_TIP := Vector2(-27.0, -9.0)

@export var bomb_color: Color = Color(0.18, 0.18, 0.22)
@export var outline_color: Color = Color(0.05, 0.05, 0.06)
@export var band_color: Color = Color(0.9, 0.35, 0.15)
@export var spark_color: Color = Color(1.0, 0.85, 0.3)
@export_range(2.0, 30.0) var bomb_radius: float = 9.0
## Spark blinks per second while walking, and at the very end of the fuse.
@export_range(0.1, 10.0) var idle_blinks: float = 1.5
@export_range(1.0, 40.0) var fuse_blinks: float = 14.0


func draw(canvas: CanvasItem, _speed: float, windup: float) -> void:
	canvas.draw_circle(BOMB_AT, bomb_radius + 1.5, outline_color)
	canvas.draw_circle(BOMB_AT, bomb_radius, bomb_color)
	canvas.draw_arc(BOMB_AT, bomb_radius * 0.7, PI * 0.35, PI * 0.65, 8, band_color, 3.0)
	canvas.draw_arc(BOMB_AT, bomb_radius * 0.7, -PI * 0.65, -PI * 0.35, 8, band_color, 3.0)
	var fuse_start: Vector2 = BOMB_AT + Vector2(-bomb_radius * 0.6, -bomb_radius * 0.6)
	canvas.draw_line(fuse_start, FUSE_TIP, outline_color, 2.0)
	if is_lit(Time.get_ticks_msec() / 1000.0, windup):
		canvas.draw_circle(FUSE_TIP, 3.0 + windup * 3.0, spark_color)


## Pure: whether the spark shows at `seconds` with `windup` (0..1) of the fuse burnt.
func is_lit(seconds: float, windup: float) -> bool:
	var rate: float = lerpf(idle_blinks, fuse_blinks, clampf(windup, 0.0, 1.0))
	return fposmod(seconds * rate, 1.0) < 0.5
