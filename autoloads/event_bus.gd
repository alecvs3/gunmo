extends Node
## Global signal hub. Systems emit and connect here; nothing in this script holds state.
## Gameplay signals are emitted on the host only, unless noted.

@warning_ignore_start("unused_signal")

signal player_spawned(player: Node2D)
signal player_died(peer_id: int)
signal enemy_spawned(enemy: Node2D)
signal enemy_killed(enemy: Node2D, killer_peer_id: int)
## Host: something fired a real bullet (a Shot). The level's ProjectileSystem simulates it
## and tells the other peers.
## Shot signals are typed RefCounted, not Shot: an autoload signal typed with a script class
## keeps that script alive past shutdown in Godot 4.7 (leak warnings at exit).
signal shot_fired(shot: RefCounted)
## Owner client: our own player fired (a predicted Shot). The ProjectileSystem shows it at
## once; the host decides what it hits.
signal shot_predicted(shot: RefCounted)
## Every peer: the match state (a MatchNetState) changed. The HUD and results screen use it.
signal match_state_changed(state: RefCounted)
## This peer: we pressed or un-pressed ready.
signal local_ready_changed(is_ready: bool)
## Host UI: the host asked to play the match again (results screen).
signal match_restart_requested
