class_name WaveFlow
extends RefCounted
## The wave mode's rules as a pure state machine (no nodes, no networking), so every rule is
## unit-tested. WaveMode tells it the facts every tick and acts on the event it returns.
##
##   LOBBY --(everyone ready, or the first break ends)--> ACTIVE (wave 1)
##   ACTIVE --(all players down)--> DEFEAT
##   ACTIVE --(wave done; last wave)--> VICTORY
##   ACTIVE --(wave done)--> BREAK --(everyone ready, or the break ends)--> ACTIVE (next wave)
## The lobby timer only starts once there is a player. Victory and defeat wait for a restart.

enum Event { NONE, WAVE_STARTED, WAVE_CLEARED, VICTORY, DEFEAT }

var phase: int = GameMode.Phase.LOBBY
var wave: int = 0
var total_waves: int = 1
## Tick the current break ends on (-1 = no timer yet).
var phase_end_tick: float = -1.0

var _first_break_ticks: int = 0
var _break_ticks: int = 0


func configure(waves: int, first_break_seconds: float, break_seconds: float) -> void:
	total_waves = maxi(waves, 1)
	_first_break_ticks = roundi(first_break_seconds * NetClock.tick_rate())
	_break_ticks = roundi(break_seconds * NetClock.tick_rate())


func reset() -> void:
	phase = GameMode.Phase.LOBBY
	wave = 0
	phase_end_tick = -1.0


## The facts this tick: players in the match, how many are alive, how many are ready, and
## whether the current wave has nothing left (all spawned, all dead).
func update(now: int, players: int, living: int, ready: int, wave_done: bool) -> Event:
	match phase:
		GameMode.Phase.LOBBY, GameMode.Phase.BREAK:
			return _update_break(now, players, ready)
		GameMode.Phase.ACTIVE:
			return _update_wave(now, players, living, wave_done)
	return Event.NONE


func _update_break(now: int, players: int, ready: int) -> Event:
	if players == 0:
		return Event.NONE
	if phase_end_tick < 0.0:
		phase_end_tick = now + _first_break_ticks
	if ready < players and now < phase_end_tick:
		return Event.NONE
	wave += 1
	phase = GameMode.Phase.ACTIVE
	phase_end_tick = -1.0
	return Event.WAVE_STARTED


func _update_wave(now: int, players: int, living: int, wave_done: bool) -> Event:
	if players > 0 and living == 0:
		phase = GameMode.Phase.DEFEAT
		return Event.DEFEAT
	if not wave_done:
		return Event.NONE
	if wave >= total_waves:
		phase = GameMode.Phase.VICTORY
		return Event.VICTORY
	phase = GameMode.Phase.BREAK
	phase_end_tick = now + _break_ticks
	return Event.WAVE_CLEARED


## How many players count as ready: the humans who are, plus every bot once all humans are
## (and there is at least one human).
static func ready_with_bots(humans: int, humans_ready: int, bots: int) -> int:
	if humans > 0 and humans_ready >= humans:
		return humans_ready + bots
	return humans_ready
