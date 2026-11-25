class_name ContactJudge
extends RefCounted
## Pure: does an enemy's contact square touch a player's round hitbox? Fair contact (the latency
## plan, step 5) asks this with the enemy where the player saw it and the player where their own
## inputs put them, instead of overlapping Area2Ds at the host's present. The square is the
## enemy's ContactArea shape (a RectangleShape2D, already scaled for bigger enemies), centred on
## the enemy and never rotated.


## Pixels between the contact square and the player's hitbox edge; 0 or less means they touch.
static func gap(
	enemy_center: Vector2, contact_half: Vector2, player_center: Vector2, player_radius: float
) -> float:
	var closest := Vector2(
		clampf(player_center.x, enemy_center.x - contact_half.x, enemy_center.x + contact_half.x),
		clampf(player_center.y, enemy_center.y - contact_half.y, enemy_center.y + contact_half.y)
	)
	return player_center.distance_to(closest) - player_radius


static func touches(
	enemy_center: Vector2, contact_half: Vector2, player_center: Vector2, player_radius: float
) -> bool:
	return gap(enemy_center, contact_half, player_center, player_radius) <= 0.0
