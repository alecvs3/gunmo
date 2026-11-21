class_name NetState
extends RefCounted
## One entity's replicated state at one server tick. Each entity kind has a subclass that lists
## its fields, writes and reads them in a fixed binary layout, and says how two states blend.
## To add a replicated field: add it to the subclass (encode, decode, byte_size, copy, and the
## public form if others need it) and bump Handshake.PROTOCOL so older builds are refused
## instead of misreading snapshots. tests/shared/network/test_net_state_fields.gd checks it.
## A state may have a shorter public form for peers that only watch the entity (another
## player's private numbers go only to that player); by default the public form is the full one.


## Writes every field in a fixed order.
func encode(_buffer: StreamPeerBuffer) -> void:
	pass


## Reads the fields back in the same order.
func decode(_buffer: StreamPeerBuffer) -> void:
	pass


## Exact number of bytes encode() writes; snapshots with any other size are ignored.
func byte_size() -> int:
	return 0


## The state `weight` (0..1) of the way from this one to `to`. By default nothing blends and
## the nearer state wins; subclasses blend what can be blended (positions, angles).
func interpolated(to: NetState, weight: float) -> NetState:
	return self if weight < 0.5 else to


## Writes the fields peers who only watch this entity need (default: all of them).
func encode_public(buffer: StreamPeerBuffer) -> void:
	encode(buffer)


func decode_public(buffer: StreamPeerBuffer) -> void:
	decode(buffer)


func public_byte_size() -> int:
	return byte_size()


## True when the public form is shorter than the full one (the host then encodes both).
func has_public_form() -> bool:
	return public_byte_size() != byte_size()
