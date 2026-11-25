extends Node
## Global signal hub. Systems emit and connect here; nothing in this script holds state.
## Gameplay signals are emitted on the host only, unless noted.

@warning_ignore_start("unused_signal")

## A player was killed; killer_id is the peer (or bot) id of whoever dealt the last hit
## (0 = an enemy's touch; an enemy's bullet = Shot.enemy_shooter_id, never a player's id).
signal player_killed(victim: Node2D, killer_id: int)
signal enemy_killed(enemy: Node2D, killer_peer_id: int)
## Host: an enemy lost `amount` health to `source_id` (a player's or bot's id; 0 = not a
## player). Pets that react to hits read this.
signal enemy_damaged(enemy: Node2D, amount: int, source_id: int)
## Every peer (Waves): show a pet's effect (PetEffects.Kind) at `points` for `seconds`.
signal pet_effect_shown(kind: int, points: PackedVector2Array, radius: float, seconds: float)
## Every peer (Gun Game): a kill for the kill feed. killer_id 0 = no player (a fall, an enemy);
## weapon_index is the killer's gun in the shop catalog (-1 = none).
signal kill_reported(killer_id: int, victim_id: int, weapon_index: int)
## A dying enemy splits into `count` enemies of type `into` (an EnemyData) where it stood.
## Emitted before it is freed, so the wave never looks empty in between.
signal enemy_split(enemy: Node2D, into: Resource, count: int)
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
## This peer: our own player was hit by a bullet; `from_direction` points from us toward
## where it came from (the HUD's hit-direction marker).
signal local_player_hurt(from_direction: Vector2)
## This peer: we pressed or un-pressed ready.
signal local_ready_changed(is_ready: bool)
## This peer (Waves): we voted (or took back our vote) to call the next wave early.
signal local_call_vote_changed(voted: bool)
## This peer: while our player is down we watch this player (0 = nobody / back to ourselves).
signal spectating_changed(peer_id: int)
## This peer's shop: the player clicked buy (kind = ShopRules.KIND_*). The mode turns it into
## a request the host checks.
signal shop_purchase_requested(kind: int, index: int)
## This peer's Path window (Waves): the player asked to take PathTree node `index`. The mode
## turns it into a request the host checks.
signal path_step_requested(index: int)
## Host UI: the host asked to play the match again (results screen).
signal match_restart_requested
## Every peer, looks only: something drawn at `at` lost `amount` health (a HitFeedback saw it
## in the host's numbers); `big` = a big share of its max health. The FeedbackSystem shows it.
signal damage_seen(at: Vector2, amount: int, big: bool)
## Every peer, looks only: an explosion of `radius` was shown at `at` (camera shake).
signal blast_shown(at: Vector2, radius: float)
## Every peer, sounds only: a bullet (a Shot) appeared here, once per bullet (predicted on the
## shooter's own peer, real on the host, remote elsewhere). The FeedbackSystem plays the gun.
signal shot_shown(shot: RefCounted)
