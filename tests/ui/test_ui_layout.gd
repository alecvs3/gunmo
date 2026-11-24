extends GutTest
## Every menu and HUD panel, laid out at the canvas sizes real windows produce, must keep its
## buttons, fields and text on screen and its controls from overlapping. The canvas (in UI
## units) is the window scaled by canvas_items stretch from the 1152x648 base, then divided by
## the UI scale: 16:9 at any resolution is 1152x648; 21:9 is wider, 4:3 is taller, and a large
## UI scale makes the canvas smaller.

const SIZES: Array[Vector2] = [
	Vector2(1152, 648),  ## 16:9, UI scale normal (720p, 1080p, 4K alike)
	Vector2(1536, 648),  ## 21:9 ultrawide
	Vector2(1152, 864),  ## 4:3
	Vector2(1152, 720),  ## 16:10
	Vector2(1355, 762),  ## 16:9, UI scale small
	Vector2(768, 432),  ## 16:9, UI scale huge (the smallest canvas)
]
const SCENES: Array[String] = [
	"res://ui/main_menu.tscn",
	"res://ui/game_menu.tscn",
	"res://ui/hud.tscn",
	"res://ui/scoreboard.tscn",
	"res://ui/shop_panel.tscn",
	"res://ui/pet_panel.tscn",
	"res://ui/results_screen.tscn",
	"res://ui/net_overlay.tscn",
]
## Slack for rounding (px).
const TOLERANCE: float = 1.0


func test_every_panel_fits_every_size() -> void:
	for path in SCENES:
		for canvas in SIZES:
			var problems: Array[String] = await _lay_out(path, canvas)
			assert_eq(problems, [] as Array[String], "%s at %s" % [path.get_file(), canvas])


## Shows the scene in a `canvas`-sized frame and lists what doesn't fit.
func _lay_out(path: String, canvas: Vector2) -> Array[String]:
	var frame := Control.new()  # stands in for Main's UI layer
	frame.size = canvas
	frame.clip_contents = true
	add_child_autofree(frame)
	var panel: Control = load(path).instantiate()
	frame.add_child(panel)
	panel.set_process(false)
	panel.show()
	for _i in 3:
		await get_tree().process_frame
	var problems: Array[String] = _check(panel, Rect2(Vector2.ZERO, canvas))
	frame.queue_free()
	return problems


func _check(panel: Control, screen: Rect2) -> Array[String]:
	var problems: Array[String] = []
	var controls: Array[Control] = _shown_controls(panel)
	var interactive: Array[Control] = []
	for control in controls:
		var rect: Rect2 = control.get_global_rect()
		if not screen.grow(TOLERANCE).encloses(rect):
			problems.append("%s off screen at %s" % [control.name, rect])
		if control is BaseButton or control is LineEdit or control is SpinBox:
			interactive.append(control)
	for i in interactive.size():
		for j in range(i + 1, interactive.size()):
			if _overlap(interactive[i], interactive[j]):
				problems.append("%s overlaps %s" % [interactive[i].name, interactive[j].name])
	return problems


## Controls that are drawn and have something to show.
func _shown_controls(root: Control) -> Array[Control]:
	var found: Array[Control] = []
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x < 1.0 or control.size.y < 1.0:
			continue
		if control is Label and (control as Label).text.is_empty():
			continue
		if _scrolled(control, root):
			continue
		if (
			control is Label
			or control is BaseButton
			or control is LineEdit
			or control is SpinBox
			or control is ScrollContainer
		):
			found.append(control)
	return found


## Inside a scroll area: reached by scrolling, so only the scroll area itself must fit.
func _scrolled(control: Control, root: Control) -> bool:
	var parent: Node = control.get_parent()
	while parent != null and parent != root:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


## One inside the other (a SpinBox's own LineEdit) is not an overlap.
func _overlap(a: Control, b: Control) -> bool:
	if a.is_ancestor_of(b) or b.is_ancestor_of(a):
		return false
	var shared: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
	return shared.size.x > TOLERANCE and shared.size.y > TOLERANCE
