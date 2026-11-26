# Netcode guide

How multiplayer works in this project, and how to build new features on it.
Short version: **the host decides, the owner predicts, everyone else interpolates.**

## Who decides what

| Shown instantly on your own PC | Decided by the host (the truth) |
|---|---|
| Your aim (the gun follows the mouse every frame) | Where every player really is |
| Your movement (predicted, corrected if wrong) | Whether a shot was allowed (fire rate, ammo) |
| Your bullets, ammo count, reload timer | Every hit, all damage, deaths, kills, knockback |
| Smooth display of everyone else (your latency + a small adaptive buffer in the past) | Enemy AI, spawns, waves, upgrades, the ladder |

Clients only ever send **inputs** ("move this way, aim here, fire"), never results ("I hit him").
When a client's prediction and the host disagree, the host wins and the client corrects itself
without a visible jump.

## The pieces (all children of the `NetworkManager` autoload)

| Piece | File | Job |
|---|---|---|
| `NetClock` | `shared/network/net_clock.gd` | Shared time in ticks (60/s). The host counts; clients estimate the host's tick from snapshots and draw others behind it (the *render tick*) by their one-way latency plus a smoothing buffer that follows the measured snapshot jitter (see Latency below). |
| `NetChannel` | `shared/network/net_channel.gd` | All gameplay traffic: **commands** (client → host, every tick), **snapshots** (host → clients, 60/s), **events** (host → clients, reliable, by topic). Runs everything through the **network simulator**. |
| `Replicator` | `shared/network/replicator.gd` | Host: every tick packs every `NetEntity`'s state into compact snapshot packets (split to fit the MTU), per client: its own player in full, everything else in the short public form. Clients: unpack and hand states to entities. |
| `LagCompensator` | `shared/network/lag_compensator.gd` | Host keeps ~250 ms of every hitbox's positions, so a shot is tested against where targets were **when the shooter saw them**. |
| `JoinGate`, `PingTracker` | `shared/network/` | Join check (build/version/full lobby), ping/loss/bandwidth. |

Spawning and despawning still uses Godot's `MultiplayerSpawner` (reliable, handles late joiners).
Continuous state never uses `MultiplayerSynchronizer`; it goes through snapshots.

## One tick, step by step

1. **Owner client** (`PlayerPrediction`): makes an `InputCommand` (numbered), simulates the player
   with it **immediately**, stores it, and sends the last 4 commands (repeats survive packet loss).
2. **Host** (`Player` + `CommandQueue`): simulates each player with its owner's commands, at most
   one per tick on average (no speed hacks; late packets can catch up a little). Only if a
   player's inputs keep stalling does the queue hold one or two in reserve (see Latency).
3. **Host**, end of the tick (`Replicator`, every tick): snapshot of every entity, including
   for each player "the last command I simulated".
4. **Owner client**, on that snapshot: rewinds its player to the host's state, replays every
   command the host hasn't simulated yet, and eases any small difference out of the visuals.
5. **Other clients**: buffer the snapshots and draw each entity at the render tick, blended
   between the two snapshots around it (`StateBuffer`), so motion is smooth however packets arrive.

`Player.simulate(command)` is the single function both the host and the owner run. It must stay
deterministic: no random numbers without a seed, no reading the clock, no `delta` from the
frame (always `NetClock.tick_delta()`).

## Shooting

- The weapon (`WeaponComponent.step`) is stepped once per command on both sides, so both agree
  on when shots happen. Spread uses a seed from (shooter, command number), so both sides draw the
  same bullet path.
- **Owner:** shows its own bullet at once (`Bullet` mode PREDICTED). It stops on what the owner
  sees but deals nothing.
- **Host:** simulates the real bullet (AUTHORITATIVE) with swept hit tests (fast bullets can't
  skip through targets), rewound to the shooter's view (lag compensation, capped at
  `max_rewind`). It tells every other peer the bullet was fired, and everyone where it ended.
