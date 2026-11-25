class_name BlastAttack
extends EnemyAttack
## A Bomber's attack. Close to a player it stops and lights its fuse (the windup: every peer
## sees a ring the size of the blast), then explodes: players and other enemies within
## `radius` take damage, and it dies (no bounty). Killed before the fuse ends, it still pops,
## but that blast hurts only enemies and its kills go to the player who killed it, so Bombers
## can be shot into a crowd and set each other off.

## Lights its fuse at a target this close (px).
@export_range(0.0, 1000.0) var trigger_range: float = 70.0
## How far the blast reaches (px); the fuse's warning ring is this big.
@export_range(1.0, 1000.0) var radius: float = 110.0
## Damage to each player in the blast (only when the fuse burns out, never when popped).
@export_range(0, 1000) var player_damage: int = 1
## Damage to each other enemy in the blast.
@export_range(0, 5000) var enemy_damage: int = 1
## Push away from the blast (px/s).
@export_range(0.0, 3000.0) var knockback: float = 0.0


func stands_still_while_winding_up() -> bool:
	return true


func wants_to_attack(cooldown_left: float, distance: float, _can_see: bool) -> bool:
	return cooldown_left <= 0.0 and distance <= trigger_range


## Host: the fuse burned out.
func perform(enemy: Node2D, _target: Node2D, _touching: Array[HitboxComponent]) -> bool:
	var chaser := enemy as ChaserEnemy
	if chaser == null:
		return false
	chaser.detonate(self)
	return true


## Pure: whether a blast hurts someone on `team`. Enemies always; players only when
## `hurts_players` (the fuse burned out: it wasn't shot).
static func hurts(team: StringName, hurts_players: bool) -> bool:
	return team == ChaserEnemy.TEAM or hurts_players


## Pure: whether a blast at `at` reaches `point`.
func reaches(at: Vector2, point: Vector2) -> bool:
	return at.distance_to(point) <= radius


## Pure: the damage a blast deals to someone on `team`.
func damage_to(team: StringName) -> int:
	return enemy_damage if team == ChaserEnemy.TEAM else player_damage


## Host: blasts everyone it may hurt around `at` except `own` (the bomber itself), with
## `source_id` as the attacker (a player's peer id gets the bounties), and shows it everywhere.
func blast(at: Vector2, own: HitboxComponent, hurts_players: bool, source_id: int) -> void:
	for hitbox in NetworkManager.lag_compensator.hitboxes():
		if hitbox == own or not hitbox.is_hittable() or not hurts(hitbox.team, hurts_players):
			continue
		if reaches(at, hitbox.center()):
			var push: Vector2 = at.direction_to(hitbox.center()) * knockback
			hitbox.hit(damage_to(hitbox.team), source_id, push, DamageType.Type.BLAST)
	EventBus.blast_requested.emit(at, radius)


## One blast per life, counted as its damage over the time it takes to set off.
func add_stats(stats: EnemyStats, weight: float) -> void:
	stats.add(EnemyStats.MELEE_DPS, weight * player_damage / cycle_seconds())
