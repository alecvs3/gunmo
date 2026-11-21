class_name PlayerInputSource
extends Node
## Owner only: turns keys and mouse into one InputCommand per physics tick, and points the gun
## at the mouse every rendered frame, so aiming never waits for the network.
## Set `scripted` to drive the player without live input (the smoke test does; bots can too).

## Closer than this to the player, the mouse doesn't change the aim (avoids spinning).
const MIN_AIM_DISTANCE: float = 4.0

@export var pivot: Node2D

## When set, used instead of the keyboard and mouse (its sequence and view tick are ignored).
var scripted: InputCommand = null

var _sequence: int = 0


func _process(_delta: float) -> void:
	pivot.rotation = current_aim()


func current_aim() -> float:
	if scripted != null:
		return scripted.aim
	var offset: Vector2 = _mouse_world_position() - pivot.global_position
	return offset.angle() if offset.length() > MIN_AIM_DISTANCE else pivot.rotation


## The command for this tick, numbered and stamped with the tick we are looking at.
func next_command() -> InputCommand:
	var command := InputCommand.new()
	if scripted != null:
		command.move = scripted.move
		command.aim = scripted.aim
		command.buttons = scripted.buttons
	else:
		_read_live_input(command)
	_sequence += 1
	command.sequence = _sequence
	command.view_tick = NetworkManager.clock.render_tick()
	return command.sanitized()


func _read_live_input(command: InputCommand) -> void:
	command.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	command.aim = current_aim()
	var over_menu: bool = get_viewport().gui_get_hovered_control() != null
	if Input.is_action_pressed("fire") and not over_menu:
		command.buttons |= InputCommand.FIRE
	if Input.is_action_pressed("reload"):
		command.buttons |= InputCommand.RELOAD


func _mouse_world_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
