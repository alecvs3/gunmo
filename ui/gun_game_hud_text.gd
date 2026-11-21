class_name GunGameHudText
extends RefCounted
## The Gun Game lines of the HUD and results screen, as pure functions so they are tested.


## "Gun 2 / 4 · Rifle"
static func title(state: MatchNetState, tier: int, weapon_name: String) -> String:
	return "Gun %d / %d · %s" % [tier + 1, state.ladder_length, weapon_name]


## "Kills 1 / 3", with a reminder on the last gun.
static func progress(state: MatchNetState, tier: int, tier_kills: int) -> String:
	var text: String = "Kills %d / %d" % [tier_kills, state.kills_needed(tier)]
	return text + " · last gun!" if tier >= state.ladder_length - 1 else text


## Who is ahead, from Scoreboard.rank()'s first row.
static func leader_line(ranked: Array[Dictionary], own_id: int) -> String:
	if ranked.is_empty():
		return ""
	var leader: Dictionary = ranked[0]
	if leader["id"] == own_id:
		return "You're in the lead"
	return "Leader: %s · gun %d" % [leader["name"], leader["tier"] + 1]


static func winner_title(winner_name: String, is_you: bool) -> String:
	return "You win!" if is_you else "%s wins!" % winner_name


static func tier_up_banner(weapon_name: String) -> String:
	return "Next gun: %s" % weapon_name
