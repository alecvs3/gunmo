class_name BotProfile
extends Resource
## How well a bot plays. Real values live in bots/profiles/*.tres.

## Shown in its name ("Bot 2 · Hard").
@export var display_name: String = ""
## Seconds from first seeing a target to the first shot.
@export_range(0.0, 3.0) var reaction_time: float = 0.0
## Largest aim mistake, in degrees either side; a new mistake is picked every aim_error_period.
@export_range(0.0, 45.0) var aim_error_degrees: float = 0.0
@export_range(0.05, 5.0) var aim_error_period: float = 1.0
## How fast it can turn its aim, in degrees per second.
@export_range(30.0, 3600.0) var turn_speed_degrees: float = 360.0
## It only fires when its aim is within this many degrees of where it wants to aim.
@export_range(0.5, 45.0) var fire_cone_degrees: float = 5.0
## It notices players this close (with a clear line of sight).
@export_range(50.0, 4000.0) var awareness_range: float = 600.0
## The distance it tries to keep from its target.
@export_range(0.0, 2000.0) var preferred_distance: float = 300.0
## How much it circles its target instead of walking straight (0 = never, 1 = only sideways).
@export_range(0.0, 1.0) var strafe: float = 0.0
## Seconds between strafe direction changes.
@export_range(0.2, 10.0) var strafe_period: float = 1.5
## Seconds between path updates while roaming or chasing out of sight.
@export_range(0.1, 5.0) var repath_interval: float = 0.5

@export_group("Co-op")
## Stays within this far of the team's centre when nobody is in sight (px).
@export_range(50.0, 3000.0) var team_spread: float = 320.0
## Goes to revive a downed teammate this close (px), and holds revive within `revive_reach`.
@export_range(0.0, 5000.0) var revive_seek_distance: float = 900.0
@export_range(10.0, 200.0) var revive_reach: float = 45.0

@export_group("Smarts")
## How hard it sidesteps bullets about to hit it (0 = never, 1 = drops everything to dodge).
@export_range(0.0, 1.0) var dodge: float = 0.0
## Bullets arriving within this many seconds are worth dodging.
@export_range(0.05, 2.0) var dodge_horizon: float = 0.5
## Below this share of its health it breaks off to cover for cover_seconds (0 = never).
@export_range(0.0, 1.0) var cover_health: float = 0.0
@export_range(0.5, 10.0) var cover_seconds: float = 2.5
## Hunting someone out of sight, it comes in this many degrees round from the side.
@export_range(0.0, 90.0) var flank_degrees: float = 0.0
## Out of sight, it walks towards the nearest opponent (it knows the map) instead of roaming.
@export var hunts: bool = false
