class_name PathPanel
extends HudMenu
## The Path window (O, Waves). One column per branch with its nodes by tier (owned, available,
## locked, and which teammates own them), your Cores, and a Take button for the selected node.
## Opening, closing and the look of the window come from HudMenu.
## Taking only *asks* (EventBus.path_step_requested); the host checks it with PathRules. Your
## nodes and Cores come from your own player's replicated state.

var _tree: PathTree = PathTree.load_default()
var _selected: int = 0
var _cards: Array[PathNodeCard] = []
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
	column.add_child(_build_branches())
	column.add_child(_build_detail())
	column.add_child(label("O or Esc to close · the host confirms every step", 12, MUTED))
	_show(PathProgress.new(), false, {})


func _refresh(player: Player) -> void:
	var in_break: bool = _phase == GameMode.Phase.BREAK
	_show(player.get_loadout().path, in_break, _team_owners(player))


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


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(label("The Path", 24, Color.WHITE))
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
		list.add_child(label(branch, 16, GOLD))
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
	_take.add_theme_stylebox_override("normal", box(Color(GOLD, 0.22), GOLD, 2))
	_take.add_theme_stylebox_override("hover", box(Color(GOLD, 0.34), GOLD, 2))
	_take.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1)))
	_take.pressed.connect(_take_pressed)
	detail.add_child(_take)
	return detail
