class_name EnemyNetState
extends NetState
## What clients need about an enemy: where it is, its health and its status effects.

## Quarter-pixel position (4) + u16 health + u8 status flags.
const SIZE: int = 7

var position: Vector2 = Vector2.ZERO
var health: int = 0
## Burning / chilled / shredded (HitEffects bits).
var status: int = 0


func encode(buffer: StreamPeerBuffer) -> void:
	NetCodec.put_quarter_position(buffer, position)
	buffer.put_u16(clampi(health, 0, 65535))
	buffer.put_u8(status & 0xFF)


func decode(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_quarter_position(buffer)
	health = buffer.get_u16()
	status = buffer.get_u8()


func byte_size() -> int:
	return SIZE


func interpolated(to: NetState, weight: float) -> NetState:
	var other := to as EnemyNetState
	if other == null:
		return super(to, weight)
	var blended := EnemyNetState.new()
	blended.position = position.lerp(other.position, weight)
	blended.health = health if weight < 0.5 else other.health
	blended.status = status if weight < 0.5 else other.status
	return blended
