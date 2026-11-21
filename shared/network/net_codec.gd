class_name NetCodec
extends RefCounted
## Small helpers for writing common types to network buffers.


static func put_vector2(buffer: StreamPeerBuffer, value: Vector2) -> void:
	buffer.put_float(value.x)
	buffer.put_float(value.y)


static func get_vector2(buffer: StreamPeerBuffer) -> Vector2:
	return Vector2(buffer.get_float(), buffer.get_float())


static func buffer_from(data: PackedByteArray) -> StreamPeerBuffer:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	return buffer
