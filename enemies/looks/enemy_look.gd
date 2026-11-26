class_name EnemyLook
extends Resource
## Extra shapes drawn on top of an enemy's sprite so its type reads at a glance (horns, a
## bomb, a shield...). Looks only, drawn on every peer; set on EnemyData.look. Drawn in the
## sprite's own space: +x is where it faces, 1 unit = 1 px before its visual_scale.
## Subclasses: HornsLook, BombLook, ShieldLook.


## Draws onto `canvas` (an EnemyLookLayer). `speed` = how fast the enemy moves now (px/s);
## `windup` = how far into a telegraphed attack's warning it is (0 = none, 1 = about to go).
func draw(_canvas: CanvasItem, _speed: float, _windup: float) -> void:
	pass
