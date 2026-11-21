class_name NetCodec
extends RefCounted
## Small helpers for writing common types to network buffers.

## A position in 2 x i16 quarter pixels (4 bytes instead of 8): exact to 0.25 px, within
## +/- POSITION_LIMIT px (clamped beyond). For interpolated things only, never for prediction.
const POSITION_LIMIT: float = 8191.75


static func put_vector2(buffer: StreamPeerBuffer, value: Vector2) -> void:
	buffer.put_float(value.x)
	buffer.put_float(value.y)


static func get_vector2(buffer: StreamPeerBuffer) -> Vector2:
	return Vector2(buffer.get_float(), buffer.get_float())


static func buffer_from(data: PackedByteArray) -> StreamPeerBuffer:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	return buffer


static func put_quarter_position(buffer: StreamPeerBuffer, value: Vector2) -> void:
	buffer.put_16(roundi(clampf(value.x, -POSITION_LIMIT, POSITION_LIMIT) * 4.0))
	buffer.put_16(roundi(clampf(value.y, -POSITION_LIMIT, POSITION_LIMIT) * 4.0))


static func get_quarter_position(buffer: StreamPeerBuffer) -> Vector2:
	return Vector2(buffer.get_16() / 4.0, buffer.get_16() / 4.0)
