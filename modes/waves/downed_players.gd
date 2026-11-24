class_name DownedPlayers
extends RefCounted
## Host: the co-op players who are down right now. Each tick it asks ReviveRules what happens
## to each one (a teammate holding revive next to them, or the bleed-out timer) and tells the
## Player: revived where they lie, bled out, or still down (the timers go into its snapshot).

var _settings: MatchSettings
## peer id -> ReviveRules.Downed
var _downed: Dictionary = {}


func _init(settings: MatchSettings) -> void:
	_settings = settings


## Whether players go down at all (a bleed-out time is set).
func enabled() -> bool:
	return _settings.bleed_out_seconds > 0.0


func start(player: Player) -> void:
	player.go_down()
	_downed[player.peer_id] = ReviveRules.Downed.new(_settings.bleed_out_seconds)


func clear() -> void:
	_downed.clear()


func forget(peer_id: int) -> void:
	_downed.erase(peer_id)


## One tick for everyone down; `players` = everyone in the level.
func update(players: Array[Player], delta: float) -> void:
	for peer_id: int in _downed.keys():
		var player: Player = _find(players, peer_id)
		if player == null or not player.is_downed():
			_downed.erase(peer_id)
			continue
		var downed: ReviveRules.Downed = _downed[peer_id]
		var reviver: Player = _reviver(players, player)
		var speed: float = PetPowers.revive_speed(reviver)
		match ReviveRules.step(downed, delta * speed, reviver != null, _settings.revive_seconds):
			ReviveRules.Result.REVIVED:
				var share: float = _settings.revive_health_share + PetPowers.revive_bonus(reviver)
				player.revive_here(minf(share, 1.0))
				PetPowers.show_heal(player)
				_downed.erase(peer_id)
			ReviveRules.Result.BLED_OUT:
				player.bleed_out()
				_downed.erase(peer_id)
			_:
				player.down_left = ReviveRules.to_byte(
					downed.bleed_left / _settings.bleed_out_seconds
				)
				player.revive_progress = ReviveRules.to_byte(
					downed.progress / _settings.revive_seconds
				)


## A living teammate next to `downed`, holding revive (null = nobody).
func _reviver(players: Array[Player], downed: Player) -> Player:
	for player in players:
		if player == downed or not player.is_alive:
			continue
		if player.held_buttons & InputCommand.REVIVE == 0:
			continue
		var reach: float = _settings.revive_range
		if ReviveRules.in_range(player.global_position, downed.global_position, reach):
			return player
	return null


static func _find(players: Array[Player], peer_id: int) -> Player:
	for player in players:
		if player.peer_id == peer_id:
			return player
	return null
