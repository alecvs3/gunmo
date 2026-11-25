class_name DifficultyAxis
extends Resource
## One category of the wave difficulty vector (DifficultyModel). A subclass says how much of
## it a wave has (`raw`, from the wave's summed EnemyStats and its merged modifier); `weight`
## says how much it counts and `reference` is the raw amount that scores 10. `handled` is the
## other side: how much of it a team can take on (the progression score).

@export var display_name: String = ""
## Column header in the wave report (one letter).
@export var short_name: String = ""
@export_range(0.0, 10.0) var weight: float = 1.0
## The raw amount that scores 10: a hard late wave's.
@export_range(0.001, 1000000.0) var reference: float = 1.0


## Pure: how much of this axis the wave on `sheet` has under `modifier` (all its modifiers merged).
func raw(_sheet: WaveSheet, _modifier: WaveModifier) -> float:
	return 0.0


## Pure: how much of this axis a team of strength `team` handles, in the same raw units, so
## the two score alike (progression, ProgressionRun). Estimates live in `model`.
func handled(_team: TeamPower, _model: ProgressionModel) -> float:
	return 0.0


## Pure: a modifier's effect on health: more health, less damage taken (Kinetic, the score's
## baseline: it never depends on the players' guns).
static func toughness(modifier: WaveModifier) -> float:
	return modifier.health_multiplier / modifier.taken(DamageType.Type.KINETIC)
