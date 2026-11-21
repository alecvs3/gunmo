class_name InputCommand
extends RefCounted
## One tick of a player's input. The owner makes one per physics tick and sends the latest
## few to the host; the host simulates the player with exactly these, and the owner replays
## the unconfirmed ones after each correction (prediction). Bots will produce them too.

const FIRE: int = 1
const RELOAD: int = 2
const ALL_BUTTONS: int = FIRE | RELOAD
## u32 sequence, 2 x f32 move, f64 aim, u8 buttons, f64 view tick, f64 client tick.
const ENCODED_SIZE: int = 37
const MAX_PER_PACKET: int = 16

var sequence: int = 0
## Movement direction, length 0..1.
var move: Vector2 = Vector2.ZERO
## Aim angle in radians.
var aim: float = 0.0
var buttons: int = 0
## The server tick the owner was drawing when it made this command (for lag compensation).
var view_tick: float = 0.0
## The owner's estimate of the host's current tick when it made this command: where on the
## owner's own timeline this input happened (fair dodging, see TimelineHits).
var client_tick: float = 0.0


func has(button: int) -> bool:
	return buttons & button != 0


## A copy that is safe to simulate: finite numbers, move at most length 1, known buttons only.
## Commands come from clients, so the host never trusts them as they are.
func sanitized() -> InputCommand:
	var clean := InputCommand.new()
	clean.sequence = sequence
	clean.move = move.limit_length(1.0) if move.is_finite() else Vector2.ZERO
	clean.aim = wrapf(aim, -PI, PI) if is_finite(aim) else 0.0
	clean.buttons = buttons & ALL_BUTTONS
	clean.view_tick = view_tick if is_finite(view_tick) else 0.0
	clean.client_tick = client_tick if is_finite(client_tick) else 0.0
	return clean


static func encode_batch(commands: Array[InputCommand]) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	var count: int = mini(commands.size(), MAX_PER_PACKET)
	buffer.put_u8(count)
	for command in commands.slice(commands.size() - count):
		buffer.put_u32(command.sequence)
		buffer.put_float(command.move.x)
		buffer.put_float(command.move.y)
		buffer.put_double(command.aim)
		buffer.put_u8(command.buttons)
		buffer.put_double(command.view_tick)
		buffer.put_double(command.client_tick)
	return buffer.data_array


## Returns [] for anything malformed instead of reading garbage.
static func decode_batch(data: PackedByteArray) -> Array[InputCommand]:
	var commands: Array[InputCommand] = []
	if data.is_empty() or data.size() != 1 + data[0] * ENCODED_SIZE or data[0] > MAX_PER_PACKET:
		return commands
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	for i in buffer.get_u8():
		var command := InputCommand.new()
		command.sequence = buffer.get_u32()
		command.move = Vector2(buffer.get_float(), buffer.get_float())
		command.aim = buffer.get_double()
		command.buttons = buffer.get_u8()
		command.view_tick = buffer.get_double()
		command.client_tick = buffer.get_double()
		commands.append(command)
	return commands
