class_name NetKinds
extends RefCounted
## The kinds of replicated entity, and which NetState class each one uses.
## New entity kind: add a constant, a NetState subclass, a line in make_state(), and the
## matching entry in NetEntity's `kind` export.

const NONE: int = 0
const PLAYER: int = 1
const ENEMY: int = 2
const MATCH: int = 3


static func make_state(kind: int) -> NetState:
	match kind:
		PLAYER:
			return PlayerNetState.new()
		ENEMY:
			return EnemyNetState.new()
		MATCH:
			return MatchNetState.new()
	return null
