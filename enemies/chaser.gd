class_name ChaserEnemy
extends CharacterBody2D
## One scene for every enemy type. It targets the nearest living player; its EnemyData decides
## the numbers (speed, health, color...) and the behaviours: where it walks (movement) and how
## it hurts players (attack).
## The AI runs only on the host; clients show its snapshots, interpolated (NetEntity).

## Where clients may load enemy data from (the path arrives from the host at spawn).
const DATA_FOLDER: String = "res://enemies/data/"
## Hitbox and shot team (enemies never hurt each other, except a Bomber's blast).
const TEAM: StringName = &"enemies"
## Walls, for line of sight.
const WORLD_MASK: int = 1
## Damage a Bomber deals itself when its fuse burns out: more than any health it can have.
const SELF_DESTRUCT_DAMAGE: int = 100000000
## Tint on top of its colour while slowed.
const FROSTED := Color(0.65, 0.85, 1.3)
## Half the side of its body's collision box in chaser.tscn, before body_scale (px).
const BODY_HALF_SIZE: float = 14.0
## How enemies push each other apart (they don't block each other).
const CROWD: EnemyCrowd = preload("res://enemies/behaviours/data/crowd.tres")

## How fast the sprite turns towards its facing (higher = snappier). Looks only.
@export_range(1.0, 60.0) var turn_rate: float = 12.0
## Set before the enemy enters the tree; its path is sent to clients with the spawn.
@export var enemy_data: EnemyData:
	set(value):
		enemy_data = value
		data_path = value.resource_path if value != null else ""

## Synced once at spawn, so clients play the same type.
var data_path: String = ""
## The wave's modifiers (ModifierCatalog bitmask); set before spawning, synced once.
var modifier_mask: int = 0
## Host: slowed and hexed by pets (EnemyStatus). Clients: the flags from the snapshot.
var status := EnemyStatus.new()

var _attack_cooldown_left: float = 0.0
## Host, fair contact: player hitbox -> the tick of that player's own timeline its last touch
## was judged on (only remote humans are judged that way).
var _judged_ticks: Dictionary = {}
var _shots_fired: int = 0
## Host: the boss phase it is in (always 0 for other enemies).
var _phase: int = 0
## Host: seconds left of a telegraphed attack's windup (0 = not winding up), and its length.
var _windup_left: float = 0.0
var _windup_total: float = 0.0
## Host: which way it aimed when the windup began (a Charger dashes this way).
var _windup_aim: Vector2 = Vector2.RIGHT
## Host: a wind-up volley's shots, built when its aim locked and sent to every peer ahead of
## time (LatencyPolicy.schedule_windup_shots); they leave at _locked_fire_tick.
var _locked_shots: Array[Shot] = []
var _locked_fire_tick: int = 0
## Host: a Charger's dash (ChargeAttack); idle for every other enemy.
var _dash := EnemyDash.new()
## Host: a Bomber already exploded (so its death doesn't pop a second blast).
var _detonated: bool = false
## Every peer: draws its type's look (null = it has none).
var _look_layer: EnemyLookLayer
## Every peer: the ring that shows a windup (the host's own, or from snapshots).
var _telegraph := EnemyTelegraph.new()
var _status_flags: int = 0
var _base_damage_taken: float = 1.0
var _repath_left: float = 0.0
var _speed: float = 0.0
var _regen_per_second: float = 0.0
var _regen_carry: float = 0.0
## Host: where it faces (walking direction plus any flinch).
var _facing := EnemyFacing.new()
## The angle the sprite turns towards: the host's own, or the latest from a snapshot.
var _facing_target: float = 0.0

@onready var _body: Sprite2D = $Body
@onready var _health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _contact_area: Area2D = $ContactArea
@onready var _agent: NavigationAgent2D = $NavigationAgent2D
@onready var _crowd_area: Area2D = $Crowd


