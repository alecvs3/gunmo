class_name PetLook
extends RefCounted
## How a pet is drawn, the same in the world (PetFollower) and in the Pets menu (PetPortrait):
## a round body in the pet's colour with eyes, the kind's mark (Healer: a cross and a halo,
## Wizard: a pointed hat with a star, Soldier: a helmet with a visor) and one gold pip per tier.
## Drawn with shapes, so no art is needed. Looks only.

const OUTLINE := Color(0.05, 0.05, 0.07, 0.9)
const PIP := Color(1, 0.85, 0.35, 1)
const PIP_EMPTY := Color(1, 1, 1, 0.18)


## Draws the pet centred on `at` with body radius `r` onto `canvas`. `time` (seconds) drives
## the small animations; `tier` 0..5 fills the pips (`show_pips` false hides them).
static func draw(
	canvas: CanvasItem,
	pet: PetData,
	tier: int,
	at: Vector2,
	r: float,
	time: float,
	show_pips: bool = true
) -> void:
	var bob: Vector2 = Vector2(0, sin(time * 3.0) * r * 0.08)
	var centre: Vector2 = at + bob
	_draw_aura(canvas, pet, centre, r, time)
	canvas.draw_circle(centre, r * 1.08, OUTLINE)
	canvas.draw_circle(centre, r, pet.color)
	canvas.draw_circle(centre + Vector2(-r * 0.3, -r * 0.35), r * 0.35, Color(1, 1, 1, 0.18))
	_draw_eyes(canvas, centre, r, time)
	match pet.kind:
		PetData.Kind.HEALER:
			_draw_cross(canvas, centre + Vector2(0, r * 0.45), r * 0.32)
		PetData.Kind.WIZARD:
			_draw_hat(canvas, centre, r, time)
		PetData.Kind.SOLDIER:
			_draw_helmet(canvas, centre, r)
	if show_pips:
		_draw_pips(canvas, at + Vector2(0, r * 1.55), r, tier)


static func _draw_aura(
	canvas: CanvasItem, pet: PetData, centre: Vector2, r: float, time: float
) -> void:
	var pulse: float = 0.5 + 0.5 * sin(time * 2.2)
	canvas.draw_circle(centre, r * (1.45 + 0.12 * pulse), Color(pet.color, 0.10 + 0.06 * pulse))
	if pet.kind == PetData.Kind.HEALER:
		canvas.draw_arc(centre + Vector2(0, -r * 1.25), r * 0.5, PI, TAU, 16, Color(1, 1, 0.7), 2.0)


static func _draw_eyes(canvas: CanvasItem, centre: Vector2, r: float, time: float) -> void:
	var blink: float = 0.15 if fmod(time, 3.7) < 0.12 else 1.0
	for side in [-1.0, 1.0]:
		var eye: Vector2 = centre + Vector2(side * r * 0.34, -r * 0.08)
		canvas.draw_set_transform(eye, 0.0, Vector2(1.0, blink))
		canvas.draw_circle(Vector2.ZERO, r * 0.2, Color.WHITE)
		canvas.draw_circle(Vector2(r * 0.04, r * 0.03), r * 0.1, OUTLINE)
		canvas.draw_set_transform(Vector2.ZERO)


static func _draw_cross(canvas: CanvasItem, centre: Vector2, size: float) -> void:
	var thick: float = size * 0.36
	canvas.draw_rect(Rect2(centre - Vector2(size, thick) / 2.0, Vector2(size, thick)), Color.WHITE)
	canvas.draw_rect(Rect2(centre - Vector2(thick, size) / 2.0, Vector2(thick, size)), Color.WHITE)


static func _draw_hat(canvas: CanvasItem, centre: Vector2, r: float, time: float) -> void:
	var brim: float = centre.y - r * 0.62
	var tip := Vector2(centre.x + r * 0.35, centre.y - r * 1.85)
	var hat := PackedVector2Array(
		[Vector2(centre.x - r * 0.9, brim), Vector2(centre.x + r * 0.9, brim), tip]
	)
	canvas.draw_colored_polygon(hat, Color(0.32, 0.22, 0.7))
	canvas.draw_polyline(hat + PackedVector2Array([hat[0]]), OUTLINE, 2.0)
	var star: Vector2 = Vector2(centre.x + r * 0.05, centre.y - r * 1.05)
	var twinkle: float = 0.7 + 0.3 * sin(time * 5.0)
	canvas.draw_circle(star, r * 0.13 * twinkle, Color(1, 0.95, 0.5))


static func _draw_helmet(canvas: CanvasItem, centre: Vector2, r: float) -> void:
	canvas.draw_arc(centre, r * 0.98, PI + 0.15, TAU - 0.15, 20, Color(0.3, 0.38, 0.22), r * 0.42)
	var visor := Rect2(centre + Vector2(-r * 0.7, -r * 0.3), Vector2(r * 1.4, r * 0.16))
	canvas.draw_rect(visor, OUTLINE)


static func _draw_pips(canvas: CanvasItem, centre: Vector2, r: float, tier: int) -> void:
	var gap: float = r * 0.42
	for i in PetData.TIERS:
		var at: Vector2 = centre + Vector2((i - 2) * gap, 0)
		canvas.draw_circle(at, r * 0.13, PIP if i < tier else PIP_EMPTY)
