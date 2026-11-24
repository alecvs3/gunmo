class_name PetPortrait
extends Control
## A pet's picture in the Pets menu: PetLook drawn to fit, gently animated.

var pet: PetData = null:
	set(value):
		pet = value
		queue_redraw()
var tier: int = 0:
	set(value):
		tier = value
		queue_redraw()
var show_pips: bool = true

var _time: float = 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree() and pet != null:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if pet == null:
		return
	var r: float = minf(size.x, size.y) * 0.24
	PetLook.draw(self, pet, tier, size / 2.0 - Vector2(0, r * 0.25), r, _time, show_pips)
