class_name WavePath
extends RefCounted
## Host: the Path's part of a Waves match, applied to the players' loadouts. Pays Cores (wave
## cleared, boss killed, the solo bonus), gives each player one step per break, and takes the
## nodes players ask for. The rules are PathRules; WaveMode only calls these.


## Every player in the match gets the Cores for clearing `wave` (standing or not).
static func pay_wave(players: Array[Player], settings: MatchSettings, wave: int) -> void:
	var cores: int = PathRules.wave_cores(settings, wave, _solo(players))
	for player in players:
		player.get_loadout().path.cores += cores


## A boss died: every player gets cores_per_boss plus their own Path's extra.
static func pay_boss(players: Array[Player], settings: MatchSettings) -> void:
	for player in players:
		var loadout: PlayerLoadout = player.get_loadout()
		loadout.path.cores += PathRules.boss_cores(settings, loadout.path_tree, loadout.path)


## A break began: everyone may take one step.
static func start_break(players: Array[Player]) -> void:
	for player in players:
		PathRules.start_break(player.get_loadout().path)


## Takes node `index` for `player` if the rules allow it; "" when taken, otherwise why not.
static func take(player: Player, index: int, in_break: bool) -> String:
	var loadout: PlayerLoadout = player.get_loadout()
	var problem: String = PathRules.check(loadout.path_tree, loadout.path, index, in_break)
	if problem.is_empty():
		loadout.take_path_node(index, in_break)
	return problem


static func _solo(players: Array[Player]) -> bool:
	var humans: int = 0
	for player in players:
		if not player.is_bot:
			humans += 1
	return PathRules.is_solo(humans, players.size() - humans)
