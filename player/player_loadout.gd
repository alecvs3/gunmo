class_name PlayerLoadout
extends Node
## What a player carries and has bought: its weapon (index into the ShopCatalog) and its
## upgrade levels. PlayerStats turns them into the numbers the components use, the same way on
## every peer, so the predicting owner always uses exactly the host's stats. The host changes
## the loadout; clients load it from snapshots.

@export var weapon: WeaponComponent
@export var health: HealthComponent
## Shows the weapon's pose and held model, so everyone can see what you carry.
@export var look: PlayerLook

var catalog: ShopCatalog = ShopCatalog.load_default()
var weapon_index: int = 0
## One level per catalog upgrade (fixed size, so it fits the snapshot).
var levels := PackedByteArray()
## The player's base data with upgrades applied (move speed, max health).
var effective_player: PlayerData

var _base_player: PlayerData


func _init() -> void:
	levels.resize(ShopCatalog.MAX_UPGRADES)


## Called by the player with its base data, before anything reads effective_player.
func configure(base_player: PlayerData) -> void:
	_base_player = base_player
	_apply(true)


## Host: switch weapons (full magazine; upgrades carry over).
func equip_weapon(index: int) -> void:
	if catalog.is_weapon_index(index):
		weapon_index = index
		_apply(true)


## Host: one more level of an upgrade. Returns false at the cap. More max health heals by the
## amount gained.
func add_level(upgrade_index: int) -> bool:
	if level(upgrade_index) >= max_level(upgrade_index):
		return false
	var old_max: int = health.max_health
	levels[upgrade_index] += 1
	_apply(false)
	health.heal(health.max_health - old_max)
	return true


## Back to the starting weapon with no upgrades.
func reset() -> void:
	weapon_index = 0
	levels.fill(0)
	_apply(true)


## Clients: take the host's loadout from a snapshot (only does work when it changed).
func load_state(index: int, state_levels: PackedByteArray) -> void:
	var weapon_changed: bool = index != weapon_index and catalog.is_weapon_index(index)
	if not weapon_changed and state_levels == levels:
		return
	weapon_index = index if weapon_changed else weapon_index
	levels = state_levels.duplicate()
	levels.resize(ShopCatalog.MAX_UPGRADES)
	_apply(weapon_changed)


func level(upgrade_index: int) -> int:
	return levels[upgrade_index] if upgrade_index >= 0 and upgrade_index < levels.size() else 0


func max_level(upgrade_index: int) -> int:
	if upgrade_index < 0 or upgrade_index >= catalog.upgrades.size():
		return 0
	return catalog.upgrades[upgrade_index].max_level


func current_weapon() -> WeaponData:
	return catalog.weapon(weapon_index)


func _apply(new_weapon: bool) -> void:
	var stats: WeaponData = PlayerStats.effective_weapon(current_weapon(), catalog, levels)
	if new_weapon:
		weapon.equip(stats)
	else:
		weapon.set_stats(stats)
	look.pose = stats.pose
	look.held_model = stats.held_model
	if _base_player != null:
		effective_player = PlayerStats.effective_player(_base_player, catalog, levels)
		health.max_health = effective_player.max_health
