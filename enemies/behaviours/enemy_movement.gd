class_name EnemyMovement
extends Resource
## How an enemy moves: given where it is and where its target is, the point it walks to (the
## enemy paths there around walls). Pure and stateless, so one file can serve many enemy types.
## Subclasses: ChaseMovement. Set on EnemyData.movement.


## The point to walk to. The base stays where it is.
func goal(own: Vector2, _target: Vector2) -> Vector2:
	return own
