class_name PathNodeCard
extends Button
## One node in the Path window: its name, tier and Core cost, and whether you own it, can take
## it now, or not yet (and which teammates own it). Pressing it selects it; the window's Take
## button asks for it.

const GOLD := Color(1, 0.85, 0.35, 1)
const GREEN := Color(0.45, 0.85, 0.5, 1)
const MUTED := Color(0.62, 0.65, 0.7, 1)

var index: int = -1


## "1 Core", "3 Cores".
static func cores_text(cores: int) -> String:
	return "%d Core" % cores if cores == 1 else "%d Cores" % cores


## The card's three lines: name, tier and cost, then its state ("Owned", "Available", or
## "Locked") and the teammates who own it.
static func card_text(path_node: PathNode, status: PathRules.Status, team: String) -> String:
	var state: String = ["Owned", "Available", "Locked"][status]
	var lines: String = (
		"%s\nTier %d · %s · %s"
		% [path_node.display_name, path_node.tier, cores_text(path_node.core_cost), state]
	)
	return lines if team.is_empty() else "%s\n%s" % [lines, team]


## "Team: Ana, Bot 2" for the teammates who own a node ("" when none do).
static func team_text(names: Array[String]) -> String:
	return "" if names.is_empty() else "Team: %s" % ", ".join(names)


func _init(node_index: int) -> void:
	index = node_index
	custom_minimum_size = Vector2(170, 0)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 13)


func show_state(
	path_node: PathNode, status: PathRules.Status, team: String, selected: bool
) -> void:
	text = card_text(path_node, status, team)
	tooltip_text = path_node.description
	var colour: Color = [GREEN, GOLD, MUTED][status]
	var fill := Color(colour, 0.28 if selected else 0.12)
	var border := Color(colour, 1.0 if selected else 0.45)
	for style in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(style, HudMenu.box(fill, border, 2 if selected else 1))
	add_theme_color_override(
		"font_color", MUTED if status == PathRules.Status.LOCKED else Color.WHITE
	)
