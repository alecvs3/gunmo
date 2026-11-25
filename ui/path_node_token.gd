class_name PathNodeToken
extends Button
## One node on the Path board: its token (PathTokenArt), its name and cost underneath, and a
## dot per teammate who owns it. Pressing it selects it; the window's Take button asks for it.

const SIZE := Vector2(124, 108)
## Where the token's circle sits inside the button (the board lines meet here).
const CENTRE := Vector2(62, 36)
const RADIUS: float = 28.0
const TEAM_DOT: float = 5.0
const TEAM_COLOURS: Array[Color] = [
	Color(0.55, 0.45, 1, 1),
	Color(0.3, 0.8, 1, 1),
	Color(1, 0.55, 0.3, 1),
	Color(1, 0.4, 0.7, 1),
	Color(0.7, 1, 0.4, 1),
]

var index: int = -1
var _node: PathNode
var _look: int = -1
var _selected: bool = false
var _team: Array[String] = []


## "Team: Ana, Bot 2" for the teammates who own a node ("" when none do).
static func team_text(names: Array[String]) -> String:
	return "" if names.is_empty() else "Team: %s" % ", ".join(names)


## Each teammate keeps one colour on every node.
static func team_colour(player_name: String) -> Color:
	return TEAM_COLOURS[absi(player_name.hash()) % TEAM_COLOURS.size()]


func _init(node_index: int, path_node: PathNode) -> void:
	index = node_index
	_node = path_node
	name = "Token%d" % node_index
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = SIZE
	size = SIZE
	tooltip_text = path_node.description


func show_state(shown: PathTokenArt.Look, selected: bool, team: Array[String]) -> void:
	if shown == _look and selected == _selected and team == _team:
		return
	_look = shown
	_selected = selected
	_team = team
	var owners: String = team_text(team)
	tooltip_text = _node.description + ("" if owners.is_empty() else "\n" + owners)
	queue_redraw()


func _draw() -> void:
	if _look < 0:
		return
	var shown := _look as PathTokenArt.Look
	PathTokenArt.draw(self, CENTRE, RADIUS, _node, shown, _selected)
	var dim: bool = PathTokenArt.is_dim(shown)
	var title := Color(PathTokenArt.COLOURS[shown], 0.7) if dim else PathTokenArt.COLOURS[shown]
	var below: float = CENTRE.y + RADIUS
	var title_text: String = _node.display_name.to_upper()
	var cost: String = PathDetail.cores_text(_node.core_cost)
	_draw_plate(title_text, below)
	PathTokenArt.draw_centred(self, title_text, CENTRE.x, below + 20, 13, title)
	PathTokenArt.draw_centred(self, cost, CENTRE.x, below + 36, 12, HudMenu.MUTED)
	for i in _team.size():
		var dot := CENTRE + Vector2(RADIUS * 0.8 - i * (TEAM_DOT * 2.0 + 2.0), -RADIUS * 0.8)
		draw_circle(dot, TEAM_DOT + 1.5, PathTokenArt.FACE, true, -1.0, true)
		draw_circle(dot, TEAM_DOT, team_colour(_team[i]), true, -1.0, true)


## A dark plate behind the name and cost, so board lines running under them don't show.
func _draw_plate(title_text: String, top: float) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	width = minf(maxf(width, 48.0) + 10.0, SIZE.x)
	var plate := Rect2(CENTRE.x - width / 2.0, top + 5.0, width, 36.0)
	draw_rect(plate, Color(PathTokenArt.FACE, 0.92))
