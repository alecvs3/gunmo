class_name PathPanel
extends HudMenu
## The Path window (O, Waves): the Path board (PathBoard) with every node, owned, available,
## locked or locked out, and which teammates own each; the selected node beside it (PathDetail)
## with the Take button; your Cores, this break's step, a legend and the wave along the bottom.
## Opening, closing and the look of the window come from HudMenu.
## Taking only *asks* (EventBus.path_step_requested); the host checks it with PathRules. Your
## nodes and Cores come from your own player's replicated state.

const PIP_GAP: float = 8.0
const PIP_RADIUS: float = 2.5

var _tree: PathTree = PathTree.load_default()
var _selected: int = 0
var _wave: int = 0
var _total_waves: int = 0
var _board := PathBoard.new()
var _detail := PathDetail.new()
var _cores := HudMenu.label("", 20, HudMenu.GOLD)
var _step := HudMenu.label("", 13, HudMenu.MUTED)
var _wave_label := HudMenu.label("", 14, HudMenu.GOLD)
var _pips := Control.new()


## What this break's step looks like: outside breaks, used, or still free.
static func step_text(in_break: bool, stepped: bool) -> String:
	if not in_break:
		return "The Path opens between waves: one step per break."
	if stepped:
		return "You took this break's step. The next one comes after the next wave."
	return "One step this break. Steps are permanent for the run."


func _action() -> StringName:
	return &"path"


func _hint_text() -> String:
	return "O: Path"


func _hint_slot() -> int:
	return 2


func _build_content(into: PanelContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	into.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	_board.setup(_tree)
	_board.node_selected.connect(_select)
	body.add_child(_board)
	_detail.take_pressed.connect(_take_pressed)
	body.add_child(_detail)
	column.add_child(_build_footer())
	column.add_child(
		label(
			"O or Esc to close · drag to move, wheel to zoom · the host confirms every step",
			12,
			MUTED
		)
	)
	_show(PathProgress.new(), false, {})


func _refresh(player: Player) -> void:
	var in_break: bool = _phase == GameMode.Phase.BREAK
	_show(player.get_loadout().path, in_break, _team_owners(player))


func _on_match_state_changed(state: RefCounted) -> void:
	super(state)
	var match_state := state as MatchNetState
	if match_state.wave != _wave or match_state.total_waves != _total_waves:
		_wave = match_state.wave
		_total_waves = match_state.total_waves
		_wave_label.text = "Wave %d / %d" % [_wave, _total_waves]
		_pips.custom_minimum_size = Vector2(_total_waves * PIP_GAP, PIP_GAP * 2.0)
		_pips.queue_redraw()


func _select(index: int) -> void:
	_selected = index
	_sound.play(_sounds.click)


func _take_pressed() -> void:
	_sound.play(_sounds.click)
	EventBus.path_step_requested.emit(_selected)


## Node index -> names of the other players who own it.
func _team_owners(local: Player) -> Dictionary:
	var owners: Dictionary = {}
	for node in get_tree().get_nodes_in_group(Groups.PLAYERS):
		var player := node as Player
		if player == null or player == local:
			continue
		for i in _tree.nodes.size():
			if PathTree.owns(player.get_loadout().path.owned, i):
				owners.get_or_add(i, [] as Array[String]).append(player.display_name)
	return owners


## Everything the window shows for `progress`.
func _show(progress: PathProgress, in_break: bool, owners: Dictionary) -> void:
	_cores.text = PathDetail.cores_text(progress.cores)
	_step.text = step_text(in_break, progress.stepped)
	_board.show_state(progress, in_break, _selected, owners)
	_detail.show_node(_tree, _selected, progress, in_break)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	var title := label("THE PATH", 26, GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(title)
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_step)
	_cores.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(_cores)
	return header


## The four looks a node can have, then the wave and a pip per wave.
func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	for look in PathTokenArt.NAMES.size():
		var key := label("● " + PathTokenArt.NAMES[look], 12, PathTokenArt.COLOURS[look])
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		footer.add_child(key)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(gap)
	_wave_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(_wave_label)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips.draw.connect(_draw_pips)
	footer.add_child(_pips)
	return footer


## Cleared waves gold, the current one bright, the rest faint.
func _draw_pips() -> void:
	var middle: float = _pips.size.y / 2.0
	for i in _total_waves:
		var wave: int = i + 1
		var colour := Color(GOLD, 0.25)
		if wave < _wave:
			colour = Color(GOLD, 0.7)
		elif wave == _wave:
			colour = Color.WHITE
		var at := Vector2(PIP_GAP * (i + 0.5), middle)
		_pips.draw_circle(
			at, PIP_RADIUS * (1.5 if wave == _wave else 1.0), colour, true, -1.0, true
		)
