extends Node
## Global signal hub. Systems emit and connect here; nothing in this script holds state.
## Gameplay signals are emitted on the host only.

@warning_ignore_start("unused_signal")

signal player_spawned(player: Node2D)
signal player_died(peer_id: int)
signal enemy_spawned(enemy: Node2D)
signal enemy_killed(enemy: Node2D, killer_peer_id: int)
