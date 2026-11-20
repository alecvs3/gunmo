class_name NetworkConfig
extends Resource
## Network tuning. Real values live in shared/network/default_network_config.tres.

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

@export_group("Smoothing")
## How fast remote objects catch up to the latest network position (higher = snappier).
@export_range(1.0, 60.0) var smoothing_rate: float = 15.0
## Jumps larger than this (pixels) snap instantly instead of gliding (spawns, respawns).
@export_range(10.0, 2000.0) var snap_distance: float = 200.0
