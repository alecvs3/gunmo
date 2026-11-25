class_name StatEffect
extends PathEffect
## Improves one player stat by a share, through the same multipliers shop upgrades use
## (PlayerStats): +10% max health adds 0.1 to the max health multiplier; on a gun stat it
## scales the gun's number after its upgrade levels (reload speed +20% = reload time / 1.2).
## It changes simulate() (move speed, fire rate, reload), so the host and the predicting owner
## both apply it from the owned nodes in the snapshot.

@export var stat: UpgradeData.Stat = UpgradeData.Stat.MAX_HEALTH
## 0.1 = +10%.
@export_range(0.0, 2.0) var amount: float = 0.0


func stat_bonus(which: UpgradeData.Stat) -> float:
	return amount if which == stat else 0.0