## Pure: how far a `data` enemy's body reaches from its centre at most (its box's corner).
static func body_reach(data: EnemyData) -> float:
	return BODY_HALF_SIZE * data.body_scale * sqrt(2.0)


func _ready() -> void:
	if not multiplayer.is_server():
		_load_data_from_host()
	_apply_modifiers(ModifierCatalog.load_default().combined(modifier_mask))
	_knockback.configure(
		enemy_data.knockback_friction, enemy_data.knockback_bounce, enemy_data.knockback_taken
	)
	_scale_body(enemy_data.body_scale)
	add_child(_telegraph)
	_add_look()
	if enemy_data.is_boss():
		add_to_group(Groups.BOSSES)
	if not multiplayer.is_server():
		set_physics_process(false)
		_contact_area.monitoring = false
		_crowd_area.monitoring = false
		return
	_health.reset()
	_health.died.connect(_on_died)
	_health.damaged.connect(
		func(amount: int, source_id: int) -> void:
			EventBus.enemy_damaged.emit(self, amount, source_id)
	)
	add_to_group(Groups.ENEMIES)
	_facing.configure(enemy_data.flinch_degrees, enemy_data.flinch_recovery)
	if enemy_data.shield != null:
		hitbox().guard = _shield_blocks
	_knockback.pushed.connect(_facing.flinch_from)


func _physics_process(delta: float) -> void:
	_regenerate(delta)
	var now: int = NetworkManager.clock.tick
	_health.damage_taken_multiplier = (
		_base_damage_taken * status.damage_factor(now) * _dash.damage_factor()
	)
	_show_status(_status_flags_now(now))
	_phase = phase_index()
	if _dash.is_busy():
		_dash_step(delta)
		return
	var target: Node2D = _find_nearest_target()
	_move(target, delta)
	_attack(target, delta)


## Every peer turns the sprite smoothly towards the facing (where it walks, plus flinches).
## Not towards where it moves: a push would spin it around.
func _process(delta: float) -> void:
	var weight: float = 1.0 - exp(-turn_rate * delta)
	_body.rotation = lerp_angle(_body.rotation, _facing_target, weight)
	_telegraph.line_angle = _facing_target
	if _look_layer != null:
		_look_layer.windup = _telegraph.progress


func capture_net_state() -> NetState:
	var state := EnemyNetState.new()
	state.position = position
	state.health = _health.current_health
	state.facing = EnemyNetState.to_facing(_facing_target)
	state.telegraph = EnemyNetState.to_telegraph(_windup_left, _windup_total)
	state.status = _status_flags_now(NetworkManager.clock.tick)
	return state


func apply_net_state(state: NetState) -> void:
	var enemy_state := state as EnemyNetState
	position = enemy_state.position
	_health.apply_replicated(enemy_state.health)
	_facing_target = EnemyNetState.facing_angle(enemy_state.facing)
	_telegraph.progress = enemy_state.telegraph / float(EnemyNetState.TELEGRAPH_STEPS)
	_show_status(enemy_state.status)
	visible = true


## Host: the snapshot's status flags (pets' slow and hex, a Charger's stun).
func _status_flags_now(now: int) -> int:
	return status.flags(now) | (EnemyStatus.FLAG_STUNNED if _dash.is_stunned() else 0)


## Every peer: slowed enemies look frosty, hexed ones wear a purple mark, stunned ones stars.
func _show_status(flags: int) -> void:
	if flags == _status_flags:
		return
	_status_flags = flags
	_body.self_modulate = FROSTED if flags & EnemyStatus.FLAG_SLOWED else Color.WHITE
	_telegraph.hexed = flags & EnemyStatus.FLAG_HEXED != 0
	_telegraph.stunned = flags & EnemyStatus.FLAG_STUNNED != 0


func hitbox() -> HitboxComponent:
	return $HitboxComponent


## Share of its health left (0..1), on every peer (clients get health in snapshots).
func health_share() -> float:
	return float(_health.current_health) / maxf(_health.max_health, 1.0)


