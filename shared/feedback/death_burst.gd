class_name DeathBurst
extends Node2D
## A dying enemy's burst: square pieces in its colour fly out, slow down, shrink and fade, then
## the node frees itself. Looks only (its randomness never touches gameplay).

var color: Color = Color.WHITE
## The enemy's size (EnemyData.body_scale); bigger enemies burst into bigger pieces.
var size_scale: float = 1.0
var data: FeedbackData

var _age: float = 0.0
var _directions: Array[Vector2] = []
var _speeds: Array[float] = []


## How far a piece launched at `speed` has flown after `age` of `seconds` (it slows down).
static func travel(speed: float, age: float, seconds: float) -> float:
	var t: float = clampf(age / maxf(seconds, 0.001), 0.0, 1.0)
	return speed * seconds * (t - t * t / 2.0)


func _ready() -> void:
	z_index = 50
	var rng := RandomNumberGenerator.new()
	for i in data.burst_pieces:
		var angle: float = TAU * i / maxf(data.burst_pieces, 1) + rng.randf_range(-0.3, 0.3)
		_directions.append(Vector2.from_angle(angle))
		_speeds.append(data.burst_speed * rng.randf_range(0.6, 1.2) * sqrt(size_scale))


func _process(delta: float) -> void:
	_age += delta
	if _age >= data.burst_seconds:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / data.burst_seconds
	var side: float = data.burst_piece_size * size_scale * (1.0 - t * 0.6)
	var faded := Color(color, 1.0 - t)
	for i in _directions.size():
		var center: Vector2 = _directions[i] * travel(_speeds[i], _age, data.burst_seconds)
		draw_rect(Rect2(center - Vector2.ONE * side / 2.0, Vector2.ONE * side), faded)
