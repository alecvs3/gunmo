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

var _radius: float = 0.0
var _half_extents: Vector2 = Vector2.ZERO
var _shape_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_read_shape()
	NetworkManager.lag_compensator.register(self)


func _exit_tree() -> void:
	NetworkManager.lag_compensator.unregister(self)


## Host only (HealthComponent ignores it elsewhere).
func hit(damage: int, source_id: int, push: Vector2 = Vector2.ZERO) -> void:
	if health != null:
		health.take_damage(damage, source_id)
	if knockback != null and multiplayer.is_server():
		knockback.apply(push)


## False while its owner is dead or gone.
func is_hittable() -> bool:
	return monitorable and is_inside_tree()


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
