class_name HurtIndicator
extends Control
## When a bullet hits our own player, a red arc near the edge of the screen points toward
## where it came from and fades out. With high latency the damage can land a moment before
## the bullet looks like it arrived; the marker makes clear who hit you and from where.
## Driven by EventBus.local_player_hurt (the host's verdict, see ProjectileSystem.EVENT_HURT).

const SHOW_SECONDS: float = 0.6
const COLOR := Color(1.0, 0.2, 0.15, 0.85)
## How far from the screen centre the arc sits, as a share of the smaller screen side.
const RADIUS_SHARE: float = 0.38
const ARC_DEGREES: float = 40.0
const WIDTH: float = 10.0
const MAX_MARKERS: int = 6

## [direction (Vector2), seconds left] per recent hit.
var _markers: Array = []


## Where on screen (around `center`, at `radius`) the arc for a hit from `from_direction`
## starts and ends, as angles in radians.
static func arc_angles(from_direction: Vector2) -> Vector2:
	var middle: float = from_direction.angle()
	var half: float = deg_to_rad(ARC_DEGREES) * 0.5
	return Vector2(middle - half, middle + half)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.local_player_hurt.connect(_on_hurt)
	NetworkManager.session_ended.connect(func(_reason: String) -> void: _markers.clear())


func _process(delta: float) -> void:
	if _markers.is_empty():
		return
	for marker: Array in _markers:
		marker[1] -= delta
	_markers = _markers.filter(func(marker: Array) -> bool: return marker[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * RADIUS_SHARE
	for marker: Array in _markers:
		var angles: Vector2 = arc_angles(marker[0])
		var color: Color = COLOR
		color.a *= clampf(marker[1] / SHOW_SECONDS, 0.0, 1.0)
		draw_arc(center, radius, angles.x, angles.y, 24, color, WIDTH, true)


func _on_hurt(from_direction: Vector2) -> void:
	if from_direction.is_zero_approx():
		return
	_markers.append([from_direction.normalized(), SHOW_SECONDS])
	while _markers.size() > MAX_MARKERS:
		_markers.pop_front()
	queue_redraw()
