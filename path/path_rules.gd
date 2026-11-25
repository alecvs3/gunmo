class_name PathRules
extends RefCounted
## The Path's rules. Pure, so every rule is unit-tested; the host runs them on every Path
## request (clients only use them to show what can be taken).
## - A step can only be taken in a break between waves, and only one per break. Calling a wave
##   early skips its break, so it skips that break's step too.
## - A step costs Cores, needs every node it requires, and is refused if an owned node excludes
##   it (or it excludes an owned node).
## - Steps are permanent for the run: nothing takes a node away (no respec).

enum Status { OWNED, AVAILABLE, LOCKED }


## "" if the player may take node `index` now, otherwise why not.
static func check(tree: PathTree, progress: PathProgress, index: int, in_break: bool) -> String:
	if not tree.is_node_index(index):
		return "No such step."
	if progress.owns(index):
		return "Already on your Path."
	var blocked: String = locked_reason(tree, progress, index)
	if not blocked.is_empty():
		return blocked
	if not in_break:
		return "The Path opens between waves."
	if progress.stepped:
		return "One step per break: wait for the next one."
	if progress.cores < tree.nodes[index].core_cost:
		return "Not enough Cores."
	return ""


## Why the node can't be reached at all yet (a requirement missing, or locked out), or "".
static func locked_reason(tree: PathTree, progress: PathProgress, index: int) -> String:
	var path_node: PathNode = tree.nodes[index]
	for other in path_node.excludes:
		if progress.owns(tree.index_of(other)):
			return "Locked out by %s." % other.display_name
	for i in tree.nodes.size():
		if progress.owns(i) and path_node in tree.nodes[i].excludes:
			return "Locked out by %s." % tree.nodes[i].display_name
	for needed in path_node.requires:
		if not progress.owns(tree.index_of(needed)):
			return "Needs %s first." % needed.display_name
	return ""


## Takes node `index` if the rules allow it: spends its Cores and uses this break's step.
static func take(tree: PathTree, progress: PathProgress, index: int, in_break: bool) -> bool:
	if not check(tree, progress, index, in_break).is_empty():
		return false
	progress.cores -= tree.nodes[index].core_cost
	progress.owned |= 1 << index
	progress.stepped = true
	return true


## A new break: one more step may be taken.
static func start_break(progress: PathProgress) -> void:
	progress.stepped = false


## What the window shows: owned, can be taken right now, or not.
static func status(tree: PathTree, progress: PathProgress, index: int, in_break: bool) -> Status:
	if progress.owns(index):
		return Status.OWNED
	if check(tree, progress, index, in_break).is_empty():
		return Status.AVAILABLE
	return Status.LOCKED


## Cores each player gets for clearing `wave`: cores_per_wave, plus cores_solo_bonus every
## cores_solo_every waves when one human plays with no bots.
static func wave_cores(settings: MatchSettings, wave: int, solo: bool) -> int:
	var cores: int = settings.cores_per_wave
	var every: int = settings.cores_solo_every
	if solo and every > 0 and wave > 0 and wave % every == 0:
		cores += settings.cores_solo_bonus
	return cores


## Cores a player gets when a boss dies: cores_per_boss plus their own Path's extra.
static func boss_cores(settings: MatchSettings, tree: PathTree, progress: PathProgress) -> int:
	return settings.cores_per_boss + tree.extra_boss_cores(progress.owned)


## One human and no bots: the solo Core bonus applies.
static func is_solo(humans: int, bots: int) -> bool:
	return humans == 1 and bots == 0
