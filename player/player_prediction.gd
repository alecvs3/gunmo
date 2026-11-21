class_name PlayerPrediction
extends Node
## Owner client only: makes the local player react instantly.
## Every tick it simulates the new input command straight away, remembers it, and sends the
## latest few to the host. When the host's state for this player arrives, it rewinds to it,
## replays every command the host hasn't simulated yet, and eases any small difference out of
## the visuals over a few frames, so corrections are invisible. Big ones (teleports) snap.
## OwnPlayerDrawing draws the visuals visual_error away from the body.

@export var input_source: PlayerInputSource

var history := PredictionHistory.new()
## How far from the simulated position to draw while a correction is eased out.
var visual_error: Vector2 = Vector2.ZERO

var _pending_state: PlayerNetState = null


func _process(delta: float) -> void:
	var decay: float = NetworkManager.config.prediction_error_decay
	visual_error *= exp(-decay * delta)


## The newest authoritative state wins; it is applied at the start of the next tick.
func on_server_state(state: PlayerNetState) -> void:
	if _pending_state == null or state.last_command >= _pending_state.last_command:
		_pending_state = state


func run_tick(player: Player) -> void:
	if _pending_state != null:
		_reconcile(player, _pending_state)
		_pending_state = null
	var command: InputCommand = input_source.next_command()
	player.simulate(command, false)
	history.record(command)
	var redundancy: int = NetworkManager.config.command_redundancy
	NetworkManager.channel.send_commands(InputCommand.encode_batch(history.recent(redundancy)))
	NetworkManager.stats.unconfirmed_commands = history.size()


func _reconcile(player: Player, state: PlayerNetState) -> void:
	var predicted: Vector2 = player.position
	var teleported: bool = state.teleport_count != player.teleport_count
	history.acknowledge(state.last_command)
	player.restore_from_state(state)
	for command in history.pending():
		player.simulate(command, true)
	var error: Vector2 = predicted - player.position
	NetworkManager.stats.prediction_error = error.length()
	if teleported or error.length() > NetworkManager.config.prediction_snap_distance:
		visual_error = Vector2.ZERO
		player.reset_physics_interpolation()
	else:
		visual_error += error
