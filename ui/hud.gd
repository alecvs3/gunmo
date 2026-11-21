class_name Hud
extends Control
## The in-match HUD. Your health, ammo and reload come from your own player (predicted on a
## client, so they react instantly); the wave, enemies left, break countdown and ready status
## come from the replicated MatchState. Banners announce waves, clears, being down and the end.

const BANNER_SECONDS: float = 2.5

var _state: MatchNetState = null
var _previous_phase: int = -1
var _previous_wave: int = 0
var _local_ready: bool = false
var _spectating: int = 0
var _banner_left: float = 0.0

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _ammo_label: Label = %AmmoLabel
@onready var _reload_bar: ProgressBar = %ReloadBar
@onready var _credits_label: Label = %CreditsLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _info_label: Label = %InfoLabel
@onready var _ready_label: Label = %ReadyLabel
@onready var _banner: Label = %Banner
@onready var _status_label: Label = %StatusLabel


## The lines under the wave title: countdown or enemies left, then the ready status.
static func match_lines(state: MatchNetState, now_tick: float, local_ready: bool) -> Array[String]:
	match state.phase:
		GameMode.Phase.LOBBY, GameMode.Phase.BREAK:
			var seconds: float = state.seconds_left(now_tick)
			var timer: String = "Waiting for players"
			if seconds >= 0.0:
				timer = "Next wave in %d s" % ceili(seconds)
			var counts: String = "%d/%d ready" % [state.ready_count, state.player_count]
			if local_ready:
				return [timer, "Ready! (%s) · F to cancel" % counts]
			return [timer, "Press F when ready (%s)" % counts]
		GameMode.Phase.ACTIVE:
			return ["Enemies left: %d" % state.enemies_left, ""]
	return ["", ""]


static func wave_title(state: MatchNetState) -> String:
	if state.phase == GameMode.Phase.LOBBY:
		return "Get ready"
	return "Wave %d / %d" % [state.wave, state.total_waves]


## The banner to show when the state moves on from (previous_phase, previous_wave), or "".
static func banner_for(previous_phase: int, previous_wave: int, state: MatchNetState) -> String:
	if state.phase == GameMode.Phase.ACTIVE and state.wave != previous_wave:
		return "Wave %d" % state.wave
	if state.phase == previous_phase:
		return ""
	match state.phase:
		GameMode.Phase.BREAK:
			return "Wave %d cleared!" % state.wave
		GameMode.Phase.VICTORY:
			return "Victory!"
		GameMode.Phase.DEFEAT:
			return "Defeat"
	return ""


func _ready() -> void:
	hide()
	_banner.hide()
	EventBus.match_state_changed.connect(_on_match_state_changed)
	EventBus.local_ready_changed.connect(func(is_ready: bool) -> void: _local_ready = is_ready)
	EventBus.spectating_changed.connect(func(peer_id: int) -> void: _spectating = peer_id)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))


func _process(delta: float) -> void:
	visible = NetworkManager.is_online() and _state != null
	if not visible:
		return
	_show_player(_own_player())
	_show_match()
	_banner_left -= delta
	_banner.visible = _banner_left > 0.0
	_banner.modulate.a = clampf(_banner_left, 0.0, 1.0)


func _on_match_state_changed(state: RefCounted) -> void:
	var new_state := (state as MatchNetState).copy()
	var text: String = banner_for(_previous_phase, _previous_wave, new_state)
	if _previous_phase != -1 and not text.is_empty():
		_banner.text = text
		_banner_left = BANNER_SECONDS
	_previous_phase = new_state.phase
	_previous_wave = new_state.wave
	_state = new_state


func _on_session_ended() -> void:
	_state = null
	_previous_phase = -1
	_previous_wave = 0
	_local_ready = false
	_spectating = 0


func _show_player(player: Player) -> void:
	if player == null:
		return
	var stats: Dictionary = player.hud_stats()
	_health_bar.max_value = stats["max_health"]
	_health_bar.value = stats["health"]
	_health_label.text = "%d / %d" % [stats["health"], stats["max_health"]]
	var reload: float = stats["reload"]
	_reload_bar.visible = reload > 0.0
	_reload_bar.value = reload
	_ammo_label.text = (
		"Reloading…" if reload > 0.0 else "%d / %d" % [stats["ammo"], stats["magazine"]]
	)
	_credits_label.text = "%d credits" % stats["credits"]
	var down: bool = not player.is_alive and _state.phase == GameMode.Phase.ACTIVE
	_status_label.visible = down
	if down:
		var watching: String = "spectating a teammate · click to switch"
		_status_label.text = (
			"You're down · " + (watching if _spectating != 0 else "nobody left to watch")
		)


func _show_match() -> void:
	_wave_label.text = wave_title(_state)
	var lines: Array[String] = match_lines(
		_state, NetworkManager.clock.server_tick_now(), _local_ready
	)
	_info_label.text = lines[0]
	_ready_label.text = lines[1]


func _own_player() -> Player:
	var own_id: int = multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(Groups.PLAYERS):
		var player := node as Player
		if player != null and player.peer_id == own_id:
			return player
	return null
