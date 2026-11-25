class_name PathDetail
extends ScrollContainer
## The selected Path node, beside the board: its token, name, tier and branch, what it does,
## what it needs and locks out, and the Take button (with a warning that steps are permanent).
## Scrolls when the window is too short for all of it.

signal take_pressed

const WIDTH: float = 240.0
const BADGE_RADIUS: float = 34.0
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]
const WARNING := Color(0.95, 0.45, 0.42, 1)

var _node: PathNode
var _look: int = -1
var _badge := Control.new()
var _name := HudMenu.label("", 20, Color.WHITE)
var _where := HudMenu.label("", 13, HudMenu.MUTED)
var _about := HudMenu.label("", 14, Color.WHITE)
var _requires := HudMenu.label("", 13, HudMenu.GOLD)
var _rivals := HudMenu.label("", 13, HudMenu.MUTED)
var _take := Button.new()
var _warning := HudMenu.label("Permanent: cannot be undone.", 12, WARNING)


## "1 Core", "3 Cores".
static func cores_text(cores: int) -> String:
	return "%d Core" % cores if cores == 1 else "%d Cores" % cores


## "Tier II · Logistics".
static func where_text(path_node: PathNode) -> String:
	return "Tier %s · %s" % [ROMAN[clampi(path_node.tier, 1, ROMAN.size()) - 1], path_node.branch]


## "Requires: Fortitude", or "Requires: nothing".
static func requires_text(path_node: PathNode) -> String:
	var names: Array[String] = []
	for needed in path_node.requires:
		names.append(needed.display_name)
	return "Requires: %s" % (", ".join(names) if not names.is_empty() else "nothing")


## "Locks out: Scavenger", or "Locks out: none" (excludes work both ways).
static func rivals_text(tree: PathTree, index: int) -> String:
	var names: Array[String] = []
	for rival in tree.rivals(index):
		names.append(tree.node(rival).display_name)
	return "Locks out: %s" % (", ".join(names) if not names.is_empty() else "none")


## The Take button: what it costs, that you own it, or why not.
static func take_text(path_node: PathNode, status: PathRules.Status, problem: String) -> String:
	match status:
		PathRules.Status.OWNED:
			return "%s is on your Path" % path_node.display_name
		PathRules.Status.AVAILABLE:
			return "Take %s · %s" % [path_node.display_name, cores_text(path_node.core_cost)]
	return problem


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_badge.custom_minimum_size = Vector2(0, BADGE_RADIUS * 2.0 + 16.0)
	_badge.draw.connect(_draw_badge)
	column.add_child(_badge)
	for line in [_name, _where, _about, _requires, _rivals]:
		(line as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(line)
	column.add_child(_build_take())
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_warning)


func show_node(tree: PathTree, index: int, progress: PathProgress, in_break: bool) -> void:
	var path_node: PathNode = tree.node(index)
	var status: PathRules.Status = PathRules.status(tree, progress, index, in_break)
	var shown: int = PathTokenArt.look(status, PathRules.is_locked_out(tree, progress, index))
	if path_node != _node or shown != _look:
		_node = path_node
		_look = shown
		_badge.queue_redraw()
	_name.text = path_node.display_name.to_upper()
	_where.text = where_text(path_node)
	_about.text = path_node.description
	_requires.text = requires_text(path_node)
	_rivals.text = rivals_text(tree, index)
	_take.text = take_text(path_node, status, PathRules.check(tree, progress, index, in_break))
	_take.disabled = status != PathRules.Status.AVAILABLE
	_warning.visible = status == PathRules.Status.AVAILABLE


func _build_take() -> Button:
	_take.custom_minimum_size = Vector2(0, 40)
	_take.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_take.add_theme_font_size_override("font_size", 15)
	var gold: Color = HudMenu.GOLD
	_take.add_theme_stylebox_override("normal", HudMenu.box(Color(gold, 0.22), gold, 2))
	_take.add_theme_stylebox_override("hover", HudMenu.box(Color(gold, 0.34), gold, 2))
	_take.add_theme_stylebox_override("pressed", HudMenu.box(Color(gold, 0.45), gold, 2))
	var faded := HudMenu.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1))
	_take.add_theme_stylebox_override("disabled", faded)
	_take.pressed.connect(take_pressed.emit)
	return _take


func _draw_badge() -> void:
	if _node == null or _look < 0:
		return
	var centre := Vector2(_badge.size.x / 2.0, _badge.size.y / 2.0)
	PathTokenArt.draw(_badge, centre, BADGE_RADIUS, _node, _look as PathTokenArt.Look, false)
