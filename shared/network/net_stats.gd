class_name NetStats
extends RefCounted
## Live netcode numbers for the F3 overlay and the latency checks, written by the systems
## that know them.

## Host: a remote player's inputs stalling this many ticks in a row is logged as a hiccup.
const STALL_LOG_TICKS: int = 6

## Owner: size of the last prediction correction, in pixels.
var prediction_error: float = 0.0
## Owner: input commands sent but not yet confirmed by the host.
var unconfirmed_commands: int = 0
## Host: entities in the last snapshot, and the bytes sent for it to one client (all packets).
var snapshot_entities: int = 0
var snapshot_bytes: int = 0
## Client: tick stamped on the newest snapshot received.
var newest_snapshot_tick: int = 0
## Client: snapshots that never arrived (total). Jitter and the smoothing delay live on the
## NetClock, which uses them.
var snapshots_missed: int = 0
## Host: per player (peer id -> PeerInput) how their inputs arrive. Shared with clients.
var peer_inputs: Dictionary = {}


## How one player's input commands reach the host.
class PeerInput:
	## Arrival jitter (ms).
	var jitter_ms: float = 0.0
	## Commands the host holds back to smooth them out (ticks of extra delay).
	var buffer_ticks: int = 0
	## Ticks in the last second the host had no input from this player to simulate.
	var late_per_second: int = 0

	func to_array() -> Array:
		return [snappedf(jitter_ms, 0.1), buffer_ticks, late_per_second]

	static func from_array(values: Variant) -> PeerInput:
		var input := PeerInput.new()
		if values is Array and values.size() == 3:
			input.jitter_ms = clampf(float(values[0]), 0.0, 10000.0)
			input.buffer_ticks = clampi(int(values[1]), 0, 255)
			input.late_per_second = clampi(int(values[2]), 0, 1000)
		return input


## Host: how a remote player's inputs arrive (from their CommandQueue), for F3 (shared with
## clients through PingTracker) and the net log. Call once per tick.
func report_inputs(peer_id: int, who: String, commands: CommandQueue) -> void:
	var report: PeerInput = peer_inputs.get(peer_id)
	if report == null:
		report = PeerInput.new()
		peer_inputs[peer_id] = report
	var jitter_ms: float = commands.jitter.jitter_seconds() * 1000.0
	if commands.buffer_ticks != report.buffer_ticks:
		NetLog.write(
			(
				"inputs from %s arrive unevenly (jitter %.1f ms): holding back %d tick(s)"
				% [who, jitter_ms, commands.buffer_ticks]
			)
		)
	report.jitter_ms = jitter_ms
	report.buffer_ticks = commands.buffer_ticks
	report.late_per_second = commands.late_per_second()
	if commands.stall_run == STALL_LOG_TICKS:
		var stalled_ms: int = roundi(STALL_LOG_TICKS * NetClock.tick_delta() * 1000.0)
		NetLog.write_limited(
			"stall_%d" % peer_id, "hiccup: no input from %s for %d ms" % [who, stalled_ms]
		)


func reset() -> void:
	prediction_error = 0.0
	unconfirmed_commands = 0
	snapshot_entities = 0
	snapshot_bytes = 0
	newest_snapshot_tick = 0
	snapshots_missed = 0
	peer_inputs.clear()
