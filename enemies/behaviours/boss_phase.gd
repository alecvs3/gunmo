class_name BossPhase
extends Resource
## One phase of a boss: once its health falls to `health_below` (a share of max health) it
## moves and attacks with these parts. A boss lists its phases from the first (health_below
## 1.0) down; EnemyData.phases.

@export var display_name: String = ""
@export_range(0.0, 1.0) var health_below: float = 1.0
@export var movement: EnemyMovement
@export var attack: EnemyAttack
## On top of the boss's move_speed.
@export_range(0.1, 5.0) var speed_multiplier: float = 1.0


## Pure: which phase a boss with `health_share` of its health left is in: the last one whose
## threshold it has reached (0 when there are none, or it is above them all).
static func index_for(phases: Array[BossPhase], health_share: float) -> int:
	var found: int = 0
	for i in phases.size():
		if health_share <= phases[i].health_below:
			found = i
	return found
