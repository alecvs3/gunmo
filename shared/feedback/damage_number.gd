class_name DamageNumber
extends Node2D
## A damage number that pops, rises and fades, then frees itself. Looks only.

var amount: int = 0
var big: bool = false
var data: FeedbackData

var _age: float = 0.0
var _start: Vector2 = Vector2.ZERO


## Scale over its life: starts large and settles, so it "pops".
static func pop_scale(age: float, seconds: float) -> float:
	var settle: float = clampf(age / maxf(seconds * 0.25, 0.001), 0.0, 1.0)
	return lerpf(1.6, 1.0, settle)


## Opacity: full for the first half, then fades out.
static func fade(age: float, seconds: float) -> float:
	var t: float = clampf(age / maxf(seconds, 0.001), 0.0, 1.0)
	return 1.0 if t < 0.5 else 1.0 - (t - 0.5) * 2.0


func _ready() -> void:
	_start = position
	z_index = 100


func _process(delta: float) -> void:
	_age += delta
	if _age >= data.number_seconds:
		queue_free()
		return
	var t: float = _age / data.number_seconds
	position = _start + Vector2.UP * data.number_rise * (1.0 - pow(1.0 - t, 2.0))
	scale = Vector2.ONE * pop_scale(_age, data.number_seconds)
	modulate.a = fade(_age, data.number_seconds)
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = data.big_number_size if big else data.number_size
	var color: Color = data.big_number_color if big else data.number_color
	var text: String = str(amount)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-width / 2.0, size / 3.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
