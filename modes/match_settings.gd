class_name MatchSettings
extends Resource
## The rules for one match. Real values live in modes/data/*.tres; a different file can be
## chosen with the --match <res://path.tres> launch argument (the smoke test uses a quick one).

## Seconds of the lobby break before wave 1 (skipped once everyone is ready).
@export_range(0.0, 600.0) var first_break_seconds: float = 0.0
## Seconds of the break between waves (skipped once everyone is ready).
@export_range(0.0, 600.0) var break_seconds: float = 0.0
## Bring everyone who is down back at the start of each break (off = hardcore).
@export var revive_at_break: bool = false
## Someone joining mid-wave watches until the next break instead of dropping in.
@export var late_joiners_spectate: bool = false
## Credits each player starts the match with.
@export_range(0, 1000000) var starting_credits: int = 0
## Credits for every player still standing when a wave is cleared: base + per_wave × wave.
@export_range(0, 100000) var wave_clear_bonus: int = 0
@export_range(0, 100000) var wave_clear_bonus_per_wave: int = 0
## How the waves grow (wave mode).
@export var wave_schedule: WaveSchedule
