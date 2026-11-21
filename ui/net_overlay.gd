class_name NetOverlay
extends Control
## Top-right connection info while online: ping (or "Host") always, details on F3:
## bandwidth, snapshot jitter, missed snapshots and the smoothing delay, and for every player
## their ping and how their inputs reach the host (jitter, held-back ticks, late ticks/s).

const QUALITY_COLORS: Dictionary = {
	PingTracker.Quality.GOOD: Color(0.45, 0.9, 0.45),
	PingTracker.Quality.OK: Color(1.0, 0.85, 0.3),
	PingTracker.Quality.BAD: Color(1.0, 0.4, 0.35),
}
const HOST_COLOR: Color = Color(0.8, 0.85, 0.9)

@onready var _ping_label: Label = %PingLabel
@onready var _details_label: Label = %DetailsLabel


func _ready() -> void:
	hide()
	_details_label.hide()
	NetworkManager.ping.stats_updated.connect(_refresh)
	NetworkManager.hosting_started.connect(_refresh)
	NetworkManager.joined_host.connect(_refresh)
	NetworkManager.session_ended.connect(hide.unbind(1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_net_overlay"):
		_details_label.visible = not _details_label.visible
		_refresh()


func _refresh() -> void:
	visible = NetworkManager.is_online()
	if not visible:
		return
	var tracker: PingTracker = NetworkManager.ping
	if NetworkManager.is_host():
		_ping_label.text = _host_text(NetworkManager.peers.size())
		_ping_label.modulate = HOST_COLOR
	else:
		var quality: PingTracker.Quality = PingTracker.quality(
			tracker.own_ping_ms, NetworkManager.config
		)
		_ping_label.text = "Ping %d ms" % tracker.own_ping_ms
		_ping_label.modulate = QUALITY_COLORS[quality]
	if _details_label.visible:
		_details_label.text = _details_text(tracker)


func _details_text(tracker: PingTracker) -> String:
	var own_id: int = multiplayer.get_unique_id()
	var lines := PackedStringArray()
	lines.append("Peer %d · build %s" % [own_id, NetworkManager.gate.hello["build"]])
	lines.append("%d FPS · %s" % [Engine.get_frames_per_second(), GameSettings.display_summary()])
	var loss_percent: float = tracker.packet_loss * 100.0
	var up_kb: float = tracker.sent_bytes_per_sec / 1024.0
	var down_kb: float = tracker.received_bytes_per_sec / 1024.0
	lines.append("Loss %.1f%% · up %.1f KB/s · down %.1f KB/s" % [loss_percent, up_kb, down_kb])
	lines.append_array(_netcode_lines())
	for peer_id: int in tracker.peer_pings:
		lines.append(peer_line(peer_id, tracker.peer_pings[peer_id], own_id))
	return "\n".join(lines)


## "Peer 5: 42 ms · input jitter 3.1 ms, held 1, late 0/s (you)"
static func peer_line(peer_id: int, ping_ms: int, own_id: int) -> String:
	var text: String = "Peer %d: %d ms" % [peer_id, ping_ms]
	var input: NetStats.PeerInput = NetworkManager.stats.peer_inputs.get(peer_id)
	if input != null:
		text += (
			" · input jitter %.1f ms, held %d, late %d/s"
			% [input.jitter_ms, input.buffer_ticks, input.late_per_second]
		)
	text += " (host)" if peer_id == 1 else ""
	return text + (" (you)" if peer_id == own_id else "")


func _netcode_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var stats: NetStats = NetworkManager.stats
	var clock: NetClock = NetworkManager.clock
	var smoothing_ms: float = clock.smoothing_delay() * 1000.0
	if NetworkManager.is_host():
		var kb: float = stats.snapshot_bytes / 1024.0
		lines.append(
			"Tick %d · snapshot %d entities, %.1f KB" % [clock.tick, stats.snapshot_entities, kb]
		)
		lines.append("Others drawn %.0f ms behind (host view delay)" % smoothing_ms)
	else:
		(
			lines
			. append(
				(
					"Server tick ≈ %.0f · others drawn %.0f ms behind (%.0f latency + %.0f smoothing)"
					% [
						clock.server_tick_now(),
						smoothing_ms,
						clock.one_way_latency() * 1000.0,
						clock.buffer_delay() * 1000.0,
					]
				)
			)
		)
		(
			lines
			. append(
				(
					"Snapshot jitter %.1f ms · %d missed · smoothing ran dry %d×"
					% [
						clock.snapshot_jitter.jitter_seconds() * 1000.0,
						stats.snapshots_missed,
						clock.ran_dry_count,
					]
				)
			)
		)
		lines.append(
			(
				"Prediction error %.1f px · %d unconfirmed inputs"
				% [stats.prediction_error, stats.unconfirmed_commands]
			)
		)
	var simulator: NetSimulator = NetworkManager.channel.simulator
	if simulator.is_active():
		var loss: float = simulator.loss * 100.0
		lines.append(
			"SIMULATED +%d ±%d ms, %.0f%% loss" % [simulator.latency_ms, simulator.jitter_ms, loss]
		)
	return lines


static func _host_text(player_count: int) -> String:
	return "Host · %d player%s" % [player_count, "" if player_count == 1 else "s"]
