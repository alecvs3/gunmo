class_name PlayerArchetype
extends Resource
## How well a kind of player plays, for the progression paper run (ProgressionRun): aim,
## time spent shooting, dodging, using counters, going down, and how they spend credits.
## Real values live in modes/waves/data/progression/*.tres.

enum Spending {
	## The buy that adds the most power per credit, until nothing affordable helps.
	GREEDY,
	## Greedy, but keeps enough credits to earn the most interest.
	SAVER,
	## The cheapest buy that helps at all (doesn't plan).
	CHEAPEST,
}

@export var display_name: String = ""
## Share of shots that hit.
@export_range(0.0, 1.0) var accuracy: float = 0.6
## Share of a wave spent shooting (not running, reviving or reloading by hand).
@export_range(0.0, 1.0) var uptime: float = 0.85
## Share of incoming shots avoided (melee avoids `ProgressionModel.melee_dodge` of this).
@export_range(0.0, 0.9) var dodge: float = 0.3
## Whether they buy guns for the next wave's forecast counter (0.5 and above) or ignore it.
@export_range(0.0, 1.0) var counter_skill: float = 0.5
## Chance of going down in a wave.
@export_range(0.0, 1.0) var down_chance: float = 0.15
@export var spending: Spending = Spending.GREEDY
