class_name EnemyNetState
extends NetState
## What clients need about an enemy: where it is and its health.

## Vector (8) + u16 health.
const SIZE: int = 10

var position: Vector2 = Vector2.ZERO
var health: int = 0


func encode(buffer: StreamPeerBuffer) -> void:
	NetCodec.put_vector2(buffer, position)
	buffer.put_u16(clampi(health, 0, 65535))


func decode(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_vector2(buffer)
	health = buffer.get_u16()


func byte_size() -> int:
	return SIZE


func interpolated(to: NetState, weight: float) -> NetState:
	var other := to as EnemyNetState
	if other == null:
		return super(to, weight)
	var blended := EnemyNetState.new()
	blended.position = position.lerp(other.position, weight)
	blended.health = health if weight < 0.5 else other.health
	return blended
