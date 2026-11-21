class_name ResultsScreen
extends Control
## Shown when the match is over: the result (Waves: how far the team got; Gun Game: who won)
## and what next. The scoreboard shows next to it.
## Only the host can play again or end the match for everyone; a client can leave.

@onready var _title: Label = %Title
@onready var _detail: Label = %Detail
@onready var _play_again: Button = %PlayAgainButton
@onready var _end_match: Button = %EndMatchButton
@onready var _waiting: Label = %WaitingLabel
@onready var _leave: Button = %LeaveButton


static func detail_text(state: MatchNetState) -> String:
	if state.mode_kind == MatchNetState.ModeKind.GUN_GAME:
		return "First to finish all %d guns." % state.ladder_length
	if state.phase == GameMode.Phase.VICTORY:
		return "All %d waves cleared." % state.total_waves
	return "The team fell on wave %d of %d." % [state.wave, state.total_waves]


func _ready() -> void:
	hide()
	_play_again.pressed.connect(EventBus.match_restart_requested.emit)
	_end_match.pressed.connect(NetworkManager.leave)
	_leave.pressed.connect(NetworkManager.leave)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	NetworkManager.session_ended.connect(hide.unbind(1))


func _on_match_state_changed(state: RefCounted) -> void:
	var match_state := state as MatchNetState
	var over: bool = (
		match_state.phase == GameMode.Phase.VICTORY or match_state.phase == GameMode.Phase.DEFEAT
	)
	visible = over
	if not over:
		return
	_title.text = _title_text(match_state)
	_detail.text = detail_text(match_state)
	var host: bool = NetworkManager.is_host()
	_play_again.visible = host
	_end_match.visible = host
	_waiting.visible = not host
	_leave.visible = not host


func _title_text(state: MatchNetState) -> String:
	if state.mode_kind == MatchNetState.ModeKind.GUN_GAME:
		var winner: Player = Player.find_by_id(get_tree(), state.winner_id)
		var winner_name: String = winner.display_name if winner != null else "Someone"
		var is_you: bool = state.winner_id == multiplayer.get_unique_id()
		return GunGameHudText.winner_title(winner_name, is_you)
	return "Victory!" if state.phase == GameMode.Phase.VICTORY else "Defeat"
