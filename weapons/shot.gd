class_name Shot
extends RefCounted
## One fired bullet: who fired it, from where, which way, and the weapon numbers it carries.
## Identified by (shooter_id, shot_id); for players shot_id is the input command that fired it,
## so the owner's predicted bullet and the host's real one share an id.

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
## Host tick the shot was fired on.
var fire_tick: float = 0.0
## Tick the shooter was looking at when firing (the host rewinds targets to it).
var view_tick: float = 0.0


static func from_weapon(data: WeaponData, origin_point: Vector2, aim_direction: Vector2) -> Shot:
	var shot := Shot.new()
	shot.origin = origin_point
	shot.direction = aim_direction.normalized()
	shot.speed = data.bullet_speed
	shot.lifetime = data.bullet_lifetime
	shot.radius = data.bullet_radius
	shot.damage = data.damage
	shot.knockback = data.knockback
	return shot


func key() -> String:
	return "%d:%d" % [shooter_id, shot_id]


## Where the bullet is `age_ticks` after being fired, if nothing stops it.
func point_at(age_ticks: float) -> Vector2:
	return origin + direction * speed * age_ticks * NetClock.tick_delta()


func lifetime_ticks() -> float:
	return lifetime * NetClock.tick_rate()


func encode(buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(shooter_id)
	buffer.put_u32(shot_id)
	buffer.put_utf8_string(team)
	NetCodec.put_vector2(buffer, origin)
	NetCodec.put_vector2(buffer, direction)
	buffer.put_float(speed)
	buffer.put_float(lifetime)
	buffer.put_float(radius)
	buffer.put_u16(clampi(damage, 0, 65535))
	buffer.put_float(knockback)
	buffer.put_double(fire_tick)
	buffer.put_double(view_tick)


static func decode(buffer: StreamPeerBuffer) -> Shot:
	var shot := Shot.new()
	shot.shooter_id = buffer.get_u32()
	shot.shot_id = buffer.get_u32()
	shot.team = StringName(buffer.get_utf8_string())
	shot.origin = NetCodec.get_vector2(buffer)
	shot.direction = NetCodec.get_vector2(buffer)
	shot.speed = buffer.get_float()
	shot.lifetime = buffer.get_float()
	shot.radius = buffer.get_float()
	shot.damage = buffer.get_u16()
	shot.knockback = buffer.get_float()
	shot.fire_tick = buffer.get_double()
	shot.view_tick = buffer.get_double()
	return shot
