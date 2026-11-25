class_name PathNode
extends Resource
## One step on the Path: what it is, where it sits (branch and tier), what it costs in Cores,
## which steps it needs first and which it locks out, and what it does (its effects).
## Real nodes live in path/data/*.tres and are listed in the PathTree.

@export var display_name: String = ""
@export_multiline var description: String = ""
## The branch it belongs to (the window shows one column per branch).
@export var branch: String = ""
## 1 = the first step of its branch; deeper tiers need earlier steps.
@export_range(1, 5) var tier: int = 1
@export_range(0, 20) var core_cost: int = 1
## Every one of these must be owned first.
@export var requires: Array[PathNode] = []
## Owning any of these locks this one out, and the other way round.
@export var excludes: Array[PathNode] = []
@export var effects: Array[PathEffect] = []
