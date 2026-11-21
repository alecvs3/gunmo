class_name Scoreboard
extends PanelContainer
## Every player's score, best first: shown while Tab is held and once the match is over.
## Waves lists kills and deaths; Gun Game adds the gun each player is on. The numbers come
## from the players' replicated ScoreComponents, so every peer shows the same board.

const REFRESH_SECONDS: float = 0.2
const LOCAL_COLOR := Color(1.0, 0.85, 0.35)
const BOT_COLOR := Color(0.7, 0.75, 0.8)

var _state: MatchNetState = null
var _refresh_left: float = 0.0

@onready var _grid: GridContainer = %Grid
@onready var _title: Label = %ScoreTitle


## The facts one row shows about a player.
class Row:
	var id: int = 0
	var name: String = ""
	var kills: int = 0
	var deaths: int = 0
	var tier: int = 0
	var tier_kills: int = 0
	var bot: bool = false
	## This peer's own player.
	var local: bool = false

	## Best first: true if this row ranks above `other`. Gun Game: highest gun, then kills on
	## it, then kills. Waves: most kills. Then fewest deaths, then by name, so every peer shows
	## the same order.
	func ranks_above(other: Row, gun_game: bool) -> bool:
		if gun_game and tier != other.tier:
			return tier > other.tier
		if gun_game and tier_kills != other.tier_kills:
			return tier_kills > other.tier_kills
		if kills != other.kills:
			return kills > other.kills
		if deaths != other.deaths:
			return deaths < other.deaths
		return name < other.name


static func row_for(player: Player, own_id: int) -> Row:
	var score: ScoreComponent = player.get_score()
	var row := Row.new()
	row.id = player.peer_id
	row.name = player.display_name
	row.kills = score.kills
	row.deaths = score.deaths
	row.tier = score.tier
	row.tier_kills = score.tier_kills
	row.bot = player.is_bot
	row.local = player.peer_id == own_id
	return row


## Best first (Row.ranks_above).
static func rank(rows: Array[Row], mode_kind: int) -> Array[Row]:
	var ranked: Array[Row] = rows.duplicate()
	var gun_game: bool = mode_kind == MatchNetState.ModeKind.GUN_GAME
	ranked.sort_custom(func(a: Row, b: Row) -> bool: return a.ranks_above(b, gun_game))
	return ranked


static func headers(mode_kind: int) -> Array[String]:
	if mode_kind == MatchNetState.ModeKind.GUN_GAME:
		return ["Player", "Gun", "Kills", "Deaths"]
	return ["Player", "Kills", "Deaths"]


static func cells(row: Row, mode_kind: int) -> Array[String]:
	var name_text: String = row.name + (" (bot)" if row.bot else "")
	if mode_kind == MatchNetState.ModeKind.GUN_GAME:
		return [name_text, str(row.tier + 1), str(row.kills), str(row.deaths)]
	return [name_text, str(row.kills), str(row.deaths)]


## Every player on this peer, ranked (the HUD's leader line uses it too).
static func ranked_players(tree: SceneTree, mode_kind: int) -> Array[Row]:
	var own_id: int = tree.get_multiplayer().get_unique_id()
	var rows: Array[Row] = []
	for node in tree.get_nodes_in_group(Groups.PLAYERS):
		var player := node as Player
		if player != null and not player.is_queued_for_deletion():
			rows.append(row_for(player, own_id))
	return rank(rows, mode_kind)


func _ready() -> void:
	hide()
	EventBus.match_state_changed.connect(
		func(state: RefCounted) -> void: _state = (state as MatchNetState).copy()
	)
	NetworkManager.session_ended.connect(func(_reason: String) -> void: _state = null)


func _process(delta: float) -> void:
	var wanted: bool = (
		Input.is_action_pressed("scoreboard") or (_state != null and _state.is_over())
	)
	visible = NetworkManager.is_online() and _state != null and wanted
	_refresh_left -= delta
	if visible and _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		_rebuild()


func _rebuild() -> void:
	var gun_game: bool = _state.mode_kind == MatchNetState.ModeKind.GUN_GAME
	_title.text = "Gun Game" if gun_game else "Wave %d / %d" % [_state.wave, _state.total_waves]
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var header_cells: Array[String] = headers(_state.mode_kind)
	_grid.columns = header_cells.size()
	for text in header_cells:
		_add_cell(text, BOT_COLOR)
	for row in ranked_players(get_tree(), _state.mode_kind):
		var color: Color = LOCAL_COLOR if row.local else (BOT_COLOR if row.bot else Color.WHITE)
		for text in cells(row, _state.mode_kind):
			_add_cell(text, color)


func _add_cell(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(label)