## A boss's phase from its health (the same on every peer); 0 for other enemies.
func phase_index() -> int:
	return BossPhase.index_for(enemy_data.phases, health_share())


func _move(target: Node2D, delta: float) -> void:
	var chase: Vector2 = Vector2.ZERO
	var rooted: bool = _is_rooted()
	if target != null and not rooted:
		var movement: EnemyMovement = enemy_data.movement_in(_phase)
		var goal: Vector2 = movement.goal(global_position, target.global_position)
		if global_position.distance_squared_to(goal) > 1.0:
			var slow: float = status.speed_factor(NetworkManager.clock.tick)
			chase = _direction_towards(goal, delta) * _speed * enemy_data.speed_in(_phase) * slow
	var crowd: Vector2 = Vector2.ZERO if rooted else _crowd_push()
	velocity = chase + _knockback.velocity + crowd
	move_and_slide()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)
	_turn(target, _windup_aim if rooted else chase, delta)
	_facing.step(delta)
	# While winding up it faces exactly where it will go (no flinch): the dash line is drawn
	# from this facing, so it never shows a direction the dash won't take.
	_facing_target = _windup_aim.angle() if rooted else _facing.angle()


## Host: it faces where it walks (`walking`); a shield-bearer instead turns slowly to face its
## target.
func _turn(target: Node2D, walking: Vector2, delta: float) -> void:
	var shield: EnemyShield = enemy_data.shield
	if shield != null and target != null:
		var towards: Vector2 = global_position.direction_to(target.global_position)
		_facing.turn_towards(towards, shield.turn_step(delta))
	else:
		_facing.walk_towards(walking)


## Host: its shield blocks a hit travelling along `incoming` from the front.
func _shield_blocks(incoming: Vector2) -> bool:
	return enemy_data.shield.blocks(_facing.angle(), incoming)


## Every peer: whether its shield would block a hit along `incoming` as it is drawn here (the
## facing from its snapshot). Looks only: a shooter's PC uses it so a shot it sees stopped by
## the shield doesn't flash as a hit (the host's own check decides).
func blocks_as_drawn(incoming: Vector2) -> bool:
	return enemy_data.shield != null and enemy_data.shield.blocks(_facing_target, incoming)


## Host: standing still while it winds up an attack that wants that (a Charger's dash), and
## from the moment a volley's aim locks until it fires (its shots leave from where it stands).
func _is_rooted() -> bool:
	if not _locked_shots.is_empty():
		return true
	return _windup_left > 0.0 and enemy_data.attack_in(_phase).stands_still_while_winding_up()


## Along the navigation path around obstacles. Straight at the target while there is no path
## (the baked map reaches the navigation server a few physics frames after the level starts).
func _direction_towards(target_position: Vector2, delta: float) -> Vector2:
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = enemy_data.repath_interval
		_agent.target_position = target_position
	var map: RID = _agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0 or _agent.is_navigation_finished():
		return global_position.direction_to(target_position)
	var next: Vector2 = _agent.get_next_path_position()
	if next.is_equal_approx(global_position):
		return global_position.direction_to(target_position)
	return global_position.direction_to(next)


func _find_nearest_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for candidate: Node2D in get_tree().get_nodes_in_group(Groups.LIVING_PLAYERS):
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


## A telegraphed attack winds up first (every peer sees the ring fill), then fires.
func _attack(target: Node2D, delta: float) -> void:
	var attack: EnemyAttack = enemy_data.attack_in(_phase)
	if _windup_left > 0.0 or not _locked_shots.is_empty():
		_wind_up(attack, target, delta)
		return
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if _attack_cooldown_left > 0.0:
		return
	var distance: float = INF
	if target != null:
		distance = global_position.distance_to(target.global_position)
	var can_see: bool = target != null
	if can_see and attack.needs_line_of_sight():
		can_see = _can_see(target)
	if not attack.wants_to_attack(_attack_cooldown_left, distance, can_see):
		return
	if attack.windup > 0.0:
		_windup_left = attack.windup
		_windup_total = attack.windup
		if target != null:
			_windup_aim = global_position.direction_to(target.global_position)
	elif attack.perform(self, target, _touching_hitboxes()):
		_attack_cooldown_left = attack.interval