- **Other clients:** place the bullet on their render timeline (REMOTE), so it lines up with the
  shooter they see, and end it exactly where and when the host said. A bullet whose path comes
  near your own player catches up from that past timeline to the present over its first
  0.2 s, so a bullet that hits you visibly reaches you when the damage lands. A bot's or
  enemy's bullet catches up before it can reach you (`Bullet.catch_up_ticks`: the ticks until it
  reaches you, minus the render delay, halved), or is drawn on the present at once when that
  is under 6 ticks (`LatencyPolicy.snap_close_threats`).
- **Your own hits show at once** (`LatencyPolicy.predict_hit_effects`): when your PREDICTED
  bullet lands, EventBus `hit_predicted` flashes the target and plays its hit sound; the host's
  health drop for it then shows only the number (`shared/feedback/predicted_hits.gd`, the idea
  of DDNet's predicted events). A hit the host never confirms still flashed (a misprediction;
  the smoke test checks the host confirms at least 90%).
- **Hurt at once** (`LatencyPolicy.predict_own_hurt`): a bot's or enemy's bullet, drawn on the
  present, that sweeps into your player plays the hurt sound, marker and shake then
  (`Bullet.reached_us`); `EVENT_HURT` names the shot, so the host's verdict doesn't repeat it.
- **Wind-up volleys are sent ahead** (`LatencyPolicy.schedule_windup_shots`, Waves): with
  `aim_lock_seconds` (0.25) of windup left, the enemy locks its aim, stands still and builds the
  volley's shots with a fire tick ahead; every peer gets them at once (`EVENT_SCHEDULED`), waits
  with an aim line (`weapons/aim_line.gd`) and shows them on the present from the tick they
  leave (`Bullet.scheduled`). If the enemy leaves first, they're ended (`EVENT_ENDED`).
- **Bots' and enemies' bullets and fair dodging** (`weapons/timeline_hits.gd`): every input carries the
  sender's view of the host clock (`InputCommand.client_tick`), and the host records where each
  remote player's own inputs put them on that timeline (`Player.timeline`). A bot's bullet is
  tested against a remote human there, tick by tick as their inputs arrive (it may wait up to
  `max_rewind` after it stops), so a dodge made on a laggy player's own screen counts. Stamps
  may only be up to `max_rewind` in the past, never in the future or out of order. Human
  shooters keep shooter-favoured lag compensation. Bots lead moving targets
  (`AimLead.intercept`), from where that player's own screen has them. Ranged enemies
  (`RangedAttack`) fire as shooter `Shot.enemy_shooter_id(net_id)`, a negative id far below any
  bot's, so their bullets get the same fair dodging; they lead from the host's view.
- The player who was hit gets `EVENT_HURT` with what hit it (a bullet's shot, or an enemy's
  touch and the tick it was judged on) and the direction it came from (the HUD's hit-direction
  marker, `ui/hurt_indicator.gd`, and the hurt sound).

## Contact attacks (melee, dashes)

