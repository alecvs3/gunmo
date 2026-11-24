class_name PetPowers
extends Node
## Host only (Waves): runs the pets' abilities. WaveMode creates it and tells it when waves
## start and end; it listens to EventBus enemy_damaged itself. Each pet's rules are pure
## classes (HealerRules, ...) reading the pet's data; this node only gathers facts and applies
## the results (heals go through Player.heal, which the snapshot carries to everyone).

var _level: Level
## Damage the players dealt this wave, and the enemy health it planned (for Mending).
var _dealt: int = 0
var _wave_health: int = 0
## peer id -> true once this wave: Mending healed, Guardian saved. peer id -> Siphon healed.
var _mended: Dictionary = {}
var _guarded: Dictionary = {}
var _siphoned: Dictionary = {}
var _wizard: WizardPowers


func _init(level: Level) -> void:
	_level = level
	_wizard = WizardPowers.new(level)


## The Healer data and tier a player has (tier 0 = no Healer).
static func healer_of(player: Player) -> Array:
	if player == null:
		return [null, 0]
	var data := player.get_loadout().pet() as HealerData
	return [data, player.get_loadout().pet_tier if data != null else 0]


## DownedPlayers: how fast `reviver` revives, and the extra health their revive gives.
static func revive_speed(reviver: Player) -> float:
	var healer: Array = healer_of(reviver)
	return HealerRules.revive_speed(healer[0], healer[1]) if healer[0] != null else 1.0


static func revive_bonus(reviver: Player) -> float:
	var healer: Array = healer_of(reviver)
	return HealerRules.revive_bonus(healer[0], healer[1]) if healer[0] != null else 0.0


## A heal everyone sees.
static func show_heal(player: Player) -> void:
	PetEffects.broadcast(
		PetEffects.Kind.HEAL, PackedVector2Array([player.global_position]), 0.0, 0.7
	)


func _ready() -> void:
	EventBus.enemy_damaged.connect(_on_enemy_damaged)


func _physics_process(_delta: float) -> void:
	_wizard.tick(_level.players(), NetworkManager.clock.tick)


func on_wave_started(planned_health: int) -> void:
	_dealt = 0
	_wave_health = planned_health
	_mended.clear()
	_guarded.clear()
	_siphoned.clear()
	_wizard.clear()


## Wave's End: the strongest Healer on the team heals everyone standing (Healers don't stack).
func on_wave_cleared() -> void:
	var share: float = 0.0
	for player in _level.players():
		var healer: Array = healer_of(player)
		if healer[0] != null:
			share = maxf(share, HealerRules.wave_end_share(healer[0], healer[1]))
	if share <= 0.0:
		return
	for player in _level.players():
		if player.is_alive:
			player.heal(HealerRules.amount(share, player.max_health()))
			show_heal(player)


## Guardian: true if the player's Healer keeps them up this time (they stay at a share).
func save_from_going_down(player: Player) -> bool:
	var healer: Array = healer_of(player)
	if healer[0] == null or not HealerRules.guardian_saves(healer[1], _guarded.has(player.peer_id)):
		return false
	_guarded[player.peer_id] = true
	player.revive_here(healer[0].guardian_share)
	show_heal(player)
	return true


func _on_enemy_damaged(enemy: Node2D, amount: int, source_id: int) -> void:
	var source: Player = _level.player(source_id) if source_id != 0 else null
	if source == null:
		return
	_dealt += amount
	_siphon(source, amount)
	_wizard.on_hit(source, enemy as ChaserEnemy, amount, NetworkManager.clock.tick)
	var any_healer: HealerData = _healer_data_any()
	if any_healer != null and HealerRules.mending_ready(any_healer, _dealt, _wave_health):
		_mend_everyone()


func _siphon(player: Player, amount: int) -> void:
	var healer: Array = healer_of(player)
	if healer[0] == null or not player.is_alive:
		return
	var healed: int = _siphoned.get(player.peer_id, 0)
	var heal: int = HealerRules.siphon_heal(
		healer[0], healer[1], amount, healed, player.max_health()
	)
	if heal > 0:
		_siphoned[player.peer_id] = healed + heal
		player.heal(heal)


## Mending: every Healer owner who hasn't been mended this wave heals.
func _mend_everyone() -> void:
	for player in _level.players():
		var healer: Array = healer_of(player)
		if healer[0] == null or _mended.has(player.peer_id) or not player.is_alive:
			continue
		var share: float = HealerRules.mending_share(healer[0], healer[1])
		if share > 0.0:
			_mended[player.peer_id] = true
			player.heal(HealerRules.amount(share, player.max_health()))
			show_heal(player)


## Any Healer's data (they share the threshold), or null when nobody has a Healer.
func _healer_data_any() -> HealerData:
	for player in _level.players():
		var healer: Array = healer_of(player)
		if healer[0] != null:
			return healer[0]
	return null
