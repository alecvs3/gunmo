class_name GunGameLadder
extends RefCounted
## The Gun Game ladder rules, pure so they are unit-tested: every gun needs kills_per_tier
## kills to move on, the last one final_tier_kills, and finishing the last gun wins.

enum Result { STAYED, ADVANCED, FINISHED }

var length: int = 1
var kills_per_tier: int = 1
var final_tier_kills: int = 1


func configure(ladder_length: int, per_tier: int, final_kills: int) -> void:
	length = maxi(ladder_length, 1)
	kills_per_tier = maxi(per_tier, 1)
	final_tier_kills = maxi(final_kills, 1)


func kills_needed(tier: int) -> int:
	return final_tier_kills if tier >= length - 1 else kills_per_tier


## One kill for `score`: counts it on the current tier and moves up when the tier is done.
func record_kill(score: ScoreComponent) -> Result:
	score.tier_kills += 1
	if score.tier_kills < kills_needed(score.tier):
		return Result.STAYED
	if score.tier >= length - 1:
		return Result.FINISHED
	score.tier += 1
	score.tier_kills = 0
	return Result.ADVANCED