An enemy hurts the players its `ChaserEnemy._touching_hitboxes()` returns (MeleeAttack, a
Charger's dash). With `LatencyPolicy.fair_contact` on (Waves), a remote human counts as touched
only if the enemy, **where that player saw it**, touched **where that player's own input put
them**: every input carries `InputCommand.view_tick` (the client's render tick), the player's
timeline keeps it with the input's stamp (`PlayerTimeline.view_at`), `LagCompensator.position_at`
gives the enemy's place then, and `ContactJudge` (`enemies/contact_judge.gd`) tests the enemy's
contact square against the player's round hitbox. The host still decides (rule 1); it only
judges on the victim's view, like fair dodging does for bullets. The host's own player and bots
keep the plain overlap. Every touch is reported (EventBus `contact_hit` → `EVENT_HURT`).
A client could send an old `view_tick` to be judged against older enemy positions, but it is
clamped to `victim_rewind` (0.3 s) before its stamp, and in co-op nobody gains from it.

## Latency policy per mode

Each mode scene sets a `LatencyPolicy` (`modes/data/*_latency.tres`); `GameMode` hands it to
`NetworkManager.latency_policy` while it runs, so shared code reads the policy, never the mode.
The default (`shared/network/default_latency_policy.tres`) turns everything off.

| Policy field | Waves | Gun Game | Why they differ |
|---|---|---|---|
| `predict_hit_effects` | on | on | Your own hit should never wait. |
| `predict_damage_numbers` | off | off | Numbers wait for the host's real value. |
| `predicted_hit_seconds` | 0.5 | 0.5 | How long a shown hit waits for the host's verdict. |
| `snap_close_threats` | on | on | Gun Game: bots' bullets only (humans' are lag-compensated). |
| `predict_own_hurt` | on | on | Gun Game: bots' bullets only. |
| `fair_contact` | on | off | Only Waves has contact attacks. |
| `victim_rewind` | 0.30 s | 0.25 s | PvE can favour the defender a little more. |
| `schedule_windup_shots` | on | off | Only Waves has wind-up attacks. |
| `aim_lock_seconds` | 0.25 s | — | At least one-way latency plus smoothing. |
- `ProjectileSystem.hit_confirmed` fires on the shooter's PC when the host confirms a hit
  (use it for hit markers).

## Latency: as little delay as possible, smoothing only where it's needed

The goals live in `shared/network/latency_budget.tres`; `test_latency_budget.gd` checks the
settings and smoke scenario G (`tests/net/latency.gd`) measures them: no hitches, a buffer that
never exceeds what the measured jitter needs (by more than 15 ms, so no wasted delay on any
machine), and hard caps on top. Every stage:

| Stage | How | Typical |
|---|---|---|
| Your aim | The gun follows the mouse every rendered frame | 1 frame |
| Your movement and shots | Predicted on your PC; `OwnPlayerDrawing` draws you one tick of motion ahead of the physics-interpolated body (`PlayerData.draw_ahead`) | 1 tick to respond |
| Display | Adaptive V-Sync, 2 swapchain images, agile input flushing (checked by a test) | 1–2 frames |
| Others on a client | One-way latency (followed directly) + a buffer of one snapshot interval + 1.25 × measured snapshot jitter + 8 ms (35–250 ms). Only the buffer is rate-limited: it grows fast when snapshots get uneven or drawing runs dry, shrinks slowly. A client frame longer than `local_stall_seconds` (a loading freeze) drops the measured jitter, since snapshots read after it arrive bunched up by us, not the network | latency + 35–55 ms |
| Others on the host | `DisplayDelay` draws everyone but the host's own player `host_view_delay_ticks` (2) back, so bunched-up inputs don't show; the host's shots are checked at that same moment | 33 ms |
| Inputs reaching the host | `CommandQueue` holds nothing back unless that player's inputs actually stall; then 1, at most 2 ticks, given back after 5 calm seconds | 0–1 tick |
| Sending and receiving | `NetChannel` reads packets at the start of every physics tick and sends at its end, never waiting for the rendered frame | 0 frames |

Snapshots go out every tick (60/s). A client gets its own player in full (91 bytes: prediction
needs every detail) and other players in a 29-byte public form; enemies send quarter-pixel
positions (6 bytes); each entity has a 4-byte header (u16 id, kind with a public-form flag,
u8 size). That keeps 60/s at the bandwidth 30/s used to need (about 50 KB/s per player in the
stress test).

**Diagnostics:** F3 shows snapshot jitter, missed snapshots, how often smoothing ran dry, the
delay split into latency + smoothing, and for every player how their inputs reach the host
(jitter, held-back ticks, late ticks per second; the host shares these with everyone).
Hiccups (no snapshot for 250 ms, a player's inputs stalling for 100 ms, the input buffer
changing) are logged; windowed runs write each session's log to `user://logs/net/` (the last
30 are kept), so last night's stutter can still be looked up.

## How to add things

**A new networked entity** (an enemy type, a pickup, a turret):
1. Add a `NetEntity` node (set `kind`) and a `SpawnSync` `MultiplayerSynchronizer` that syncs
   `NetEntity:net_id` at spawn only (copy it from `enemies/chaser.tscn`).
