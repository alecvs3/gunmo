class_name EarlyCall
extends RefCounted
## "Call it early", as pure rules. Once a wave has spawned everything, the players may vote to
## start the next wave at once, on top of the enemies still alive. It pays a bonus (more for
## each enemy still alive and for the break skipped), but the shop only opens in breaks, so
## calling early means not shopping: an easy win in the first waves, a gamble later.


## Whether calling the next wave is allowed now.
static func can_call(active: bool, wave: int, total_waves: int, all_spawned: bool) -> bool:
	return active and all_spawned and wave < total_waves


## Whether the vote passes: everyone counted (bots vote with the humans, WaveFlow).
static func passes(votes: int, players: int) -> bool:
	return players > 0 and votes >= players


## Credits each standing player gets for calling early.
static func bonus(alive_enemies: int, break_seconds: float, settings: MatchSettings) -> int:
	return roundi(
		(
			alive_enemies * settings.early_call_bonus_per_enemy
			+ break_seconds * settings.early_call_bonus_per_second
		)
	)
