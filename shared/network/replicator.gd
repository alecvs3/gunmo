class_name Replicator
extends Node
## Keeps clients up to date with every NetEntity.
## Host: every snapshot_interval_ticks, after all simulation for the tick, captures every
## entity's state and sends the snapshot (split into packets that fit the MTU) to each client.
## Clients: unpack snapshots, sync the clock, and hand each state to its entity.

var config: NetworkConfig
var stats: NetStats

var _channel: NetChannel
var _clock: NetClock
var _ping: PingTracker
var _entities: Dictionary = {}
var _next_id: int = 1


func setup(channel: NetChannel, clock: NetClock, ping: PingTracker) -> void:
	_channel = channel
	_clock = clock
	_ping = ping
	_channel.snapshot_received.connect(_on_snapshot_received)


## Runs after every other physics node, so snapshots carry the finished tick.
func _ready() -> void:
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or multiplayer.get_peers().is_empty():
		return
	if _clock.tick % config.snapshot_interval_ticks != 0:
		return
	var packets: Array[PackedByteArray] = SnapshotCodec.encode(
		_clock.tick, _capture_all(), config.max_snapshot_bytes
	)
	stats.snapshot_bytes = 0
	for packet in packets:
		stats.snapshot_bytes += packet.size()
		for peer_id in multiplayer.get_peers():
			_channel.send_snapshot(peer_id, packet)


func allocate_id() -> int:
	_next_id += 1
	return _next_id - 1


func register(entity: NetEntity) -> void:
	_entities[entity.net_id] = entity


func unregister(entity: NetEntity) -> void:
	if _entities.get(entity.net_id) == entity:
		_entities.erase(entity.net_id)


func entity_count() -> int:
	return _entities.size()


func reset() -> void:
	_next_id = 1


func _capture_all() -> Array[SnapshotCodec.Entry]:
	var entries: Array[SnapshotCodec.Entry] = []
	for entity: NetEntity in _entities.values():
		if entity.net_id != 0 and entity.kind != NetKinds.NONE:
			entries.append(SnapshotCodec.Entry.new(entity.net_id, entity.kind, entity.capture()))
	stats.snapshot_entities = entries.size()
	return entries


## Half the real round trip, plus the simulator's added delay (ENet can't see that one).
func _one_way_delay_seconds() -> float:
	return _ping.live_rtt_ms() / 2000.0 + _channel.simulator.latency_ms / 1000.0


func _on_snapshot_received(data: PackedByteArray) -> void:
	var snapshot: Dictionary = SnapshotCodec.decode(data)
	if snapshot.is_empty():
		return
	var tick: int = snapshot["tick"]
	_clock.observe_server_tick(tick, _one_way_delay_seconds())
	stats.newest_snapshot_tick = maxi(stats.newest_snapshot_tick, tick)
	for entry: SnapshotCodec.Entry in snapshot["entries"]:
		var entity: NetEntity = _entities.get(entry.net_id)
		if entity != null and entity.kind == entry.kind:
			entity.receive(tick, entry.state)
