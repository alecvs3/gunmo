class_name Replicator
extends Node
## Keeps clients up to date with every NetEntity.
## Host: every snapshot_interval_ticks, after all simulation for the tick, captures every
## entity's state and sends the snapshot (split into packets that fit the MTU) to each client.
## Each state is encoded once per form: a client gets its own player in full (prediction needs
## every detail) and everything else in the short public form where there is one.
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
	var captured: Array[Dictionary] = _capture_all()
	stats.snapshot_bytes = 0
	for peer_id in multiplayer.get_peers():
		var packets: Array[PackedByteArray] = SnapshotCodec.encode(
			_clock.tick, _entries_for(peer_id, captured), config.max_snapshot_bytes
		)
		var sent: int = 0
		for packet in packets:
			sent += packet.size()
			_channel.send_snapshot(peer_id, packet)
		stats.snapshot_bytes = maxi(stats.snapshot_bytes, sent)


## Ids fit the snapshot's u16 header: they wrap, skipping 0 and ids still in use.
func allocate_id() -> int:
	for attempt in SnapshotCodec.MAX_NET_ID:
		var id: int = _next_id
		_next_id = _next_id % SnapshotCodec.MAX_NET_ID + 1
		if not _entities.has(id):
			return id
	push_error("Replicator: no free net id")
	return 0


func register(entity: NetEntity) -> void:
	_entities[entity.net_id] = entity


func unregister(entity: NetEntity) -> void:
	if _entities.get(entity.net_id) == entity:
		_entities.erase(entity.net_id)


func entity_count() -> int:
	return _entities.size()


func reset() -> void:
	_next_id = 1


## Every entity's state, encoded once in full and (if it has one) once in public form.
func _capture_all() -> Array[Dictionary]:
	var captured: Array[Dictionary] = []
	for entity: NetEntity in _entities.values():
		if entity.net_id == 0 or entity.kind == NetKinds.NONE:
			continue
		var state: NetState = entity.capture()
		var full := SnapshotCodec.Entry.new(entity.net_id, entity.kind, state)
		full.payload = full.bytes()
		var public: SnapshotCodec.Entry = null
		if state.has_public_form():
			public = SnapshotCodec.Entry.new(entity.net_id, entity.kind, state, true)
			public.payload = public.bytes()
		captured.append({"owner": entity.owner_peer, "full": full, "public": public})
	stats.snapshot_entities = captured.size()
	return captured


## What `peer_id` gets: its own entities in full, the rest in public form where there is one.
static func _entries_for(peer_id: int, captured: Array[Dictionary]) -> Array[SnapshotCodec.Entry]:
	var entries: Array[SnapshotCodec.Entry] = []
	for item in captured:
		var public: SnapshotCodec.Entry = item["public"]
		var own: bool = item["owner"] == peer_id
		entries.append(item["full"] if own or public == null else public)
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
	stats.snapshots_missed += _clock.observe_snapshot_arrival(tick, Time.get_ticks_usec() / 1e6)
	stats.newest_snapshot_tick = maxi(stats.newest_snapshot_tick, tick)
	for entry: SnapshotCodec.Entry in snapshot["entries"]:
		var entity: NetEntity = _entities.get(entry.net_id)
		if entity != null and entity.kind == entry.kind:
			entity.receive(tick, entry.state)
