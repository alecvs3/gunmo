class_name NetState
extends RefCounted
## One entity's replicated state at one server tick. Each entity kind has a subclass that lists
## its fields, writes and reads them in a fixed binary layout, and says how two states blend.
## To add a replicated field: add it to the subclass (encode, decode, byte_size, copy) and bump
## Handshake.PROTOCOL so older builds are refused instead of misreading snapshots.


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
