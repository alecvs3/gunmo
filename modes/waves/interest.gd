class_name Interest
extends RefCounted
## Interest on held credits, as pure rules. After each clear bonus every standing player earns
## `interest_per_step` for every whole `interest_step` credits they hold, up to `interest_cap`
## (MatchSettings). Saving is a choice against spending: a bank of 500 pays 50 a wave.


## Credits a player holding `credits` earns this wave (0 when any setting is 0).
static func amount(credits: int, settings: MatchSettings) -> int:
	if credits <= 0 or settings.interest_step <= 0 or settings.interest_per_step <= 0:
		return 0
	var steps: int = floori(float(credits) / settings.interest_step)
	return mini(steps * settings.interest_per_step, settings.interest_cap)
