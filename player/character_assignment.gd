class_name CharacterAssignment
extends RefCounted
## Who looks like whom: each new player gets a character nobody in the match has yet (humans
## from the human looks first, bots from the bot looks first), so players can tell each other
## apart. Only when every look is taken do they repeat. Pure; the host picks, the choice is
## sent once with the spawn (Player.look_index).


## The look index for a new player. `taken` = indices already in use, `preferred` = the
## indices to try first, `count` = how many looks there are in all.
static func pick(taken: Array[int], preferred: Array[int], count: int, fallback: int) -> int:
	if count <= 0:
		return -1
	for index in preferred:
		if index >= 0 and index < count and not taken.has(index):
			return index
	for index in count:
		if not taken.has(index):
			return index
	return posmod(fallback, count)
