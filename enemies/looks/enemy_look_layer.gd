class_name EnemyLookLayer
extends Node2D
## Draws an enemy's EnemyLook on top of its sprite. It copies the sprite's position, turn and
## size every frame (so it is drawn delayed with it too) but not its tint, so a look keeps its
## own colors. It measures how fast it moves so a look can animate (dust while dashing).
## Looks only, on every peer.

## How quickly the measured speed follows the real one (higher = snappier).
const SPEED_SMOOTHING: float = 12.0

var look: EnemyLook
## The sprite it sits on (a sibling).
var follow: Node2D

var _last_position: Vector2 = Vector2.ZERO
var _speed: float = 0.0


func _ready() -> void:
	_copy_sprite()
	_last_position = global_position


func _process(delta: float) -> void:
	_copy_sprite()
	if delta > 0.0:
		var measured: float = global_position.distance_to(_last_position) / delta
		_speed = lerpf(_speed, measured, 1.0 - exp(-SPEED_SMOOTHING * delta))
	_last_position = global_position
	queue_redraw()


func _draw() -> void:
	if look != null:
		look.draw(self, _speed)


func _copy_sprite() -> void:
	if follow != null:
		transform = follow.transform
