class_name MatchSettings
extends Resource
## The rules for one match. Real values live in modes/data/*.tres; a different file can be
## chosen with the --match <res://path.tres> launch argument (the smoke test uses a quick one).
## Each file also says which mode it is for (mode_scene).

## The game mode scene this match runs (modes/*.tscn, listed in Main's ModeSpawner).
@export var mode_scene: PackedScene
## The map (levels/data/*.tres); none = the default map (test arena).
@export var map: MapData
## Bots added until there are this many players, humans included (modes with bots only).
## The host's menu can override it.
@export_range(0, 16) var bot_fill_to: int = 0

## Seconds of the lobby break before wave 1 (skipped once everyone is ready).
@export_range(0.0, 600.0) var first_break_seconds: float = 0.0
## Seconds of the break between waves (skipped once everyone is ready).
@export_range(0.0, 600.0) var break_seconds: float = 0.0
## Bring everyone who is down back at the start of each break (off = hardcore).
@export var revive_at_break: bool = false
## Someone joining mid-wave watches until the next break instead of dropping in.
@export var late_joiners_spectate: bool = false
## Co-op: a player at 0 health goes down for this long (a teammate can revive them) before
## they are out until the break. 0 = no downed state: out at once.
@export_range(0.0, 120.0) var bleed_out_seconds: float = 0.0
## Holding revive this long next to a downed teammate brings them back.
@export_range(0.1, 30.0) var revive_seconds: float = 3.0
@export_range(10.0, 500.0) var revive_range: float = 70.0
## Share of max health a revived player comes back with.
@export_range(0.05, 1.0) var revive_health_share: float = 0.3
## Credits each player starts the match with.
@export_range(0, 1000000) var starting_credits: int = 0
## Credits for every player still standing when a wave is cleared: base + per_wave × wave.
@export_range(0, 100000) var wave_clear_bonus: int = 0
@export_range(0, 100000) var wave_clear_bonus_per_wave: int = 0
## Calling the next wave early pays every standing player this much per enemy still alive,
## and this much per second of break skipped (on top of the wave's clear bonus).
@export_range(0, 1000) var early_call_bonus_per_enemy: int = 0
@export_range(0, 1000) var early_call_bonus_per_second: int = 0
## How the waves grow (wave mode).
@export var wave_schedule: WaveSchedule

@export_group("Gun Game")
## The guns in order, first to last. Each must be in the shop catalog (peers name guns by
## catalog index); a gun may appear more than once.
@export var ladder: Array[WeaponData] = []
## Kills with a gun to move on to the next one.
@export_range(1, 50) var kills_per_tier: int = 1
## Kills with the last gun to win.
@export_range(1, 50) var final_tier_kills: int = 1
@export_range(0.0, 30.0) var respawn_seconds: float = 0.0
## After respawning a player can't be hurt for this long.
@export_range(0.0, 10.0) var spawn_protection_seconds: float = 0.0
## Bots take these profiles in turn (bot_fill_to says how many bots).
@export var bot_profiles: Array[BotProfile] = []
