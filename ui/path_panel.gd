class_name PathPanel
extends Control
## The Path window (Waves): a see-through window like the shop. While the shop is open (the
## lobby and between waves) an "O: Path" hint shows; O opens the window, O, Esc or a click
## outside closes it. One column per branch with its nodes by tier (owned, available, locked,
## and which teammates own them), your Cores, and a Take button for the selected node.
## Taking only *asks* (EventBus.path_step_requested); the host checks it with PathRules. Your
## nodes and Cores come from your own player's replicated state.

const GOLD := Color(1, 0.85, 0.35, 1)
const MUTED := Color(0.62, 0.65, 0.7, 1)

var _tree: PathTree = PathTree.load_default()
var _open: bool = false
var _shown: bool = false
var _phase: int = -1
var _selected: int = 0
var _sounds: SoundData = SoundData.load_default()
var _sound := SoundPlayback.new()
var _cards: Array[PathNodeCard] = []
var _hint := Label.new()
var _dim := ColorRect.new()
var _window := PanelContainer.new()
var _cores := Label.new()
var _step := Label.new()
var _name := Label.new()
var _about := Label.new()
var _take := Button.new()


## What this break's step looks like: outside breaks, used, or still free.
static func step_text(in_break: bool, stepped: bool) -> String:
	if not in_break:
		return "The Path opens between waves: one step per break."
	if stepped:
		return "You took this break's step. The next one comes after the next wave."
	return "One step this break. Steps are permanent for the run."


## The Take button: what it costs, that you own it, or why not.
static func take_text(path_node: PathNode, status: PathRules.Status, problem: String) -> String:
	match status:
		PathRules.Status.OWNED:
			return "%s is on your Path" % path_node.display_name
		PathRules.Status.AVAILABLE:
			var cost: String = PathNodeCard.cores_text(path_node.core_cost)
			return "Take %s · %s" % [path_node.display_name, cost]
	return problem


## The nodes of `branch`, ordered by tier (tree order within a tier).
static func branch_nodes(tree: PathTree, branch: String) -> Array[int]:
	var found: Array[int] = []
	for tier in range(1, 6):
		for i in tree.nodes.size():
			var path_node: PathNode = tree.node(i)
			if path_node != null and path_node.branch == branch and path_node.tier == tier:
				found.append(i)
	return found


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	add_child(_sound)
	_build_hint()
	_build_window()
	_show(PathProgress.new(), false, {})
	EventBus.match_state_changed.connect(_on_match_state_changed)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible and _shown:
		_show_window(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("path") and _open:
		_show_window(not _shown)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	visible = NetworkManager.is_online() and _open
	_hint.visible = not _shown
	_dim.visible = _shown
	_window.visible = _shown
	var player: Player = Player.find_local(get_tree())
	if _shown and player != null:
		var in_break: bool = _phase == GameMode.Phase.BREAK
		_show(player.get_loadout().path, in_break, _team_owners(player))


func _show_window(shown: bool) -> void:
	_shown = shown
	_sound.play(_sounds.shop_open if shown else _sounds.shop_close)


func _on_match_state_changed(state: RefCounted) -> void:
	var match_state := state as MatchNetState
	_open = match_state.shop_open
	if match_state.phase != _phase:
		_phase = match_state.phase
		_shown = false


func _on_session_ended() -> void:
	_phase = -1
	_open = false
	_shown = false


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
	_cores.text = PathNodeCard.cores_text(progress.cores)
	_step.text = step_text(in_break, progress.stepped)
	for card in _cards:
		var status: PathRules.Status = PathRules.status(_tree, progress, card.index, in_break)
		var names: Array[String] = owners.get(card.index, [] as Array[String])
		var team: String = PathNodeCard.team_text(names)
		card.show_state(_tree.node(card.index), status, team, card.index == _selected)
	var chosen: PathNode = _tree.node(_selected)
	var problem: String = PathRules.check(_tree, progress, _selected, in_break)
	var chosen_status: PathRules.Status = PathRules.status(_tree, progress, _selected, in_break)
	_name.text = chosen.display_name
	_about.text = chosen.description
	_take.text = take_text(chosen, chosen_status, problem)
	_take.disabled = chosen_status != PathRules.Status.AVAILABLE


func _build_hint() -> void:
	_hint.text = "O: Path"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -136.0
	_hint.offset_top = -108.0
	_hint.offset_right = -16.0
	_hint.offset_bottom = -80.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_font_size_override("font_size", 18)
	add_child(_hint)


func _build_window() -> void:
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.4)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	_window.anchor_left = 0.08
	_window.anchor_top = 0.07
	_window.anchor_right = 0.92
	_window.anchor_bottom = 0.93
	_window.add_theme_stylebox_override(
		"panel", PetPanel.box(Color(0.08, 0.09, 0.11, 0.86), Color(GOLD, 0.35), 1)
	)
	add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_window.add_child(column)
	column.add_child(_build_header())
	column.add_child(_build_branches())
	column.add_child(_build_detail())
	column.add_child(_label("O or Esc to close · the host confirms every step", 12, MUTED))


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label("The Path", 24, Color.WHITE))
	titles.add_child(_step)
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.add_theme_font_size_override("font_size", 13)
	_step.add_theme_color_override("font_color", MUTED)
	_cores.add_theme_color_override("font_color", GOLD)
	_cores.add_theme_font_size_override("font_size", 20)
	header.add_child(_cores)
	return header


## One column per branch, its nodes by tier; scrolls when the tree is bigger than the window.
func _build_branches() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	scroll.add_child(columns)
	for branch in _tree.branches():
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 6)
		columns.add_child(list)
		list.add_child(_label(branch, 16, GOLD))
		for i in branch_nodes(_tree, branch):
			var card := PathNodeCard.new(i)
			card.pressed.connect(_select.bind(i))
			list.add_child(card)
			_cards.append(card)
	return scroll


func _build_detail() -> Control:
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 12)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(words)
	_name.add_theme_font_size_override("font_size", 18)
	words.add_child(_name)
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.add_theme_color_override("font_color", MUTED)
	words.add_child(_about)
	_take.custom_minimum_size = Vector2(220, 40)
	_take.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_take.add_theme_font_size_override("font_size", 15)
	_take.add_theme_stylebox_override("normal", PetPanel.box(Color(GOLD, 0.22), GOLD, 2))
	_take.add_theme_stylebox_override("hover", PetPanel.box(Color(GOLD, 0.34), GOLD, 2))
	_take.add_theme_stylebox_override(
		"disabled", PetPanel.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1))
	)
	_take.pressed.connect(_take_pressed)
	detail.add_child(_take)
	return detail


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_show_window(false)
		_dim.accept_event()
