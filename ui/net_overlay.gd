class_name NetOverlay
extends Control
## Top-right connection info while online: ping (or "Host") always, details on F3.

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
		_ping_label.text = "Host · %d players" % NetworkManager.peers.size()
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
	var loss_percent: float = tracker.packet_loss * 100.0
	var up_kb: float = tracker.sent_bytes_per_sec / 1024.0
	var down_kb: float = tracker.received_bytes_per_sec / 1024.0
	lines.append("Loss %.1f%% · up %.1f KB/s · down %.1f KB/s" % [loss_percent, up_kb, down_kb])
	for peer_id: int in tracker.peer_pings:
		var suffix: String = " (host)" if peer_id == 1 else ""
		suffix += " (you)" if peer_id == own_id else ""
		lines.append("Peer %d: %d ms%s" % [peer_id, tracker.peer_pings[peer_id], suffix])
	return "\n".join(lines)
