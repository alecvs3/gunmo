class_name HudMenu
extends Control
## The base of every pop-up menu over the game (Shop, Pets, Path, ...), so they all look and
## behave the same. While the match says the shop is open (Waves: the lobby and between waves)
## each menu shows a gold "<key>: <name>" hint, stacked in the bottom right by `_hint_slot()`.
## The menu's key opens its see-through window; the key again, Esc or a click outside closes it.
## Only one menu is open at a time: opening one closes the others.
## A menu only fills in `_build_content()` and `_refresh()`; the hint, the dim, the window, the
## sounds and closing at a new phase live here.

const GROUP: StringName = &"hud_menus"
const GOLD := Color(1, 0.85, 0.35, 1)
const MUTED := Color(0.62, 0.65, 0.7, 1)
const HINT_FONT_SIZE: int = 18
const HINT_OUTLINE: int = 4
## Hint box height plus the gap to the next hint up (px).
const HINT_STEP: float = 32.0
const HINT_SIZE := Vector2(120, 28)
const EDGE: float = 16.0
const WINDOW_FILL := Color(0.08, 0.09, 0.11, 0.82)
const DIM_COLOR := Color(0, 0, 0, 0.4)

var _open: bool = false
var _shown: bool = false
var _phase: int = -1
var _sounds: SoundData = SoundData.load_default()
var _sound := SoundPlayback.new()
var _hint := Label.new()
var _dim := ColorRect.new()
var _window: PanelContainer


## A rounded box in the menus' style.
static func box(fill: Color, border: Color, width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(10.0)
	return style


## The window every menu sits in.
static func window_style() -> StyleBoxFlat:
	var style := box(WINDOW_FILL, Color(GOLD, 0.35), 1)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


## A wrapping label in one size and colour.
static func label(text: String, font_size: int, color: Color) -> Label:
	var made := Label.new()
	made.text = text
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	return made


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	add_to_group(GROUP)
	add_child(_sound)
	_build_dim()
	_build_window()
	_build_hint()
	_build_content(_window)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))


## Esc closes the menu before the game menu (which reads Esc in _unhandled_input) sees it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible and _shown:
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(_action()) and _open:
		if _shown:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	visible = NetworkManager.is_online() and _open
	_hint.visible = not any_shown(get_tree())
	_dim.visible = _shown
	_window.visible = _shown
	var player: Player = Player.find_local(get_tree())
	if _shown and player != null:
		_refresh(player)


## Whether any menu's window is open (hints hide while one is).
static func any_shown(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		if (node as HudMenu).is_shown():
			return true
	return false


func is_shown() -> bool:
	return _shown


## Opens this menu's window and closes every other menu's.
func open() -> void:
	for node in get_tree().get_nodes_in_group(GROUP):
		if node != self:
			(node as HudMenu)._shown = false
	_shown = true
	_sound.play(_sounds.shop_open)
	_on_opened(Player.find_local(get_tree()))


func close() -> void:
	_shown = false
	_sound.play(_sounds.shop_close)


## The input action that opens and closes this menu ("shop", "pets", ...).
func _action() -> StringName:
	return &""


## "B: Shop".
func _hint_text() -> String:
	return ""


## Where the hint sits: 0 is the bottom-right corner, 1 the line above, and so on.
func _hint_slot() -> int:
	return 0


## Builds what goes inside the window.
func _build_content(_into: PanelContainer) -> void:
	pass


## Shows the local player's state; called every frame while the window is open.
func _refresh(_player: Player) -> void:
	pass


## Called when the window opens (`player` may be null).
func _on_opened(_player: Player) -> void:
	pass


## A scene may supply its own window (with its content in the .tscn); otherwise one is made.
func _make_window() -> PanelContainer:
	return PanelContainer.new()


## A new lobby or break starts with the menu closed again (the hint shows).
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


func _build_dim() -> void:
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = DIM_COLOR
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	move_child(_dim, 0)


func _build_window() -> void:
	_window = _make_window()
	_window.anchor_left = 0.08
	_window.anchor_top = 0.07
	_window.anchor_right = 0.92
	_window.anchor_bottom = 0.93
	_window.offset_left = 0.0
	_window.offset_top = 0.0
	_window.offset_right = 0.0
	_window.offset_bottom = 0.0
	_window.add_theme_stylebox_override("panel", window_style())
	if _window.get_parent() == null:
		add_child(_window)


func _build_hint() -> void:
	_hint.text = _hint_text()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var bottom: float = -EDGE - HINT_STEP * _hint_slot()
	_hint.offset_right = -EDGE
	_hint.offset_left = -EDGE - HINT_SIZE.x
	_hint.offset_bottom = bottom
	_hint.offset_top = bottom - HINT_SIZE.y
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", HINT_OUTLINE)
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	add_child(_hint)


func _on_dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		close()
		_dim.accept_event()
