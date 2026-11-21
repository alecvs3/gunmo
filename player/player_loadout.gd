class_name PlayerLoadout
extends Node
## What a player carries: its weapon (index into the ShopCatalog). It is applied to the
## player's components the same way on every peer, so the predicting owner always uses exactly
## the host's numbers. The host changes it; clients load it from snapshots.

@export var weapon: WeaponComponent
## Tinted with the weapon's color, so everyone can see what you carry.
@export var barrel: Polygon2D

var catalog: ShopCatalog = ShopCatalog.load_default()
var weapon_index: int = 0


func _ready() -> void:
	_apply_weapon()


## Host: switch weapons (full magazine).
func equip_weapon(index: int) -> void:
	if catalog.is_weapon_index(index):
		weapon_index = index
		_apply_weapon()


## Back to the starting weapon.
func reset() -> void:
	equip_weapon(0)


## Clients: take the host's loadout from a snapshot (only does work when it changed).
func load_state(index: int) -> void:
	if index != weapon_index and catalog.is_weapon_index(index):
		weapon_index = index
		_apply_weapon()


func current_weapon() -> WeaponData:
	return catalog.weapon(weapon_index)


func _apply_weapon() -> void:
	var data: WeaponData = current_weapon()
	weapon.equip(data)
	barrel.color = data.color
