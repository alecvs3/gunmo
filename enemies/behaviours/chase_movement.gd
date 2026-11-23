class_name ChaseMovement
extends EnemyMovement
## Walks straight at its target (along the navigation path).


func goal(_own: Vector2, target: Vector2) -> Vector2:
	return target