## Host: one tick of a windup. A volley locks its aim near the end and fires the locked shots
## on their tick; any other attack performs when the windup runs out.
func _wind_up(attack: EnemyAttack, target: Node2D, delta: float) -> void:
	_windup_left = maxf(_windup_left - delta, 0.0)
	var policy: LatencyPolicy = NetworkManager.latency_policy
	var lock_now: bool = EnemyAttack.lock_left(_windup_left, policy.aim_lock_seconds) <= 0.0
	if _locked_shots.is_empty() and _windup_left > 0.0 and lock_now:
		if policy.schedule_windup_shots and attack.schedules_shots(policy.aim_lock_seconds):
			_lock_aim(attack, target)
	if not _locked_shots.is_empty():
		if NetworkManager.clock.tick >= _locked_fire_tick:
			_fire_locked_shots(attack)
	elif _windup_left <= 0.0:
		_attack_cooldown_left = attack.interval
		attack.perform(self, target, _touching_hitboxes())
	_telegraph.progress = (
		EnemyNetState.to_telegraph(_windup_left, _windup_total)
		/ float(EnemyNetState.TELEGRAPH_STEPS)
	)


## Host: build the volley now and tell every peer, so its bullets reach them before they leave.
func _lock_aim(attack: EnemyAttack, target: Node2D) -> void:
	_locked_fire_tick = NetworkManager.clock.tick + ceili(_windup_left * NetClock.tick_rate())
	_locked_shots = attack.build_shots(self, target, _locked_fire_tick)
	if not _locked_shots.is_empty():
		EventBus.shots_scheduled.emit(_locked_shots)


func _fire_locked_shots(attack: EnemyAttack) -> void:
	for shot in _locked_shots:
		EventBus.shot_fired.emit(shot)
	_locked_shots.clear()
	_windup_left = 0.0
	_attack_cooldown_left = attack.interval


## Host: leaving before a locked volley fired (died, or the match reset): its shots never leave.
func _exit_tree() -> void:
	if not _locked_shots.is_empty():
		EventBus.shots_cancelled.emit(_locked_shots)
		_locked_shots.clear()


## Host: a ChargeAttack's windup is over: dash the way it aimed when the warning began.
func start_dash(attack: ChargeAttack) -> void:
	_dash.start(attack, _windup_aim)


## Host: a BlastAttack's fuse burned out: blast everyone around it, then die (no bounty).
func detonate(attack: BlastAttack) -> void:
	_detonated = true
	attack.blast(global_position, hitbox(), true, 0)
	_health.take_damage(SELF_DESTRUCT_DAMAGE)


## Host: a dash goes straight on, hurts the players it reaches and stuns it on walls.
func _dash_step(delta: float) -> void:
	velocity = _dash.velocity() + _knockback.velocity
	move_and_slide()
	if _dash.is_dashing():
		_dash_into_walls()
		_dash_into_players()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)
	_dash.step(delta)
	_facing.walk_towards(_dash.direction)
	_facing.step(delta)
	_facing_target = _facing.angle()


## Host: running head-on into a wall (not another enemy) stuns it.
func _dash_into_walls() -> void:
	for index in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(index)
		var layer: int = PhysicsServer2D.body_get_collision_layer(collision.get_collider_rid())
		if layer & WORLD_MASK and _dash.hit_wall(collision.get_normal()):
			return


