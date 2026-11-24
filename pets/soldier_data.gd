class_name SoldierData
extends PetData
## The Soldier's numbers (SoldierRules reads them).

@export_group("Drill (tier 1, better from 2)")
@export_range(0.0, 2.0) var drill_bonus: float = 0.08
@export_range(0.0, 2.0) var drill_bonus_upgraded: float = 0.10

@export_group("Rally (tier 2, also you from 4, stronger from 5)")
@export_range(1, 200) var rally_kills: int = 12
@export_range(0.0, 2.0) var rally_fire_rate: float = 0.15
@export_range(0.0, 2.0) var rally_fire_rate_upgraded: float = 0.20
@export_range(0.5, 30.0) var rally_seconds: float = 6.0
@export_range(50.0, 3000.0) var rally_reach: float = 400.0

@export_group("Covering Fire (tier 3)")
@export_range(0.1, 10.0) var cover_interval: float = 0.8
## Share of your gun's damage per pet shot.
@export_range(0.0, 2.0) var cover_damage_share: float = 0.25
@export_range(50.0, 2000.0) var cover_reach: float = 350.0

@export_group("Last Stand (tier 4)")
@export_range(0.0, 2.0) var last_stand_damage: float = 0.25
@export_range(0.0, 2.0) var last_stand_move: float = 0.10

@export_group("Airstrike (tier 5)")
@export_range(1, 100) var airstrike_kills: int = 10
@export_range(0.5, 60.0) var airstrike_window: float = 8.0
@export_range(0.0, 10.0) var airstrike_warning: float = 1.2
@export_range(50.0, 3000.0) var airstrike_length: float = 600.0
@export_range(5.0, 300.0) var airstrike_width: float = 50.0
@export_range(0, 100000) var airstrike_damage: int = 300
@export_range(0, 10000) var airstrike_damage_per_wave: int = 20
@export_range(0.0, 1.0) var airstrike_boss_share: float = 0.25
