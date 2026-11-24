class_name PetEffects
extends Node2D
## Every peer: draws what pets do, as the host announces it (heals, lightning, runes, marks,
## airstrikes). The host calls PetEffects.broadcast(): it shows here at once (EventBus
## pet_effect_shown) and goes to every client as a reliable NetChannel event. Looks only.

enum Kind { HEAL, ARC, RUNE, HEX, STRIKE_WARNING, STRIKE, TEMPEST_WARNING, RALLY, TRACER }

## NetChannel event topic (ProjectileSystem uses 1, the kill feed 3):
## [u8 kind, f32 radius, f32 seconds, u8 count, count x (f32, f32) points].
const TOPIC: int = 4
const MAX_POINTS: int = 16
const COLORS: Dictionary = {
	Kind.HEAL: Color(0.45, 1, 0.6),
	Kind.ARC: Color(0.55, 0.75, 1),
	Kind.RUNE: Color(0.6, 0.85, 1),
	Kind.HEX: Color(0.8, 0.4, 1),
	Kind.STRIKE_WARNING: Color(1, 0.45, 0.2),
	Kind.STRIKE: Color(1, 0.85, 0.4),
	Kind.TEMPEST_WARNING: Color(0.55, 0.75, 1),
	Kind.RALLY: Color(1, 0.7, 0.35),
	Kind.TRACER: Color(1, 0.9, 0.55),
}


## One effect being drawn.
class Shown:
	var kind: int
	var points: PackedVector2Array
	var radius: float
	var seconds: float
	var age: float = 0.0


var _shown: Array[Shown] = []
var _rng := RandomNumberGenerator.new()


## Host: show an effect on every peer for `seconds`.
static func broadcast(
	kind: int, points: PackedVector2Array, radius: float = 0.0, seconds: float = 0.5
) -> void:
	EventBus.pet_effect_shown.emit(kind, points, radius, seconds)
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(kind)
	buffer.put_float(radius)
	buffer.put_float(seconds)
	var count: int = mini(points.size(), MAX_POINTS)
	buffer.put_u8(count)
	for i in count:
		NetCodec.put_vector2(buffer, points[i])
	for peer_id in NetworkManager.multiplayer.get_peers():
		NetworkManager.channel.send_event(peer_id, TOPIC, buffer.data_array)


## Clients: an announced effect, checked like any packet (only the host sends these).
static func decode(data: PackedByteArray) -> Array:
	if data.size() < 10:
		return []
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(data)
	var kind: int = buffer.get_u8()
	var radius: float = buffer.get_float()
	var seconds: float = buffer.get_float()
	var count: int = buffer.get_u8()
	if kind >= Kind.size() or count > MAX_POINTS or data.size() != 10 + count * 8:
		return []
	var points := PackedVector2Array()
	for i in count:
		points.append(NetCodec.get_vector2(buffer))
	if not is_finite(radius) or not is_finite(seconds):
		return []
	return [kind, points, clampf(radius, 0.0, 2000.0), clampf(seconds, 0.05, 5.0)]


func _ready() -> void:
	z_index = 6
	EventBus.pet_effect_shown.connect(_add)
	if not multiplayer.is_server():
		NetworkManager.channel.event_received.connect(_on_event_received)


func _on_event_received(topic: int, data: PackedByteArray) -> void:
	if topic != TOPIC:
		return
	var effect: Array = decode(data)
	if not effect.is_empty():
		EventBus.pet_effect_shown.emit(effect[0], effect[1], effect[2], effect[3])


func _add(kind: int, points: PackedVector2Array, radius: float, seconds: float) -> void:
	var shown := Shown.new()
	shown.kind = kind
	shown.points = points
	shown.radius = radius
	shown.seconds = seconds
	_shown.append(shown)


func _process(delta: float) -> void:
	for shown in _shown:
		shown.age += delta
	_shown = _shown.filter(func(shown: Shown) -> bool: return shown.age < shown.seconds)
	queue_redraw()


func _draw() -> void:
	for shown in _shown:
		var fade: float = 1.0 - shown.age / shown.seconds
		var color: Color = Color(COLORS.get(shown.kind, Color.WHITE), fade)
		match shown.kind:
			Kind.HEAL:
				_draw_heal(shown, color)
			Kind.ARC:
				_draw_arc_chain(shown, color)
			Kind.STRIKE_WARNING, Kind.STRIKE, Kind.TRACER:
				_draw_strike(shown, color)
			_:
				_draw_ring(shown, color)


func _draw_heal(shown: Shown, color: Color) -> void:
	var at: Vector2 = shown.points[0] + Vector2(0, -30.0 * shown.age / shown.seconds)
	draw_arc(shown.points[0], 26.0 + 14.0 * shown.age, 0.0, TAU, 32, color, 3.0)
	draw_rect(Rect2(at - Vector2(9, 3), Vector2(18, 6)), color)
	draw_rect(Rect2(at - Vector2(3, 9), Vector2(6, 18)), color)


## Lightning: a jagged line through every point, re-jagged each frame.
func _draw_arc_chain(shown: Shown, color: Color) -> void:
	for i in shown.points.size() - 1:
		var from: Vector2 = shown.points[i]
		var to: Vector2 = shown.points[i + 1]
		var line := PackedVector2Array([from])
		var side: Vector2 = (to - from).orthogonal().normalized()
		for step in range(1, 6):
			var jitter: float = _rng.randf_range(-10.0, 10.0)
			line.append(from.lerp(to, step / 6.0) + side * jitter)
		line.append(to)
		draw_polyline(line, Color(1, 1, 1, color.a), 1.5)
		draw_polyline(line, color, 4.0)


func _draw_strike(shown: Shown, color: Color) -> void:
	var width: float = maxf(shown.radius, 2.0)
	if shown.kind == Kind.STRIKE_WARNING:
		var pulse: float = 0.35 + 0.25 * sin(shown.age * 20.0)
		draw_line(shown.points[0], shown.points[1], Color(color, pulse), width)
	else:
		draw_line(shown.points[0], shown.points[1], color, width * 1.4)


func _draw_ring(shown: Shown, color: Color) -> void:
	for at in shown.points:
		var r: float = maxf(shown.radius, 20.0)
		draw_circle(at, r, Color(color, color.a * 0.18))
		draw_arc(at, r, 0.0, TAU, 40, color, 2.5)
