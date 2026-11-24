class_name ShopPips
extends Control
## An upgrade's level as a row of dots: gold for bought levels, dark for the rest. `pop()` makes
## the newest gold dot swell and settle, for a purchase the host just confirmed.

const DOT: float = 10.0
const GAP: float = 4.0
const FILLED_COLOR: Color = Color(1, 0.82, 0.3)
const EMPTY_COLOR: Color = Color(0.25, 0.27, 0.31)
const POP_SECONDS: float = 0.35
## How much bigger the newest dot starts when it pops.
const POP_GROWTH: float = 0.9

var level: int = 0:
	set(value):
		if value != level:
			level = value
			queue_redraw()
var max_level: int = 1:
	set(value):
		if value != max_level:
			max_level = value
			custom_minimum_size = Vector2(width_for(value), DOT + DOT * POP_GROWTH)
			queue_redraw()

var _pop: float = 0.0


static func width_for(dots: int) -> float:
	return maxf(dots * DOT + (dots - 1) * GAP, 0.0)


func _ready() -> void:
	custom_minimum_size = Vector2(width_for(max_level), DOT + DOT * POP_GROWTH)


func pop() -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_pop, 1.0, 0.0, POP_SECONDS).set_trans(Tween.TRANS_BACK)


func _set_pop(value: float) -> void:
	_pop = value
	queue_redraw()


func _draw() -> void:
	var left: float = size.x - width_for(max_level)
	for i in max_level:
		var center := Vector2(left + i * (DOT + GAP) + DOT / 2.0, size.y / 2.0)
		var radius: float = DOT / 2.0
		if i == level - 1:
			radius *= 1.0 + POP_GROWTH * _pop
		draw_circle(center, radius, FILLED_COLOR if i < level else EMPTY_COLOR)
