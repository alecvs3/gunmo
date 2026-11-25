class_name ProgressionModel
extends Resource
## How strong a team is likely to be at each wave, on the paper (ProgressionRun). Every number
## here is an estimate that turns a loadout into the units the difficulty axes use, so the two
## scores compare directly: a team with progression 60 handles a wave of difficulty 60.
## Real values live in modes/waves/data/progression/progression_model.tres.

const DEFAULT_PATH: String = "res://modes/waves/data/progression/progression_model.tres"
## The graphs and tables show both scores ×10 (difficulty's 0–10 becomes 0–100).
const DISPLAY_SCALE: float = 10.0

@export_group("Axes: what a team handles")
## A wave should take this long (design intent). Toughness: the team handles the effective
## health it kills in this time. Melee and Ranged: the damage it survives over this time.
@export_range(1.0, 600.0) var clear_seconds: float = 60.0
## Melee: the share of the wave's summed contact damage per second that lands on the team on
## average (the raw amount counts every enemy touching at once, so this is small).
@export_range(0.0001, 1.0) var melee_hit_share: float = 0.02
## Ranged: the same for projectile damage per second (before dodging).
@export_range(0.0001, 1.0) var ranged_hit_share: float = 0.18
## Pressure: bodies (at the pressure axis's reference speed) one player at the base move speed
## keeps away by moving...
@export_range(0.0, 100.0) var kite_bodies: float = 11.0
## ...plus bodies held back for each point of team damage per second (killing them).
@export_range(0.0, 10.0) var pressure_per_dps: float = 0.05
## Sustain: the share of team damage per second that can be spent out-damaging healing...
@export_range(0.0, 1.0) var sustain_share: float = 0.5
## ...and how much each point of burst damage (airstrikes, Tempest) counts on top.
@export_range(0.0, 5.0) var burst_sustain: float = 1.0
## Move speed (px/s) that counts as 1 (the pressure axis's reference speed).
@export_range(1.0, 2000.0) var reference_speed: float = 220.0

@export_group("Guns")
## Average extra enemies an explosion hits besides the one it struck.
@export_range(0.0, 10.0) var blast_targets: float = 1.5
## Average extra enemies a piercing bullet hits for each pierce.
@export_range(0.0, 1.0) var pierce_targets: float = 0.3
## Knockback (px/s) that doubles how long melee enemies take to get back to you.
@export_range(1.0, 10000.0) var knockback_reference: float = 600.0
## Share of dodging that also works against melee (most dodging is against shots).
@export_range(0.0, 1.0) var melee_dodge: float = 0.5

@export_group("Pets")
## Share of the time a Soldier's Rally is up.
@export_range(0.0, 1.0) var rally_uptime: float = 0.3
## Seconds between airstrikes once tier 5 is owned, and enemies each one hits.
@export_range(1.0, 600.0) var airstrike_seconds: float = 30.0
@export_range(0.0, 20.0) var airstrike_targets: float = 4.0
## Share of the team's damage that lands on the hexed enemy.
@export_range(0.0, 1.0) var hex_focus_share: float = 0.4
## Share of melee enemies a Frost Rune catches.
@export_range(0.0, 1.0) var rune_coverage: float = 0.4
## Share of hits that land on slowed enemies (Conduction).
@export_range(0.0, 1.0) var slowed_share: float = 0.3
## The pet's own aim (covering fire).
@export_range(0.0, 1.0) var pet_accuracy: float = 0.8

@export_group("Team")
## How much of a wave a player who goes down misses (their damage, their health).
@export_range(0.0, 1.0) var down_cost: float = 0.5
## How much Guardian (Healer tier 5) cuts the owner's chance to go down.
@export_range(0.0, 1.0) var guardian_cut: float = 0.5
## Bounty goes to the killing hit. Above 1, players who deal more damage also steal more last
## hits: a player's share is (dps ^ this) over the team's.
@export_range(0.5, 4.0) var kill_share_power: float = 1.3
## Enemies of the called-away wave still alive when a team calls early.
@export_range(0.0, 100.0) var early_call_alive: float = 5.0
## Pets handed out to generated teams, one per member in order (PetCatalog index, -1 = none).
@export var team_pets := PackedInt32Array([2, 0, 1, 2])

@export_group("Comparison")
## What the strain (difficulty − progression, ×10) should be at each wave.
@export var strain: StrainCurve
## The team the strain check is for (the graphs show every team).
@export var reference_team: TeamSetup


static func load_default() -> ProgressionModel:
	return load(DEFAULT_PATH)