2. If it needs fields the existing kinds don't have, add a `NetState` subclass in
   `shared/network/states/` and a kind in `NetKinds`.
3. Give the root script `capture_net_state()` (host) and `apply_net_state(state)` (clients).
4. Put it under a `MultiplayerSpawner` so clients get it.

**A new replicated field** on an existing kind: add it to that `NetState` subclass (encode,
decode, `byte_size`, `copy` if any), then **bump `Handshake.PROTOCOL`** so older builds are
refused instead of misreading snapshots.

**A new player action** (dash, grenade, interact): add a button bit to `InputCommand`, read it in
`PlayerInputSource`, and handle it inside `Player.simulate()`. It is then predicted, replayed and
validated automatically. Bump `Handshake.PROTOCOL`.

**Match state** (the game mode): `GameMode` lives under `Main/ModeContainer`, replicated by
`ModeSpawner`, and carries a `NetEntity` of kind MATCH. Its `MatchNetState` (mode kind, phase, wave,
phase end tick, enemies left, players in/alive/ready, shop open, Gun Game ladder shape and
winner) reaches clients with every snapshot;
clients use the newest one and everything announces it through
`EventBus.match_state_changed`. Timers are host ticks, so every countdown is identical.

**A request from a client** (ready up now, buy an upgrade later): the client calls
`NetworkManager.channel.send_request(TOPIC, bytes)`; the host gets `channel.request_received`
with the sender's peer id and must check it against the rules before acting (see
`GameMode._on_request_received`).

**Shop and loadouts:** the ShopCatalog and ModifierCatalog are fixed files; items travel by
index (weapon index, 16 upgrade levels and credits in `PlayerNetState`; the modifier bitmask in
`MatchNetState` and each enemy's spawn data). `PlayerLoadout` applies weapon and upgrades through
`PlayerStats` identically on every peer, so the owner predicts with the host's stats. Purchases
are requests (`WaveMode.REQUEST_BUY`) checked with `ShopRules` on the host.

**A one-off event** (pickup taken): host sends
`NetworkManager.channel.send_event(peer_id, TOPIC, bytes)`; clients listen to
`channel.event_received`. Pick a new topic number (bullets use 1, enemy death bursts 2, the Gun Game kill feed 3).

**Names, teams and scores:** a joiner's name travels in the join hello; the host spawns the
player with it and `SpawnSync` sends `display_name` and `is_bot` once with the spawn. Team id,
spawn protection and the score (kills, deaths, tier, tier kills) are part of `PlayerNetState`.
Team 0 is the co-op team; any other number is a team of its own (Gun Game uses the player's
id). Hitboxes know their owner, so a shot never hits its own shooter.

**Bots** (Gun Game): `Level.spawn_bot` spawns a normal `Player` with a negative id and adds a
`BotController` that exists only on the host. Each tick the Player runs the bot's
`InputCommand` (stamped with the current tick, since the host sees the present) instead of a
human's, so movement, shooting, lag compensation and replication are the same as for humans.
Ids are signed everywhere they travel (`Shot.shooter_id`, team ids).

## Testing

- **Two instances:** Debug → Customize Run Instances → instance 1 `-- --host`,
  instance 2 `-- --join 127.0.0.1`.
- **Fake a bad connection** on any instance: add `--net-sim 100,20,5` (100 ms each way, ±20 ms
  jitter, 5% loss). F3 shows "SIMULATED" while it's on.
- **Dedicated server:** `-- --dedicated [port]`, no player of its own (for the Oracle server
  later; run headless with `--headless`).
- **Smoke test:** `.\tests\net\run_smoke.ps1 -Godot <console exe>` runs a listen host with a
  lagged client and a wrong-build client, then a dedicated server with two clients, and checks
  prediction, agreement with the host, hit confirmation, interpolation and refusals.
- **F3 overlay:** ping, loss, bandwidth, tick, how far behind others are drawn, size of the last
  prediction correction, unconfirmed inputs, snapshot size.

## Any refresh rate

The simulation (movement, shooting, networking) always runs at 60 ticks per second; drawing
runs at the monitor's rate. The engine's physics interpolation draws bodies between ticks, and
`PlayerCamera` follows that drawn position every frame, so 60, 144 and 240 Hz screens all
scroll smoothly. Never move the view or a visible node from `_physics_process` unless the
engine interpolates it; never tie gameplay to the frame rate. Check with
`godot --path . -s res://tests/visual/frame_pacing.gd` (opens a window for a few seconds).

## Tuning

Everything is in `shared/network/default_network_config.tres` (snapshot rate, interpolation
delay, command budget, prediction snap distance, max rewind, simulator defaults).

## Known limits (honest list)

- The host's own view of remote players moves in small steps when their commands arrive
  unevenly (the host shows the truth, not a smoothed version).
- No interest management yet: every client gets every entity. Fine for one arena; needed for
  big maps later.
- Snapshots are full states, not deltas (about 10 bytes per enemy). Fine for hundreds of enemies
  at 30 snapshots per second; delta compression can be added inside `SnapshotCodec` later.
- Exported (non-editor) builds compare by version number only, not by build fingerprint.
- **A melee shove isn't predicted.** Your PC learns of a knockback one round trip later, so for a
  moment your screen has you where the host no longer does; a hit in that moment (bullet or
  melee) can look unfair. Smoke I counts those apart: `bullet_hits_while_displaced` (5–16 per
  run at 160 ms) and `melee_hits_while_displaced` (about half of all melee hits with three
  Runners on you). Every other melee hit is fair (gap 0–2 px). Predicting the shove was tried
  twice (2026-11-26), both made it worse: first from a "ready to strike" bit (it arrives late),
  then from the host tick the touch is ready plus the player's input lead (melee fair share
  80–83% and a 21–23 px worst gap, against 83–90% and 9–12 px without). A shove predicted even
  a tick or two off moves you while the enemy is still on you.
