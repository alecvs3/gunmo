class_name EnemyNetState
extends NetState
## What clients need about an enemy: where it is, its health and which way it faces.

## Quarter-pixel position (4) + u16 health + u8 facing.
const SIZE: int = 7
## Facing is sent as one of this many directions (1 byte, about 1.4 degrees apart).
const FACING_STEPS: int = 256

var position: Vector2 = Vector2.ZERO
var health: int = 0
## Which way it faces, 0..FACING_STEPS-1 around a full turn (see to_facing / facing_angle).
var facing: int = 0


## The facing step closest to `angle` (radians).
static func to_facing(angle: float) -> int:
	return posmod(roundi(angle / TAU * FACING_STEPS), FACING_STEPS)


## The angle (radians) of facing step `step`.
static func facing_angle(step: int) -> float:
	return step * TAU / FACING_STEPS


func encode(buffer: StreamPeerBuffer) -> void:
	NetCodec.put_quarter_position(buffer, position)
	buffer.put_u16(clampi(health, 0, 65535))
	buffer.put_u8(posmod(facing, FACING_STEPS))


func decode(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_quarter_position(buffer)
	health = buffer.get_u16()
	facing = buffer.get_u8()


func byte_size() -> int:
	return SIZE


func interpolated(to: NetState, weight: float) -> NetState:
	var other := to as EnemyNetState
	if other == null:
		return super(to, weight)
	var blended := EnemyNetState.new()
	blended.position = position.lerp(other.position, weight)
	blended.health = health if weight < 0.5 else other.health
	var angle: float = lerp_angle(facing_angle(facing), facing_angle(other.facing), weight)
	blended.facing = to_facing(angle)
	return blended
