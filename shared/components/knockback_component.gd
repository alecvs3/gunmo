class_name KnockbackComponent
extends Node
## Pushes its owner around after hits. Hits add an impulse (host only); the owner's movement
## adds `velocity` to its own each tick, calls bounce_off_collisions() after moving and step()
## to let the push die down. A push into a wall bounces back a little; walking never does.
## Fully deterministic, so a predicting owner reproduces the host's knockback exactly.

## Below this speed (px/s) a push counts as over.
const MIN_SPEED: float = 1.0

## Current push, px/s. Replicated for players (prediction needs it).
var velocity: Vector2 = Vector2.ZERO
## px/s lost per second.
var friction: float = 2000.0
## Share of the push kept when bouncing off a wall (0 = stops dead, 1 = full bounce).
var bounce: float = 0.3
## Multiplier on incoming pushes (0 = immovable, 1 = normal).
var taken: float = 1.0


func configure(friction_value: float, bounce_value: float, taken_value: float) -> void:
	friction = friction_value
	bounce = bounce_value
	taken = taken_value


func apply(impulse: Vector2) -> void:
	velocity += impulse * taken


func is_active() -> bool:
	return velocity.length_squared() > MIN_SPEED * MIN_SPEED


func step(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


## Reflects a push that is driving into a surface with this normal.
func bounce_off(normal: Vector2) -> void:
	if is_active() and velocity.dot(normal) < 0.0:
		velocity = velocity.bounce(normal) * bounce


func bounce_off_collisions(body: CharacterBody2D) -> void:
	for i in body.get_slide_collision_count():
		bounce_off(body.get_slide_collision(i).get_normal())
