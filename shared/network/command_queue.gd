class_name CommandQueue
extends RefCounted
## Host side: one player's input commands waiting to be simulated, oldest first.
## Copies already seen (every packet repeats recent commands) are dropped. Each tick earns one
## command of budget, saved up to `budget_cap`, so a player whose packets came late catches up
## a little, but nobody is ever simulated faster than real time (no speed hacks).

var budget_cap: int = 4
var max_per_tick: int = 2
var max_pending: int = 16
## Highest sequence number accepted so far.
var last_received: int = -1

var _pending: Array[InputCommand] = []
var _budget: float = 0.0


func configure(config: NetworkConfig) -> void:
	budget_cap = config.command_budget
	max_per_tick = config.max_commands_per_tick
	max_pending = config.max_pending_commands


func push(commands: Array[InputCommand]) -> void:
	for command in commands:
		if command.sequence > last_received:
			_pending.append(command.sanitized())
			last_received = command.sequence
	while _pending.size() > max_pending:
		_pending.pop_front()


## The commands to simulate this tick (often one, sometimes none, at most max_per_tick).
func take_for_tick() -> Array[InputCommand]:
	_budget = minf(_budget + 1.0, budget_cap)
	var taken: Array[InputCommand] = []
	while not _pending.is_empty() and _budget >= 1.0 and taken.size() < max_per_tick:
		taken.append(_pending.pop_front())
		_budget -= 1.0
	return taken


func pending_count() -> int:
	return _pending.size()
