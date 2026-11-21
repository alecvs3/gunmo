class_name NetStats
extends RefCounted
## Live netcode numbers for the F3 overlay, written by the systems that know them.

## Owner: size of the last prediction correction, in pixels.
var prediction_error: float = 0.0
## Owner: input commands sent but not yet confirmed by the host.
var unconfirmed_commands: int = 0
## Host: entities in the last snapshot, and its size in bytes (all packets).
var snapshot_entities: int = 0
var snapshot_bytes: int = 0
## Client: tick stamped on the newest snapshot received.
var newest_snapshot_tick: int = 0


func reset() -> void:
	prediction_error = 0.0
	unconfirmed_commands = 0
	snapshot_entities = 0
	snapshot_bytes = 0
	newest_snapshot_tick = 0
