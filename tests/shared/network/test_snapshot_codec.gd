extends GutTest


func _enemy(id: int, x: float) -> SnapshotCodec.Entry:
	var state := EnemyNetState.new()
	state.position = Vector2(x, x * 2.0)
	state.health = id * 3
	return SnapshotCodec.Entry.new(id, NetKinds.ENEMY, state)


func _player(id: int) -> SnapshotCodec.Entry:
	var state := PlayerNetState.new()
	state.position = Vector2(10, 20)
	state.last_command = 77
	state.health = 90
	return SnapshotCodec.Entry.new(id, NetKinds.PLAYER, state)


func test_round_trip() -> void:
	var entries: Array[SnapshotCodec.Entry] = [_player(1), _enemy(2, 5.5), _enemy(3, 7.0)]
	var packets: Array[PackedByteArray] = SnapshotCodec.encode(500, entries, 1100)
	assert_eq(packets.size(), 1)
	var snapshot: Dictionary = SnapshotCodec.decode(packets[0])
	assert_eq(snapshot["tick"], 500)
	var decoded: Array = snapshot["entries"]
	assert_eq(decoded.size(), 3)
	assert_eq((decoded[0].state as PlayerNetState).last_command, 77)
	assert_eq((decoded[1].state as EnemyNetState).position, Vector2(5.5, 11.0))
	assert_eq((decoded[2].state as EnemyNetState).health, 9)


func test_big_snapshots_split_into_packets_under_the_limit() -> void:
	var entries: Array[SnapshotCodec.Entry] = []
	for id in range(1, 201):
		entries.append(_enemy(id, id))
	var packets: Array[PackedByteArray] = SnapshotCodec.encode(9, entries, 400)
	assert_gt(packets.size(), 1)
	var total: int = 0
	for packet in packets:
		assert_lte(packet.size(), 400)
		var snapshot: Dictionary = SnapshotCodec.decode(packet)
		assert_eq(snapshot["tick"], 9, "every part carries the tick")
		total += (snapshot["entries"] as Array).size()
	assert_eq(total, 200)


func test_empty_snapshot_still_sent_for_clock_sync() -> void:
	var empty: Array[SnapshotCodec.Entry] = []
	var packets: Array[PackedByteArray] = SnapshotCodec.encode(42, empty, 1100)
	assert_eq(packets.size(), 1)
	assert_eq(SnapshotCodec.decode(packets[0])["tick"], 42)


func test_unknown_kind_and_bad_size_are_skipped() -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(7)
	buffer.put_u16(3)
	buffer.put_u32(1)
	buffer.put_u8(99)
	buffer.put_u16(2)
	buffer.put_data(PackedByteArray([0, 0]))
	buffer.put_u32(2)
	buffer.put_u8(NetKinds.ENEMY)
	buffer.put_u16(3)
	buffer.put_data(PackedByteArray([0, 0, 0]))
	var good := StreamPeerBuffer.new()
	(_enemy(3, 1.0).state as EnemyNetState).encode(good)
	buffer.put_u32(3)
	buffer.put_u8(NetKinds.ENEMY)
	buffer.put_u16(good.data_array.size())
	buffer.put_data(good.data_array)
	var decoded: Array = SnapshotCodec.decode(buffer.data_array)["entries"]
	assert_eq(decoded.size(), 1)
	assert_eq(decoded[0].net_id, 3)


func test_truncated_packet_is_safe() -> void:
	var entries: Array[SnapshotCodec.Entry] = [_enemy(1, 1.0), _enemy(2, 2.0)]
	var packet: PackedByteArray = SnapshotCodec.encode(1, entries, 1100)[0]
	var cut: PackedByteArray = packet.slice(0, packet.size() - 4)
	assert_eq((SnapshotCodec.decode(cut)["entries"] as Array).size(), 1)
	assert_eq(SnapshotCodec.decode(PackedByteArray([1, 2])), {})
