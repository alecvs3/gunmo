class_name PlayerNetSync
extends Node
## A player's part of the snapshot. Player forwards NetEntity's calls here:
##   capture   host: the player's state right now, as a PlayerNetState
##   show      other clients: put an (already interpolated) state on screen
##   restore   owner client: jump back to the host's verdict before PlayerPrediction replays
##             the unconfirmed commands
## Adding a networked field: PlayerNetState (and its public form if others need it), capture,
## then show and/or restore. tests/shared/network/test_net_state_fields.gd checks the round trip.

@export var player: Player
@export var pivot: Node2D
@export var health: HealthComponent
@export var weapon: WeaponComponent
@export var loadout: PlayerLoadout
@export var wallet: WalletComponent
@export var score: ScoreComponent
@export var knockback: KnockbackComponent


func capture() -> PlayerNetState:
	var state := PlayerNetState.new()
	state.position = player.position
	state.move_velocity = player.move_velocity
	state.knockback = knockback.velocity
	state.aim = player.aim
	state.health = health.current_health
	state.max_health = health.max_health
	state.ammo = weapon.ammo
	state.cooldown_left = weapon.cooldown_left
	state.reload_left = weapon.reload_left
	state.alive = player.is_alive
	state.protected = player.is_protected
	state.down_left = player.down_left
	state.revive_progress = player.revive_progress
	state.pet = loadout.pet_index + 1
	state.pet_tier = loadout.pet_tier
	state.team_id = player.team_id
	state.kills = score.kills
	state.deaths = score.deaths
	state.tier = score.tier
	state.tier_kills = score.tier_kills
	state.teleport_count = player.teleport_count
	state.last_command = player.last_command
	state.weapon_index = loadout.weapon_index
	state.upgrade_levels = loadout.levels.duplicate()
	state.credits = wallet.credits
	return state


## Other clients: show this (interpolated) state.
func show_state(state: PlayerNetState) -> void:
	player.position = state.position
	player.aim = state.aim
	pivot.rotation = state.aim
	loadout.load_state(state.weapon_index, state.upgrade_levels)
	health.max_health = maxi(state.max_health, 1)
	health.apply_replicated(state.health)
	wallet.apply_replicated(state.credits)
	weapon.ammo = state.ammo
	player.teleport_count = state.teleport_count
	player.is_alive = state.alive
	_apply_shared(state)


## Owner client: jump back to the host's state before replaying unconfirmed commands.
func restore(state: PlayerNetState) -> void:
	player.position = state.position
	player.move_velocity = state.move_velocity
	knockback.velocity = state.knockback
	player.aim = state.aim
	loadout.load_state(state.weapon_index, state.upgrade_levels)
	wallet.apply_replicated(state.credits)
	weapon.restore(state.ammo, state.cooldown_left, state.reload_left)
	health.apply_replicated(state.health)
	player.teleport_count = state.teleport_count
	player.last_command = state.last_command
	player.is_alive = state.alive
	_apply_shared(state)


## Clients: the parts of a snapshot every peer shows the same way.
func _apply_shared(state: PlayerNetState) -> void:
	player.is_protected = state.protected
	player.down_left = state.down_left
	player.revive_progress = state.revive_progress
	loadout.load_pet(state.pet, state.pet_tier)
	if player.team_id != state.team_id:
		player.team_id = state.team_id
	score.apply_replicated(state.kills, state.deaths, state.tier, state.tier_kills)
