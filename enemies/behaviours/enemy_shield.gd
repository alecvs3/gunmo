class_name EnemyShield
extends Resource
## A shield carried in front. A hit coming from within `arc_degrees` of where the enemy faces is
## blocked, whatever its damage type (rockets and blasts too), so no gun beats it: getting
## around it does. It turns slowly towards its target (`turn_speed_degrees`), and it never
## flinches, or a hit would swing the shield aside. Set on EnemyData.shield.

## How wide the shield covers, centred on where it faces (degrees).
@export_range(0.0, 360.0) var arc_degrees: float = 110.0
## How fast it turns to face its target (degrees per second).
@export_range(1.0, 1440.0) var turn_speed_degrees: float = 90.0


## Pure: whether a hit travelling along `incoming` is blocked while it faces `facing` (radians).
## A hit with no direction (Vector2.ZERO: a pet's lightning) is never blocked.
func blocks(facing: float, incoming: Vector2) -> bool:
	if incoming == Vector2.ZERO:
		return false
	var towards_source: float = (-incoming).angle()
	return absf(angle_difference(facing, towards_source)) <= deg_to_rad(arc_degrees) / 2.0


## Pure: how far it may turn in `delta` seconds (radians).
func turn_step(delta: float) -> float:
	return deg_to_rad(turn_speed_degrees) * delta
