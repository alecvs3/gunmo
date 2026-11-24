class_name WizardData
extends PetData
## The Wizard's numbers (WizardRules reads them).

@export_group("Arc Spark (tier 1, better from 2)")
@export_range(0.0, 1.0) var arc_chance: float = 0.15
@export_range(0.0, 1.0) var arc_chance_upgraded: float = 0.2
@export_range(0, 10) var arc_jumps: int = 2
@export_range(0, 10) var arc_jumps_upgraded: int = 3
@export_range(10.0, 1000.0) var arc_radius: float = 140.0
## Share of the hit's damage each arc deals.
@export_range(0.0, 5.0) var arc_damage_share: float = 0.4
## At most one arc per this many seconds per Wizard.
@export_range(0.0, 10.0) var arc_cooldown: float = 1.0

@export_group("Frost Rune (tier 2, faster from 4)")
@export_range(1.0, 60.0) var rune_interval: float = 8.0
@export_range(1.0, 60.0) var rune_interval_upgraded: float = 6.0
@export_range(10.0, 1000.0) var rune_radius: float = 110.0
## How far from its owner the rune may land.
@export_range(50.0, 2000.0) var rune_reach: float = 450.0
@export_range(0.0, 0.9) var rune_slow: float = 0.35
@export_range(0.1, 20.0) var rune_seconds: float = 3.0

@export_group("Conduction (tier 3)")
## Arcs deal this much more to slowed enemies, and slowed enemies pass arcs on this many more times.
@export_range(0.0, 5.0) var conduction_bonus: float = 0.25
@export_range(0, 10) var conduction_extra_jumps: int = 1

@export_group("Hex (tier 4, faster from 5)")
@export_range(1.0, 60.0) var hex_interval: float = 12.0
@export_range(1.0, 60.0) var hex_interval_upgraded: float = 7.0
@export_range(50.0, 2000.0) var hex_reach: float = 600.0
@export_range(0.0, 5.0) var hex_bonus: float = 0.2
@export_range(0.1, 30.0) var hex_seconds: float = 5.0

@export_group("Tempest (tier 5)")
@export_range(1.0, 120.0) var tempest_interval: float = 25.0
@export_range(0.0, 10.0) var tempest_warning: float = 1.0
@export_range(1, 30) var tempest_bolts: int = 6
@export_range(50.0, 2000.0) var tempest_reach: float = 400.0
## Share of each struck enemy's max health (less on bosses).
@export_range(0.0, 1.0) var tempest_share: float = 0.08
@export_range(0.0, 1.0) var tempest_boss_share: float = 0.02