- **Point-blank shots without a windup** (the spitter, Shooters) can hit before their
  `EVENT_FIRED` reaches you (one-way latency): no drawing can show them
  (`bullet_hits_before_drawn` in smoke H and I). Wind-up volleys are sent ahead instead.
- **Enemies react to you late** (80–160 ms): they are drawn in the past, by design. Predicting
  them forward would break fair contact (`docs/LATENCY_PLAN.md`, section 4).
- **Where fairness breaks** (lag sweep, 2026-11-26: smoke H and I with the client at each
  latency each way and 10 ms jitter, one run each, `run_smoke.ps1 -Only H,I -ClientSim "125,10,0"`):

  | Latency each way (round trip) | 0 (0) | 40 (80) | 80 (160) | 125 (250) | 160 (320) |
  |---|---|---|---|---|---|
  | Own hit shown, p50 | 0 ms | 0 ms | 0 ms | 0 ms | 0 ms |
  | Shown hits the host confirmed, Gun Game / Waves | 1.00 / 0.99 | 0.99 / 0.99 | 0.94 / 0.95 | 0.87 / 0.94 | 0.79 / 0.93 |
  | Hits on you drawn on you, Gun Game / Waves | 0.98 / 1.00 | 0.98 / 1.00 | 1.00 / 1.00 | 1.00 / 0.90 | 1.00 / 1.00 |
  | Volley hits drawn on you | 1.00 | 1.00 | 1.00 | 0.88 | 1.00 |
  | Melee fair share / worst 5% gap | 0.99 / 1 px | 0.92 / 6 px | 0.87 / 10 px | 0.88 / 9 px | 0.88 / 7 px |
  | Every budget met | yes | yes | yes | no | no |

  What breaks first, above about 200 ms round trip: in Gun Game, lag compensation stops at
  `max_rewind` (0.25 s), so a shooter's hits on what they saw get rejected more often (shown hit,
  no damage); and a volley's 0.25 s aim lock no longer covers one-way latency plus smoothing, so
  some boss pellets arrive late. Fair contact holds (its `victim_rewind` is 0.3 s).
