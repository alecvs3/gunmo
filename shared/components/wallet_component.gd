class_name WalletComponent
extends Node
## A player's credits. Only the host changes them (bounties, bonuses, purchases); clients
## show the host's number from snapshots.

var credits: int = 0


func set_credits(amount: int) -> void:
	if multiplayer.is_server():
		credits = maxi(amount, 0)


func add(amount: int) -> void:
	if multiplayer.is_server() and amount > 0:
		credits += amount


func can_afford(cost: int) -> bool:
	return cost <= credits


## Host: takes the cost if there is enough. Returns whether it did.
func spend(cost: int) -> bool:
	if not multiplayer.is_server() or cost < 0 or not can_afford(cost):
		return false
	credits -= cost
	return true


## Clients: show the host's value.
func apply_replicated(amount: int) -> void:
	credits = amount
