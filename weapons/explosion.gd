class_name Explosion
extends RefCounted
## Host: a shot that explodes (WeaponData.blast_radius) damages and pushes away everyone it may
## hurt within the radius of where it lands. The target it hit directly already took the
## shot's own damage, so it is skipped. Uses where targets are now (an area effect, not
## lag-compensated), and walls don't block it.


## Whether `hitbox` is someone this shot may hurt: not dead or gone, not on the shooter's team,
## and never the shooter.
static func is_foe(shot: Shot, hitbox: HitboxComponent) -> bool:
	return hitbox.is_hittable() and hitbox.team != shot.team and hitbox.owner_id != shot.shooter_id


## Everyone the blast at `at` reaches, except `skip`.
static func targets(
	shot: Shot, at: Vector2, skip: HitboxComponent, candidates: Array[HitboxComponent]
) -> Array[HitboxComponent]:
	var reached: Array[HitboxComponent] = []
	for hitbox in candidates:
		if hitbox == skip or not is_foe(shot, hitbox):
			continue
		if hitbox.center().distance_to(at) <= shot.blast_radius:
			reached.append(hitbox)
	return reached


## Deals the blast at `at`. Returns false if the shot doesn't explode.
static func detonate(
	shot: Shot, at: Vector2, skip: HitboxComponent, candidates: Array[HitboxComponent]
) -> bool:
	if shot.blast_radius <= 0.0 or shot.blast_damage <= 0:
		return false
	for hitbox in targets(shot, at, skip, candidates):
		var away: Vector2 = at.direction_to(hitbox.center())
		hitbox.hit(shot.blast_damage, shot.shooter_id, away * shot.knockback)
	return true