## Host: the players it touches take the hit, and the dash ends.
func _dash_into_players() -> void:
	var touching: Array[HitboxComponent] = _touching_hitboxes()
	if touching.is_empty():
		return
	var attack: ChargeAttack = _dash.attack
	for hitbox in touching:
		var away: Vector2 = global_position.direction_to(hitbox.center())
		hitbox.hit(attack.damage, 0, away * attack.knockback)
		EventBus.contact_hit.emit(self, hitbox)
	_dash.hit_player()


## The id its shots carry (negative: enemy bullets get fair dodging, see Shot).
func shooter_id() -> int:
	return Shot.enemy_shooter_id($NetEntity.net_id)


func next_shot_id() -> int:
	_shots_fired += 1
	return _shots_fired


## No wall between it and the target.
func _can_see(target: Node2D) -> bool:
	if target == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, WORLD_MASK
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Bosses are bigger: hitbox, touch area and body grow with body_scale (every peer).
func _scale_body(factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	$HitboxComponent.scale_size(factor)
	$HitboxComponent/CollisionShape2D.scale = Vector2.ONE * factor
	$ContactArea/CollisionShape2D.scale = Vector2.ONE * factor
	$Crowd/CollisionShape2D.scale = Vector2.ONE * factor
	$CollisionShape2D.scale = Vector2.ONE * factor
	_telegraph.radius *= factor


## Host: the push (px/s) from the enemies it overlaps (EnemyCrowd). Not while it stands still
## for an attack (a locked volley leaves from where it stands).
func _crowd_push() -> Vector2:
	var spots: Array[Vector2] = []
	var scales: Array[float] = []
	for body in _crowd_area.get_overlapping_bodies():
		var other := body as ChaserEnemy
		if other != null and other != self:
			spots.append(other.global_position)
			scales.append(other.enemy_data.body_scale)
	return CROWD.push(global_position, enemy_data.body_scale, spots, scales, get_instance_id())


## Every peer: its type's extra shapes on the sprite, and a Charger's dash line length.
func _add_look() -> void:
	var charge := enemy_data.attack as ChargeAttack
	if charge != null:
		_telegraph.line_length = charge.dash_distance
	var bomb := enemy_data.attack as BlastAttack
	if bomb != null:
		_telegraph.blast_radius = bomb.radius
	if enemy_data.look == null:
		return
	_look_layer = EnemyLookLayer.new()
	_look_layer.look = enemy_data.look
	_look_layer.follow = _body
	add_child(_look_layer)


## Host: the tick of the victim's own timeline its last touch on `hitbox` was judged on, or -1
## (not judged on their view: the host's own player, a bot, or fair contact off).
func judged_tick(hitbox: HitboxComponent) -> int:
	return _judged_ticks.get(hitbox, -1)


## The player hitboxes it touches. With the mode's LatencyPolicy.fair_contact on, a remote human
## is touched only if, where they saw this enemy, it touched where their own inputs put them
## (ContactJudge); everyone else (the host's own player, bots) by the contact area's overlap.
func _touching_hitboxes() -> Array[HitboxComponent]:
	_judged_ticks.clear()
	var overlapping: Array[HitboxComponent] = []
	for area in _contact_area.get_overlapping_areas():
		var hitbox := area as HitboxComponent
		if hitbox != null:
			overlapping.append(hitbox)
	if not NetworkManager.latency_policy.fair_contact:
		return overlapping
	var touching: Array[HitboxComponent] = []
	var remote: Array[Player] = _remote_humans()
	for hitbox in overlapping:
		if remote.all(func(player: Player) -> bool: return player.get_hitbox() != hitbox):
			touching.append(hitbox)
	for player in remote:
		if _touches_as_seen(player):
			touching.append(player.get_hitbox())
	return touching


## Living players whose inputs carry their own timeline (remote humans).
func _remote_humans() -> Array[Player]:
	var found: Array[Player] = []
	for node in get_tree().get_nodes_in_group(Groups.LIVING_PLAYERS):
		var player := node as Player
		if player != null and player.timeline != null:
			found.append(player)
	return found


## Fair contact for one remote human: at their newest input, where they saw this enemy.
func _touches_as_seen(player: Player) -> bool:
	var stamp: int = player.timeline.newest_tick()
	if stamp < 0:
		return false
	var them: PositionHistory.Place = player.timeline.history.sample(stamp)
	if not them.hittable:
		return false
	var lag: LagCompensator = NetworkManager.lag_compensator
	var me: PositionHistory.Place = lag.position_at(
		$HitboxComponent, player.timeline.view_at(stamp)
	)
	var radius: float = player.get_hitbox().circle_radius()
	if not ContactJudge.touches(me.position, _contact_half(), them.position, radius):
		return false
	_judged_ticks[player.get_hitbox()] = stamp
	return true


## Half the size of the contact square, scaled like the body (_scale_body).
func _contact_half() -> Vector2:
	var shape := $ContactArea/CollisionShape2D as CollisionShape2D
	return (shape.shape as RectangleShape2D).size * shape.scale / 2.0


func _on_died(killer_peer_id: int) -> void:
	EventBus.enemy_killed.emit(self, killer_peer_id)
	_pop(killer_peer_id)
	if enemy_data.split_into != null and enemy_data.split_count > 0:
		EventBus.enemy_split.emit(self, enemy_data.split_into, enemy_data.split_count)
	remove_from_group(Groups.ENEMIES)
	queue_free()


## Host: a Bomber shot before its fuse burned out still pops, but only enemies get hurt
## (its killer gets their bounties).
func _pop(killer_peer_id: int) -> void:
	var bomb := enemy_data.attack_in(_phase) as BlastAttack
	if bomb == null or _detonated:
		return
	_detonated = true
	bomb.blast(global_position, hitbox(), false, killer_peer_id)


## Where it is drawn (the host draws remote things a little back, see DisplayDelay).
func drawn_position() -> Vector2:
	return _body.global_position


## The colour its death burst uses: its body tint (wave modifiers included).
func burst_color() -> Color:
	return _body.modulate


## Host: whether it has lost health (support enemies heal these).
func is_wounded() -> bool:
	return _health.current_health < _health.max_health


## Host: heal `amount` points (support enemies), less if it resists healing (heal_received).
func heal(amount: int) -> void:
	_health.heal(enemy_data.received_heal(amount))


func max_health() -> int:
	return _health.max_health


## The wave's modifiers change health, speed, armor, traits and regeneration, and tint the enemy
## so players can read the wave (every peer tints; only the host's numbers matter).
func _apply_modifiers(combined: WaveModifier) -> void:
	var tinted: Color = enemy_data.color
	if modifier_mask != 0:
		tinted = enemy_data.color.lerp(combined.color, 0.45)
	_body.modulate = tinted
	_body.scale = Vector2.ONE * enemy_data.visual_scale
	_health.max_health = combined.scaled_health(enemy_data.max_health)
	_base_damage_taken = combined.damage_taken_multiplier * enemy_data.damage_taken
	_health.damage_taken_multiplier = _base_damage_taken
	_health.type_multipliers = EnemyTrait.profile(enemy_data.traits + combined.adds_traits)
	_speed = enemy_data.move_speed * combined.speed_multiplier
	_regen_per_second = combined.regen_per_second * enemy_data.heal_received


## Host: heal a share of max health per second (whole points; the rest carries over).
func _regenerate(delta: float) -> void:
	if _regen_per_second <= 0.0 or _health.current_health >= _health.max_health:
		return
	_regen_carry += _regen_per_second * _health.max_health * delta
	var whole: int = floori(_regen_carry)
	if whole > 0:
		_regen_carry -= whole
		_health.heal(whole)


## Clients: the host told us which type this is; only enemy data files are accepted.
func _load_data_from_host() -> void:
	if not data_path.begins_with(DATA_FOLDER) or not ResourceLoader.exists(data_path):
		return
	var loaded := load(data_path) as EnemyData
	if loaded != null:
		enemy_data = loaded
