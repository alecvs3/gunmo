class_name Shot
extends RefCounted
## One fired bullet: who fired it, from where, which way, and the weapon numbers it carries.
## Identified by (shooter_id, shot_id). For players shot_id = command number × MAX_PELLETS +
## pellet index, so the owner's predicted bullet and the host's real one share an id.
## shooter_id is signed: bots have negative ids.

## Room for pellets in shot ids (see make_id).
const MAX_PELLETS: int = 16

var shooter_id: int = 0
var shot_id: int = 0
var team: StringName = &""
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var lifetime: float = 0.0
var radius: float = 0.0
var damage: int = 0
var knockback: float = 0.0
## Enemies it can still pass through.
var pierce: int = 0
## Host tick the shot was fired on.
var fire_tick: float = 0.0
## Tick the shooter was looking at when firing (the host rewinds targets to it).
var view_tick: float = 0.0
## How it is drawn (WeaponData.Projectile); sent to everyone.
var projectile: int = 0
## Explosion where it lands (host only; the host tells everyone where blasts happen).
var blast_radius: float = 0.0
var blast_damage: int = 0


static func from_weapon(data: WeaponData, origin_point: Vector2, aim_direction: Vector2) -> Shot:
	var shot := Shot.new()
	shot.origin = origin_point
	shot.direction = aim_direction.normalized()
	shot.speed = data.bullet_speed
	shot.lifetime = data.bullet_lifetime
	shot.radius = data.bullet_radius
	shot.damage = data.damage
	shot.knockback = data.knockback
	shot.pierce = data.pierce
	shot.projectile = data.projectile
	if data.explodes():
		shot.blast_radius = data.blast_radius
		shot.blast_damage = data.blast_damage
	return shot


static func make_id(command_sequence: int, pellet: int) -> int:
	return command_sequence * MAX_PELLETS + pellet


func key() -> String:
	return "%d:%d" % [shooter_id, shot_id]


## Where the bullet is `age_ticks` after being fired, if nothing stops it.
func point_at(age_ticks: float) -> Vector2:
	return origin + direction * speed * age_ticks * NetClock.tick_delta()


func lifetime_ticks() -> float:
	return lifetime * NetClock.tick_rate()


func encode(buffer: StreamPeerBuffer) -> void:
	buffer.put_32(shooter_id)
	buffer.put_u32(shot_id)
	buffer.put_utf8_string(team)
	NetCodec.put_vector2(buffer, origin)
	NetCodec.put_vector2(buffer, direction)
	buffer.put_float(speed)
	buffer.put_float(lifetime)
	buffer.put_float(radius)
	buffer.put_u16(clampi(damage, 0, 65535))
	buffer.put_float(knockback)
	buffer.put_u8(clampi(pierce, 0, 255))
	buffer.put_double(fire_tick)
	buffer.put_double(view_tick)
	buffer.put_u8(clampi(projectile, 0, 255))


static func decode(buffer: StreamPeerBuffer) -> Shot:
	var shot := Shot.new()
	shot.shooter_id = buffer.get_32()
	shot.shot_id = buffer.get_u32()
	shot.team = StringName(buffer.get_utf8_string())
	shot.origin = NetCodec.get_vector2(buffer)
	shot.direction = NetCodec.get_vector2(buffer)
	shot.speed = buffer.get_float()
	shot.lifetime = buffer.get_float()
	shot.radius = buffer.get_float()
	shot.damage = buffer.get_u16()
	shot.knockback = buffer.get_float()
	shot.pierce = buffer.get_u8()
	shot.fire_tick = buffer.get_double()
	shot.view_tick = buffer.get_double()
	shot.projectile = buffer.get_u8()
	return shot
