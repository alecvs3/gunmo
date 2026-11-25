class_name PathBoard
extends ScrollContainer
## The Path board: every node at its `board_position`, a line from each node to the ones it
## unlocks (gold once the route is open), a red broken chain between nodes that lock each other
## out, and a banner over each branch. Drag to pan, mouse wheel to zoom.

signal node_selected(index: int)

## One board cell (px at zoom 1).
const CELL := Vector2(150, 132)
## Room around the nodes, the top part for the branch banners.
const MARGIN := Vector2(24, 40)
const ZOOM_MIN: float = 0.6
const ZOOM_MAX: float = 1.6
const ZOOM_STEP: float = 1.1
const LINE_WIDTH: float = 3.0
const LINE_OPEN := Color(1, 0.85, 0.35, 0.9)
const LINE_SHUT := Color(0.5, 0.53, 0.58, 0.45)
const BANNER_SIZE: int = 15
const DRAG_BUTTONS: int = (
	MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE
)

var tokens: Array[PathNodeToken] = []
var _tree: PathTree
var _owned: int = 0
var _zoom: float = 1.0
## What the scroll area scrolls: the board's size at the current zoom.
var _frame := Control.new()
## The board at zoom 1, scaled by the zoom: lines are drawn here and tokens sit on it.
var _canvas := Control.new()


## The nodes' corner and extent in board cells (zero when the tree is empty).
static func cell_bounds(tree: PathTree) -> Rect2:
	var bounds := Rect2()
	var first: bool = true
	for path_node in tree.nodes:
		if path_node == null:
			continue
		if first:
			bounds = Rect2(path_node.board_position, Vector2.ZERO)
			first = false
		bounds = bounds.expand(path_node.board_position)
	return bounds


## Where node `index`'s token centre sits on the board at zoom 1.
static func spot(tree: PathTree, index: int) -> Vector2:
	var corner: Vector2 = cell_bounds(tree).position
	return MARGIN + (tree.node(index).board_position - corner) * CELL + CELL / 2.0


## The board's size at zoom 1.
static func board_size(tree: PathTree) -> Vector2:
	return MARGIN * 2.0 + (cell_bounds(tree).size + Vector2.ONE) * CELL


func setup(tree: PathTree) -> void:
	_tree = tree
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.gui_input.connect(_on_frame_input)
	_frame.resized.connect(_place_canvas)
	add_child(_frame)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = board_size(tree)
	_canvas.draw.connect(_draw_board)
	_frame.add_child(_canvas)
	for i in tree.nodes.size():
		if tree.node(i) == null:
			continue
		var token := PathNodeToken.new(i, tree.node(i))
		token.position = spot(tree, i) - PathNodeToken.CENTRE
		token.pressed.connect(node_selected.emit.bind(i))
		_canvas.add_child(token)
		tokens.append(token)
	_set_zoom(1.0)


func show_state(progress: PathProgress, in_break: bool, selected: int, owners: Dictionary) -> void:
	for token in tokens:
		var status: PathRules.Status = PathRules.status(_tree, progress, token.index, in_break)
		var locked_out: bool = PathRules.is_locked_out(_tree, progress, token.index)
		var team: Array[String] = owners.get(token.index, [] as Array[String])
		token.show_state(PathTokenArt.look(status, locked_out), token.index == selected, team)
	if progress.owned != _owned:
		_owned = progress.owned
		_canvas.queue_redraw()


## Wheel zooms around the mouse; dragging with any button pans.
func _on_frame_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(_zoom * ZOOM_STEP, button.position)
			_frame.accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(_zoom / ZOOM_STEP, button.position)
			_frame.accept_event()
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & DRAG_BUTTONS:
		scroll_horizontal -= roundi(motion.relative.x)
		scroll_vertical -= roundi(motion.relative.y)


## Zooms so the board point under `at` (a point on the frame) stays under the mouse.
func _zoom_at(zoom: float, at: Vector2) -> void:
	var on_board: Vector2 = (at - _canvas.position) / _zoom
	var on_screen: Vector2 = at - Vector2(scroll_horizontal, scroll_vertical)
	_set_zoom(zoom)
	var scroll: Vector2 = on_board * _zoom + _canvas.position - on_screen
	_scroll_to.call_deferred(scroll)


func _set_zoom(zoom: float) -> void:
	_zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	_canvas.scale = Vector2.ONE * _zoom
	_frame.custom_minimum_size = _canvas.size * _zoom
	_place_canvas()


func _scroll_to(scroll: Vector2) -> void:
	scroll_horizontal = roundi(scroll.x)
	scroll_vertical = roundi(scroll.y)


## Centred while the board is smaller than the view.
func _place_canvas() -> void:
	_canvas.position = ((_frame.size - _canvas.size * _zoom) / 2.0).max(Vector2.ZERO)


func _draw_board() -> void:
	for i in _tree.nodes.size():
		var path_node: PathNode = _tree.node(i)
		if path_node == null:
			continue
		for needed in path_node.requires:
			var from: int = _tree.index_of(needed)
			if from >= 0:
				var open: bool = PathTree.owns(_owned, from)
				var colour: Color = LINE_OPEN if open else LINE_SHUT
				_canvas.draw_line(spot(_tree, from), spot(_tree, i), colour, LINE_WIDTH, true)
		for rival in _tree.rivals(i):
			if rival > i:
				_draw_chain(spot(_tree, i), spot(_tree, rival))
	for branch in _tree.branches():
		_draw_banner(branch)


## Two nodes that lock each other out: a red dashed line broken by a cross.
func _draw_chain(from: Vector2, to: Vector2) -> void:
	var red: Color = PathTokenArt.COLOURS[PathTokenArt.Look.LOCKED_OUT]
	_canvas.draw_dashed_line(from, to, Color(red, 0.85), LINE_WIDTH, 8.0)
	var middle: Vector2 = (from + to) / 2.0
	var reach := Vector2(7, 7)
	var flip := Vector2(7, -7)
	_canvas.draw_line(middle - reach, middle + reach, red, LINE_WIDTH, true)
	_canvas.draw_line(middle - flip, middle + flip, red, LINE_WIDTH, true)


## The branch's name over its highest node, centred over all of its nodes.
func _draw_banner(branch: String) -> void:
	var left: float = INF
	var right: float = -INF
	var top: float = INF
	for i in _tree.nodes.size():
		if _tree.node(i) != null and _tree.node(i).branch == branch:
			var at: Vector2 = spot(_tree, i)
			left = minf(left, at.x)
			right = maxf(right, at.x)
			top = minf(top, at.y)
	var baseline: float = top - PathNodeToken.CENTRE.y - 10.0
	var text: String = branch.to_upper()
	PathTokenArt.draw_centred(
		_canvas, text, (left + right) / 2.0, baseline, BANNER_SIZE, HudMenu.GOLD
	)
