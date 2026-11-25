class_name EconomyModel
extends RefCounted
## Credits and Cores a paper team earns for one wave, with the match's own rules: each enemy's
## bounty to its killer (split by kill share, TeamPower.kill_shares), the clear bonus and
## Interest to everyone standing, the early-call bonus, and Cores (PathRules). Amounts are
## averages: a player standing 85% of the time gets 85% of the clear bonus.


## Pays `players` for clearing `wave` (bounty `bounty`) with strength `team`. `called_early`:
## the team called the next wave early during this one.
static func pay_wave(
	players: Array[SimPlayer],
	team: TeamPower,
	bounty: int,
	wave: int,
	called_early: bool,
	settings: MatchSettings,
	model: ProgressionModel
) -> void:
	var shares: PackedFloat32Array = team.kill_shares(model.kill_share_power)
	var clear: int = settings.wave_clear_bonus + settings.wave_clear_bonus_per_wave * wave
	for i in players.size():
		var player: SimPlayer = players[i]
		var standing: float = PlayerPower.standing(player, model)
		player.earn(SimPlayer.BOUNTY, bounty * shares[i])
		player.earn(SimPlayer.CLEAR, clear * standing)
		if called_early:
			var seconds: float = settings.break_seconds
			var early: int = EarlyCall.bonus(roundi(model.early_call_alive), seconds, settings)
			player.earn(SimPlayer.EARLY, early * standing)
		var interest: int = Interest.amount(floori(player.credits), settings)
		player.earn(SimPlayer.INTEREST, interest * standing)


## Cores for clearing `wave` (and its boss, if it has one), the same for every player.
static func pay_cores(
	players: Array[SimPlayer], wave: int, boss: bool, settings: MatchSettings
) -> void:
	var solo: bool = players.size() == 1
	for player in players:
		player.path.cores += PathRules.wave_cores(settings, wave, solo)
		if boss:
			player.path.cores += PathRules.boss_cores(settings, player.path_tree, player.path)


## Whether a team that calls early calls during `wave` (the next wave must be allowed early).
static func calls_early(team: TeamSetup, wave: int, total: int, settings: MatchSettings) -> bool:
	return (
		team.calls_early
		and EarlyCall.can_call(true, wave, total, true, settings.early_call_last_wave)
	)
