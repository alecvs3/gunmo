class_name ViewMask
extends Control
## Covers the world outside the fair view box (FairView) with bars, so every window shape sees
## the same amount of the map. Sits under the rest of the UI, which still uses the whole window.
## Only while this peer has a player of its own (not in the menu).

const COLOR := Color(0.04, 0.04, 0.05, 1.0)

var _box := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var player: Player = Player.find_local(get_tree())
	visible = player != null
	if player == null:
		return
	var box: Rect2 = FairView.box_on_screen(size, player.player_data.view_size)
	if not box.is_equal_approx(_box):
		_box = box
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, _box.position.y), COLOR)
	draw_rect(Rect2(0.0, _box.end.y, size.x, size.y - _box.end.y), COLOR)
	draw_rect(Rect2(0.0, _box.position.y, _box.position.x, _box.size.y), COLOR)
	draw_rect(Rect2(_box.end.x, _box.position.y, size.x - _box.end.x, _box.size.y), COLOR)
