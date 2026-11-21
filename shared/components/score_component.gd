class_name ScoreComponent
extends Node
## A player's match score: kills, deaths and, in Gun Game, which ladder tier it is on and how
## many kills it has on that tier. Only the game mode on the host changes it; clients show
## the host's numbers from snapshots (scoreboard, HUD).

var kills: int = 0
var deaths: int = 0
## Index on the Gun Game ladder (0 = first gun).
var tier: int = 0
## Kills scored with the current tier's gun.
var tier_kills: int = 0


func reset() -> void:
	kills = 0
	deaths = 0
	tier = 0
	tier_kills = 0


## Clients: the host's numbers from a snapshot.
func apply_replicated(new_kills: int, new_deaths: int, new_tier: int, new_tier_kills: int) -> void:
	kills = new_kills
	deaths = new_deaths
	tier = new_tier
	tier_kills = new_tier_kills
