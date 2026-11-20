class_name PlayerInput
extends MultiplayerSynchronizer
## Reads input on the owning client only and syncs it to the host. Nothing else is sent:
## the host decides what the input actually does.

var move_direction: Vector2 = Vector2.ZERO
var aim_position: Vector2 = Vector2.ZERO
var fire_held: bool = false
var reload_held: bool = false


## Authority is set by Player._enter_tree(), which runs before this.
func _ready() -> void:
	set_process(is_multiplayer_authority())


func _process(_delta: float) -> void:
	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim_position = _mouse_world_position()
	fire_held = Input.is_action_pressed("fire") and get_viewport().gui_get_hovered_control() == null
	reload_held = Input.is_action_pressed("reload")


func _mouse_world_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
