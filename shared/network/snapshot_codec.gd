class_name SnapshotCodec
extends RefCounted
## Packs entity states into snapshot packets of at most max_bytes each, and unpacks them.
## Packet: u32 tick, u16 count, then per entity: u16 net id, u8 kind (bit 7 set = the state's
## short public form), u8 size, state bytes.
## Each packet stands alone, so losing one part of a big snapshot only loses those entities.
## An entity whose kind is unknown or whose size doesn't match is skipped, never misread.

const HEADER_BYTES: int = 6
const ENTRY_HEADER_BYTES: int = 4
## Set in the kind byte when the state is in its public form (NetState.encode_public).
const PUBLIC_FLAG: int = 0x80
## Net ids wrap at this (they fit the u16 header).
const MAX_NET_ID: int = 65535


class Entry:
	var net_id: int = 0
	var kind: int = 0
	var state: NetState = null
	## The short form, for peers that only watch this entity.
	var public: bool = false
	## Already-encoded state bytes (the host encodes each state once per form); empty =
	## encode `state` when packing.
	var payload := PackedByteArray()

	func _init(
		id: int = 0, entity_kind: int = 0, entity_state: NetState = null, short: bool = false
	) -> void:
		net_id = id
		kind = entity_kind
		state = entity_state
		public = short

	func bytes() -> PackedByteArray:
		if not payload.is_empty():
			return payload
		var buffer := StreamPeerBuffer.new()
		if public:
			state.encode_public(buffer)
		else:
			state.encode(buffer)
		return buffer.data_array


## Always returns at least one packet (an empty snapshot still keeps clients' clocks in sync).
static func encode(tick: int, entries: Array[Entry], max_bytes: int) -> Array[PackedByteArray]:
	var packets: Array[PackedByteArray] = []
	var body := StreamPeerBuffer.new()
	var count: int = 0
	for entry in entries:
		var payload: PackedByteArray = entry.bytes()
		var entry_bytes: int = ENTRY_HEADER_BYTES + payload.size()
		if count > 0 and HEADER_BYTES + body.data_array.size() + entry_bytes > max_bytes:
			packets.append(_finish(tick, count, body))
			body = StreamPeerBuffer.new()
			count = 0
		body.put_u16(entry.net_id)
		body.put_u8(entry.kind | (PUBLIC_FLAG if entry.public else 0))
		body.put_u8(payload.size())
		body.put_data(payload)
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
		var net_id: int = buffer.get_u16()
		var kind_byte: int = buffer.get_u8()
		var size: int = buffer.get_u8()
		if buffer.get_available_bytes() < size:
			break
		var bytes: PackedByteArray = buffer.get_data(size)[1]
		var entry: Entry = _read_entry(net_id, kind_byte, bytes)
		if entry != null:
			entries.append(entry)
	return {"tick": tick, "entries": entries}


static func _read_entry(net_id: int, kind_byte: int, bytes: PackedByteArray) -> Entry:
	var public: bool = kind_byte & PUBLIC_FLAG != 0
	var kind: int = kind_byte & ~PUBLIC_FLAG
	var state: NetState = NetKinds.make_state(kind)
	if state == null:
		return null
	var expected: int = state.public_byte_size() if public else state.byte_size()
	if expected != bytes.size():
		return null
	if public:
		state.decode_public(NetCodec.buffer_from(bytes))
	else:
		state.decode(NetCodec.buffer_from(bytes))
	return Entry.new(net_id, kind, state, public)


static func _finish(tick: int, count: int, body: StreamPeerBuffer) -> PackedByteArray:
	var packet := StreamPeerBuffer.new()
	packet.put_u32(tick)
	packet.put_u16(count)
	packet.put_data(body.data_array)
	return packet.data_array
