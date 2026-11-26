class_name LatencyPolicy
extends Resource
## How a match hides network latency: every switch and number the latency plan adds, in one
## place per mode (modes/data/*_latency.tres, set on the mode scene). The running mode hands its
## policy to NetworkManager.latency_policy on every peer, so shared code reads the policy and
## never asks which mode is running (rule 7). default_latency_policy.tres turns everything off:
## the game as it was before the plan. A switch stays off until the step that builds it.

@export_group("Your own hits")
## Play the hit sound and flash the moment our own bullet lands on our screen, before the host
## confirms it.
@export var predict_hit_effects: bool = false
## Also show the damage number at once (off: numbers wait for the host's real value).
@export var predict_damage_numbers: bool = false
## How long a predicted hit waits to be matched with the host's verdict before it counts as a
## misprediction (seconds).
@export_range(0.05, 3.0) var predicted_hit_seconds: float = 0.5

@export_group("Hits on you")
## Draw a bot's or enemy's bullet that would reach us before its smooth catch-up ends at the
## present straight away.
@export var snap_close_threats: bool = false
## Play our hurt sound and hit marker the moment a bot's or enemy's bullet reaches us on our
## screen (only shots judged on our own timeline).
@export var predict_own_hurt: bool = false
## Judge enemy contact (melee) hits against where the victim saw the enemy.
@export var fair_contact: bool = false
## How far back the host may judge a hit on the victim's own view (seconds).
@export_range(0.0, 0.5) var victim_rewind: float = 0.25

@export_group("Wind-up attacks")
## Attacks with a windup lock their aim early and send their shots ahead of time.
@export var schedule_windup_shots: bool = false
## How long before firing the aim locks (seconds). At least one-way latency plus smoothing, so
## the shots reach clients before they fire.
@export_range(0.0, 1.0) var aim_lock_seconds: float = 0.25
