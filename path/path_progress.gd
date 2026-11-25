class_name PathProgress
extends RefCounted
## One player's Path in a run: the nodes owned (bit i = PathTree node i), the Cores to spend,
## and whether this break's step is used. PathRules changes it; it lives on the PlayerLoadout
## and travels in the player snapshot.

var owned: int = 0
var cores: int = 0
## Already took a step this break (PathRules.start_break clears it).
var stepped: bool = false


func owns(index: int) -> bool:
	return PathTree.owns(owned, index)


func reset() -> void:
	owned = 0
	cores = 0
	stepped = false
