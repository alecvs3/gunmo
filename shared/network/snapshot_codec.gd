class_name SnapshotCodec
extends RefCounted
## Packs entity states into snapshot packets of at most max_bytes each, and unpacks them.
## Packet: u32 tick, u16 count, then per entity: u32 net id, u8 kind, u16 size, state bytes.
## Each packet stands alone, so losing one part of a big snapshot only loses those entities.
## An entity whose kind is unknown or whose size doesn't match is skipped, never misread.

const HEADER_BYTES: int = 6
const ENTRY_HEADER_BYTES: int = 7


class Entry:
	var net_id: int = 0
	var kind: int = 0
	var state: NetState = null

	func _init(id: int = 0, entity_kind: int = 0, entity_state: NetState = null) -> void:
		net_id = id
		kind = entity_kind
		state = entity_state


## Always returns at least one packet (an empty snapshot still keeps clients' clocks in sync).
static func encode(tick: int, entries: Array[Entry], max_bytes: int) -> Array[PackedByteArray]:
	var packets: Array[PackedByteArray] = []
	var body := StreamPeerBuffer.new()
	var count: int = 0
	for entry in entries:
		var payload := StreamPeerBuffer.new()
		entry.state.encode(payload)
		var entry_bytes: int = ENTRY_HEADER_BYTES + payload.data_array.size()
		if count > 0 and HEADER_BYTES + body.data_array.size() + entry_bytes > max_bytes:
			packets.append(_finish(tick, count, body))
			body = StreamPeerBuffer.new()
			count = 0
		body.put_u32(entry.net_id)
		body.put_u8(entry.kind)
		body.put_u16(payload.data_array.size())
		body.put_data(payload.data_array)
		count += 1
	if count > 0 or packets.is_empty():
		packets.append(_finish(tick, count, body))
	return packets


## Returns {"tick": int, "entries": Array[Entry]}, or {} if the packet is malformed.
static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < HEADER_BYTES:
		return {}
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(data)
	var tick: int = buffer.get_u32()
	var count: int = buffer.get_u16()
	var entries: Array[Entry] = []
	for i in count:
		if buffer.get_available_bytes() < ENTRY_HEADER_BYTES:
			break
		var net_id: int = buffer.get_u32()
		var kind: int = buffer.get_u8()
		var size: int = buffer.get_u16()
		if buffer.get_available_bytes() < size:
			break
		var bytes: PackedByteArray = buffer.get_data(size)[1]
		var state: NetState = NetKinds.make_state(kind)
		if state != null and state.byte_size() == size:
			state.decode(NetCodec.buffer_from(bytes))
			entries.append(Entry.new(net_id, kind, state))
	return {"tick": tick, "entries": entries}


static func _finish(tick: int, count: int, body: StreamPeerBuffer) -> PackedByteArray:
	var packet := StreamPeerBuffer.new()
	packet.put_u32(tick)
	packet.put_u16(count)
	packet.put_data(body.data_array)
	return packet.data_array
