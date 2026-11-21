class_name PlayerNetState
extends NetState
## What clients need about a player: where it is and how it is moving (also everything the
## owner's prediction rewinds to), weapon timers, health, and the last command the host ran.

const FLAG_ALIVE: int = 1
## 3 vectors (24) + f64 aim + u16 health + u16 ammo + 2 x f64 timers + u8 flags + u8 teleports
## + u32 last command.
const SIZE: int = 58

var position: Vector2 = Vector2.ZERO
var move_velocity: Vector2 = Vector2.ZERO
var knockback: Vector2 = Vector2.ZERO
var aim: float = 0.0
var health: int = 0
var ammo: int = 0
var cooldown_left: float = 0.0
var reload_left: float = 0.0
var alive: bool = true
## Bumped on every teleport (respawn) so receivers snap instead of sliding across the map.
var teleport_count: int = 0
## Sequence of the last input command the host simulated (-1 = none yet).
var last_command: int = -1


func encode(buffer: StreamPeerBuffer) -> void:
	NetCodec.put_vector2(buffer, position)
	NetCodec.put_vector2(buffer, move_velocity)
	NetCodec.put_vector2(buffer, knockback)
	buffer.put_double(aim)
	buffer.put_u16(clampi(health, 0, 65535))
	buffer.put_u16(clampi(ammo, 0, 65535))
	buffer.put_double(cooldown_left)
	buffer.put_double(reload_left)
	buffer.put_u8(FLAG_ALIVE if alive else 0)
	buffer.put_u8(teleport_count & 0xFF)
	buffer.put_u32(last_command + 1)


func decode(buffer: StreamPeerBuffer) -> void:
	position = NetCodec.get_vector2(buffer)
	move_velocity = NetCodec.get_vector2(buffer)
	knockback = NetCodec.get_vector2(buffer)
	aim = buffer.get_double()
	health = buffer.get_u16()
	ammo = buffer.get_u16()
	cooldown_left = buffer.get_double()
	reload_left = buffer.get_double()
	alive = buffer.get_u8() & FLAG_ALIVE != 0
	teleport_count = buffer.get_u8()
	last_command = buffer.get_u32() - 1


func byte_size() -> int:
	return SIZE


## Position and aim blend; everything else comes from the nearer state. Across a teleport
## nothing blends, so the player jumps instead of sliding.
func interpolated(to: NetState, weight: float) -> NetState:
	var other := to as PlayerNetState
	if other == null or other.teleport_count != teleport_count:
		return super(to, weight)
	var blended: PlayerNetState = (self if weight < 0.5 else other).copy()
	blended.position = position.lerp(other.position, weight)
	blended.aim = lerp_angle(aim, other.aim, weight)
	return blended


func copy() -> PlayerNetState:
	var duplicate := PlayerNetState.new()
	duplicate.position = position
	duplicate.move_velocity = move_velocity
	duplicate.knockback = knockback
	duplicate.aim = aim
	duplicate.health = health
	duplicate.ammo = ammo
	duplicate.cooldown_left = cooldown_left
	duplicate.reload_left = reload_left
	duplicate.alive = alive
	duplicate.teleport_count = teleport_count
	duplicate.last_command = last_command
	return duplicate
