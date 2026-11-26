class_name HitboxComponent
extends Area2D
## The area that bullets and contact damage hit. Forwards damage to a HealthComponent and
## pushes to a KnockbackComponent. Registers with the LagCompensator, so a shot can be tested
## against where this hitbox was when the shooter saw it. Its shape (first CollisionShape2D,
## circle or rectangle) is used for those swept tests.

@export var health: HealthComponent
@export var knockback: KnockbackComponent
## Shots from the same team pass through (players don't hurt each other in co-op).
@export var team: StringName = &""
## The player this hitbox belongs to (0 = not a player). Its own shots never hit it, even
## when there are no teams (free-for-all).
var owner_id: int = 0
## Host, optional: called with the direction a hit travels; true = the hit is blocked (a
## Shielder's shield) and does nothing. Empty for everyone without a shield.
var guard: Callable = Callable()

var _radius: float = 0.0
var _half_extents: Vector2 = Vector2.ZERO
var _shape_offset: Vector2 = Vector2.ZERO


## The hitbox team for a team number: 0 is the co-op "players" team, any other number is a
## team of its own (free-for-all gives every player a different one).
static func team_for(team_id: int) -> StringName:
	return &"players" if team_id == 0 else StringName("team_%d" % team_id)


func _ready() -> void:
	_read_shape()
	NetworkManager.lag_compensator.register(self)


func _exit_tree() -> void:
	NetworkManager.lag_compensator.unregister(self)


## Host only (HealthComponent ignores it elsewhere). damage_type is a DamageType.Type: the
## target's traits take more or less of it. `incoming` is the direction the hit travels
## (a bullet's flight, away from a blast); Vector2.ZERO = from no side, never blocked.
## False = a guard blocked it: no damage, no push.
func hit(
	damage: int,
	source_id: int,
	push: Vector2 = Vector2.ZERO,
	damage_type: int = DamageType.Type.KINETIC,
	incoming: Vector2 = Vector2.ZERO
) -> bool:
	if incoming != Vector2.ZERO and guard.is_valid() and guard.call(incoming):
		return false
	if health != null:
		health.take_damage(damage, source_id, damage_type)
	if knockback != null and multiplayer.is_server():
		knockback.apply(push)
	return true


## False while its owner is dead or gone.
func is_hittable() -> bool:
	return monitorable and is_inside_tree()


## Grows (or shrinks) the hit shape by `factor` (a boss's body_scale). Call after _ready.
func scale_size(factor: float) -> void:
	_radius *= factor
	_half_extents *= factor
	_shape_offset *= factor


## Where the shape's centre is now.
func center() -> Vector2:
	return global_position + _shape_offset


## Where along from->to (0..1) a bullet of `bullet_radius` touches this shape if it were
## centred at `at_center`, or -1 for a miss.
func sweep_fraction(from: Vector2, to: Vector2, at_center: Vector2, bullet_radius: float) -> float:
	if _half_extents != Vector2.ZERO:
		var size: Vector2 = (_half_extents + Vector2.ONE * bullet_radius) * 2.0
		return HitGeometry.segment_rect(from, to, Rect2(at_center - size * 0.5, size))
	return HitGeometry.segment_circle(from, to, at_center, _radius + bullet_radius)


func _read_shape() -> void:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		_shape_offset = shape_node.position
		if shape_node.shape is CircleShape2D:
			_radius = (shape_node.shape as CircleShape2D).radius
		elif shape_node.shape is RectangleShape2D:
			_half_extents = (shape_node.shape as RectangleShape2D).size * 0.5
		return
