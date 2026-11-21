class_name EffectFlash
extends Node2D
## A short flash for a shock arc (a jagged line) or a blast (a ring that grows), drawn in world
## space and gone after LIFETIME. Looks only: the host already applied the damage.

const LIFETIME: float = 0.25
const ARC_COLOR := Color(0.8, 0.6, 1.0)
const BLAST_COLOR := Color(1.0, 0.75, 0.35)

var kind: int = 0
var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO

var _age: float = 0.0


func setup(flash_kind: int, from_point: Vector2, to_point: Vector2) -> void:
	kind = flash_kind
	from = from_point
	to = to_point


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - _age / LIFETIME
	if kind == HitEffects.SHOCK:
		draw_polyline(_jagged_line(), Color(ARC_COLOR, fade), 2.0)
	elif kind == HitEffects.BLAST:
		var radius: float = to.x * (0.6 + 0.4 * _age / LIFETIME)
		draw_circle(from, radius, Color(BLAST_COLOR, 0.25 * fade))
		draw_arc(from, radius, 0.0, TAU, 32, Color(BLAST_COLOR, fade), 3.0)


## The arc as a zigzag; the same shape on every frame of one flash.
func _jagged_line() -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var side: Vector2 = (to - from).orthogonal().normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([from, to])
	for i in range(1, 6):
		points.append(from.lerp(to, i / 6.0) + side * rng.randf_range(-8.0, 8.0))
	points.append(to)
	return points
