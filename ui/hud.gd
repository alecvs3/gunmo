class_name Hud
extends Control
## The in-match HUD. Your health, ammo and reload come from your own player (predicted on a
## client, so they react instantly); the wave, enemies left, break countdown and ready status
## come from the replicated MatchState. Banners announce waves, clears, being down and the end.
## In Gun Game the match panel shows your gun, kills on it and the leader instead, and a banner
## announces each new gun.

const BANNER_SECONDS: float = 2.5
## Show the revive prompt this close to a downed teammate (px; the host's range decides).
const REVIVE_HINT_RANGE: float = 80.0

var _state: MatchNetState = null
var _previous_phase: int = -1
var _previous_wave: int = 0
var _local_ready: bool = false
var _spectating: int = 0
var _banner_left: float = 0.0
var _modifiers: ModifierCatalog = ModifierCatalog.load_default()
## Gun Game: the tier our player was on last frame (-1 = unknown), for the next-gun banner.
var _last_tier: int = -1

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
	var player: Player = Player.find_local(get_tree())
	_show_player(player)
	if _state.mode_kind == MatchNetState.ModeKind.GUN_GAME:
		_show_gun_game(player)
	else:
		_show_match()
	_banner_left -= delta
	_banner.visible = _banner_left > 0.0
	_banner.modulate.a = clampf(_banner_left, 0.0, 1.0)


func _on_match_state_changed(state: RefCounted) -> void:
	var new_state := (state as MatchNetState).copy()
	var text: String = banner_for(_previous_phase, _previous_wave, new_state)
	if new_state.mode_kind == MatchNetState.ModeKind.GUN_GAME:
		text = _gun_game_banner(new_state)
	var modifiers: String = _modifiers.names(new_state.modifier_mask)
	if new_state.phase == GameMode.Phase.ACTIVE and text.begins_with("Wave") and modifiers != "":
		text += " · " + modifiers
	if _previous_phase != -1 and not text.is_empty():
		_show_banner(text)
	_previous_phase = new_state.phase
	_previous_wave = new_state.wave
	_state = new_state


func _on_session_ended() -> void:
	_state = null
	_previous_phase = -1
	_previous_wave = 0
	_local_ready = false
	_spectating = 0
	_last_tier = -1


func _show_player(player: Player) -> void:
	if player == null:
		return
	var stats: Player.HudStats = player.hud_stats()
	_health_bar.max_value = stats.max_health
	_health_bar.value = stats.health
	_health_label.text = "%d / %d" % [stats.health, stats.max_health]
	var reload: float = stats.reload
	_reload_bar.visible = reload > 0.0
	_reload_bar.value = reload
	_ammo_label.text = ("Reloading…" if reload > 0.0 else "%d / %d" % [stats.ammo, stats.magazine])
	_credits_label.text = "%d credits" % stats.credits
	_credits_label.visible = _state.mode_kind == MatchNetState.ModeKind.WAVES
	var down: bool = not player.is_alive and _state.phase == GameMode.Phase.ACTIVE
	_status_label.visible = down
	if down and _state.mode_kind == MatchNetState.ModeKind.GUN_GAME:
		_status_label.text = "Respawning…"
	elif down:
		_status_label.text = down_text(player.down_left, player.revive_progress, _spectating)
	else:
		var near: Player = _downed_teammate_near(player)
		_status_label.visible = near != null and _state.phase == GameMode.Phase.ACTIVE
		if near != null:
			_status_label.text = revive_prompt(near.display_name, near.revive_progress)


## Co-op status while down: bleeding out (being revived), or out and spectating.
static func down_text(down_left: int, revive_progress: int, spectating: int) -> String:
	if down_left > 0 and revive_progress > 0:
		return "You're down · being revived %d%%" % roundi(revive_progress / 2.55)
	if down_left > 0:
		return "You're down · a teammate can revive you (%d%% left)" % roundi(down_left / 2.55)
	var watching: String = "spectating a teammate · click to switch"
	return "You're down · " + (watching if spectating != 0 else "nobody left to watch")


## Co-op prompt next to a downed teammate.
static func revive_prompt(teammate: String, revive_progress: int) -> String:
	if revive_progress > 0:
		return "Reviving %s… %d%%" % [teammate, roundi(revive_progress / 2.55)]
	return "Hold E to revive %s" % teammate


## A downed teammate close enough to revive (the host decides; this only shows the prompt).
func _downed_teammate_near(player: Player) -> Player:
	for node in get_tree().get_nodes_in_group(Groups.PLAYERS):
		var teammate := node as Player
		if teammate != null and teammate != player and teammate.is_downed():
			if player.global_position.distance_to(teammate.global_position) <= REVIVE_HINT_RANGE:
				return teammate
	return null


func _show_match() -> void:
	_wave_label.text = wave_title(_state)
	var lines: Array[String] = match_lines(
		_state, NetworkManager.clock.server_tick_now(), _local_ready
	)
	_info_label.text = lines[0]
	_ready_label.text = lines[1]
	if _state.phase == GameMode.Phase.ACTIVE:
		_ready_label.text = _modifiers.names(_state.modifier_mask)


func _show_gun_game(player: Player) -> void:
	var ranked: Array[Scoreboard.Row] = Scoreboard.ranked_players(get_tree(), _state.mode_kind)
	_ready_label.text = GunGameHudText.leader_line(ranked, multiplayer.get_unique_id())
	if player == null:
		_wave_label.text = "Gun Game"
		_info_label.text = ""
		return
	var score: ScoreComponent = player.get_score()
	var weapon_name: String = player.get_loadout().current_weapon().display_name
	_wave_label.text = GunGameHudText.title(_state, score.tier, weapon_name)
	_info_label.text = GunGameHudText.progress(_state, score.tier, score.tier_kills)
	if _last_tier >= 0 and score.tier > _last_tier:
		_show_banner(GunGameHudText.tier_up_banner(weapon_name))
	_last_tier = score.tier


## Gun Game only announces the winner (new guns are announced from the player's tier).
func _gun_game_banner(state: MatchNetState) -> String:
	if state.winner_id == 0 or state.phase == _previous_phase:
		return ""
	var winner: Player = Player.find_by_id(get_tree(), state.winner_id)
	var winner_name: String = winner.display_name if winner != null else "Someone"
	return GunGameHudText.winner_title(winner_name, state.winner_id == multiplayer.get_unique_id())


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_SECONDS
