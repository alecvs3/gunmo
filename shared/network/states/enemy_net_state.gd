class_name EnemyNetState
extends NetState
## What clients need about an enemy: where it is, its health, which way it faces and how far
## into a telegraphed attack's windup it is.

## Quarter-pixel position (4) + u16 health + u8 facing + u8 (3 bits status, 5 bits telegraph).
const SIZE: int = 8
## Facing is sent as one of this many directions (1 byte, about 1.4 degrees apart).
const FACING_STEPS: int = 256
## The telegraph's top value (5 bits).
const TELEGRAPH_STEPS: int = 31

var position: Vector2 = Vector2.ZERO
var health: int = 0
## Which way it faces, 0..FACING_STEPS-1 around a full turn (see to_facing / facing_angle).
var facing: int = 0
## How far into an attack's windup (1..31 = just started..about to fire), 0 = not winding up.
var telegraph: int = 0
## EnemyStatus.FLAG_*: slowed, hexed (pets), stunned (a Charger). Shares telegraph's byte.
var status: int = 0


## The telegraph byte for a windup with `left` of `total` seconds to go (0 = none).
static func to_telegraph(left: float, total: float) -> int:
	if total <= 0.0 or left <= 0.0:
		return 0
	return clampi(roundi((1.0 - left / total) * (TELEGRAPH_STEPS - 1)) + 1, 1, TELEGRAPH_STEPS)


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
	buffer.put_u8((status & 7) << 5 | clampi(telegraph, 0, TELEGRAPH_STEPS))


func decode(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_quarter_position(buffer)
	health = buffer.get_u16()
	facing = buffer.get_u8()
	var packed: int = buffer.get_u8()
	telegraph = packed & TELEGRAPH_STEPS
	status = packed >> 5


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
	blended.telegraph = telegraph if weight < 0.5 else other.telegraph
	blended.status = status if weight < 0.5 else other.status
	return blended
