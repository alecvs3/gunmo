class_name OwnPlayerDrawing
extends Node
## Your own player only (on the host too): where its visuals are drawn relative to its body.
##   + the prediction's eased correction (PlayerPrediction.visual_error), so corrections never
##     snap on screen
##   + with PlayerData.draw_ahead, one tick of its current motion ahead. The engine draws the
##     body between the last two ticks (physics interpolation), up to a tick behind the
##     newest one; drawing it a tick of motion further shows the newest tick extended by the
##     same fraction instead, so movement looks about 8 ms fresher without any stutter.
## The camera follows the visuals, so it gets the same head start.

@export var body: Player
@export var visual: Node2D
@export var prediction: PlayerPrediction

var _previous: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _teleports: int = -1


## How far ahead to draw: the motion of the last tick, capped at `max_length` (a correction
## or a knockback spike shouldn't throw the drawing far off). Zero across a teleport.
static func lead(previous: Vector2, current: Vector2, max_length: float) -> Vector2:
	return (current - previous).limit_length(max_length)


func _ready() -> void:
	process_physics_priority = 40


## After the tick's simulation (and any replay after a correction).
func _physics_process(_delta: float) -> void:
	if body.teleport_count != _teleports:
		_teleports = body.teleport_count
		_previous = body.position
	else:
		_previous = _current
	_current = body.position


func _process(_delta: float) -> void:
	var offset: Vector2 = prediction.visual_error if prediction != null else Vector2.ZERO
	var data: PlayerData = body.player_data
	if data.draw_ahead and body.is_alive:
		var max_length: float = data.move_speed * NetClock.tick_delta() * 1.5
		offset += lead(_previous, _current, max_length)
	visual.position = offset
