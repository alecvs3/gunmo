class_name NetworkConfig
extends Resource
## Network tuning. Real values live in shared/network/default_network_config.tres.
## The simulation tick rate is the project's physics tick rate (60 by default).

@export_range(1, 65535) var default_port: int = 7777
## Total players including the host.
@export_range(2, 32) var max_players: int = 8
## Reject joiners whose scripts/scenes differ from the host's (editor runs only).
@export var require_matching_build: bool = true

@export_group("Timeouts")
## Seconds to wait for the host before a join attempt gives up.
@export_range(1.0, 60.0) var join_timeout: float = 8.0
## Seconds the host waits for a joiner's hello before dropping them.
@export_range(0.5, 30.0) var auth_timeout: float = 3.0
## ENet drop detection (see ENetPacketPeer.set_timeout). Milliseconds.
@export_range(1, 100) var peer_timeout_factor: int = 32
@export_range(500, 60000) var peer_timeout_min_ms: int = 3000
@export_range(1000, 60000) var peer_timeout_max_ms: int = 8000
## Seconds the host waits after telling clients it is closing, so the message arrives.
@export_range(0.0, 2.0) var close_flush_time: float = 0.25

@export_group("Ping")
## Seconds between ping samples (and the host's ping broadcast).
@export_range(0.1, 10.0) var ping_interval: float = 1.0
## Pings at or below this are "good" (green).
@export_range(1, 1000) var ping_good_ms: int = 80
## Pings at or below this are "ok" (yellow); above is "bad" (red).
@export_range(1, 2000) var ping_ok_ms: int = 150

@export_group("Snapshots")
## The host sends a snapshot every this many ticks (2 at 60 Hz = 30 snapshots per second).
@export_range(1, 10) var snapshot_interval_ticks: int = 2
## Largest snapshot packet in bytes; bigger snapshots are split (stays under the network MTU).
@export_range(200, 1400) var max_snapshot_bytes: int = 1100
## Seconds clients draw remote objects behind the host, so there are always two snapshots to
## blend between. At least two snapshot intervals plus some jitter.
@export_range(0.02, 0.5) var interpolation_delay: float = 0.1
## Clients re-sync their clock estimate when it is off by more than this many ticks.
@export_range(1.0, 120.0) var clock_snap_ticks: float = 10.0
## How much of the clock error each snapshot corrects (0..1, small = smoother).
@export_range(0.01, 1.0) var clock_correction: float = 0.1

@export_group("Input commands")
## Each packet repeats this many of the latest commands, so one lost packet loses nothing.
@export_range(1, 16) var command_redundancy: int = 4
## Commands the host may save up when a player's packets arrive late (catch-up allowance).
@export_range(1, 16) var command_budget: int = 4
## Most commands the host simulates for one player in one tick.
@export_range(1, 8) var max_commands_per_tick: int = 2
## Commands waiting beyond this are dropped (a client running fast adds no extra delay).
@export_range(2, 64) var max_pending_commands: int = 16

@export_group("Prediction")
## A correction bigger than this (pixels) snaps instead of easing.
@export_range(1.0, 1000.0) var prediction_snap_distance: float = 120.0
## How fast a small correction is eased out of the visuals (per second; higher = quicker).
@export_range(1.0, 60.0) var prediction_error_decay: float = 15.0

@export_group("Lag compensation")
## The furthest back the host rewinds targets for a shot (seconds). Caps "shot behind a wall".
@export_range(0.0, 1.0) var max_rewind: float = 0.25

@export_group("Network simulator")
## Fake delay added to each of this peer's packets, both directions (ms). 0 = off.
@export_range(0, 1000) var sim_latency_ms: int = 0
## Random +/- variation on that delay (ms).
@export_range(0, 500) var sim_jitter_ms: int = 0
## Share of unreliable packets dropped (0..1).
@export_range(0.0, 0.5) var sim_loss: float = 0.0
