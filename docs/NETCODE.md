# Netcode guide

How multiplayer works in this project, and how to build new features on it.
Short version: **the host decides, the owner predicts, everyone else interpolates.**

## Who decides what

| Shown instantly on your own PC | Decided by the host (the truth) |
|---|---|
| Your aim (the gun follows the mouse every frame) | Where every player really is |
| Your movement (predicted, corrected if wrong) | Whether a shot was allowed (fire rate, ammo) |
| Your bullets, ammo count, reload timer | Every hit, all damage, deaths, kills, knockback |
| Smooth display of everyone else (100 ms in the past) | Enemy AI, spawns, waves, upgrades, the ladder |

Clients only ever send **inputs** ("move this way, aim here, fire"), never results ("I hit him").
When a client's prediction and the host disagree, the host wins and the client corrects itself
without a visible jump.

## The pieces (all children of the `NetworkManager` autoload)

| Piece | File | Job |
|---|---|---|
| `NetClock` | `shared/network/net_clock.gd` | Shared time in ticks (60/s). The host counts; clients estimate the host's tick from snapshots and draw others `interpolation_delay` behind it (the *render tick*). |
| `NetChannel` | `shared/network/net_channel.gd` | All gameplay traffic: **commands** (client → host, every tick), **snapshots** (host → clients, 30/s), **events** (host → clients, reliable, by topic). Runs everything through the **network simulator**. |
| `Replicator` | `shared/network/replicator.gd` | Host: every 2 ticks packs every `NetEntity`'s state into compact snapshot packets (split to fit the MTU). Clients: unpack and hand states to entities. |
| `LagCompensator` | `shared/network/lag_compensator.gd` | Host keeps ~250 ms of every hitbox's positions, so a shot is tested against where targets were **when the shooter saw them**. |
| `JoinGate`, `PingTracker` | `shared/network/` | Join check (build/version/full lobby), ping/loss/bandwidth. |

Spawning and despawning still uses Godot's `MultiplayerSpawner` (reliable, handles late joiners).
Continuous state never uses `MultiplayerSynchronizer`; it goes through snapshots.

## One tick, step by step

1. **Owner client** (`PlayerPrediction`): makes an `InputCommand` (numbered), simulates the player
   with it **immediately**, stores it, and sends the last 4 commands (repeats survive packet loss).
2. **Host** (`Player` + `CommandQueue`): simulates each player with its owner's commands, at most
   one per tick on average (no speed hacks; late packets can catch up a little).
3. **Host**, end of the tick (`Replicator`, every 2 ticks): snapshot of every entity, including
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
  shooter they see, and end it exactly where and when the host said.
- `ProjectileSystem.hit_confirmed` fires on the shooter's PC when the host confirms a hit
  (use it for hit markers).

## How to add things

**A new networked entity** (an enemy type, a pickup, a turret):
1. Add a `NetEntity` node (set `kind`) and a `SpawnSync` `MultiplayerSynchronizer` that syncs
   `NetEntity:net_id` at spawn only (copy it from `enemies/test_enemy.tscn`).
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

**A one-off event** (wave started, pickup taken, upgrade bought): host sends
`NetworkManager.channel.send_event(peer_id, TOPIC, bytes)`; clients listen to
`channel.event_received`. Pick a new topic number (bullets use 1).

**Bots** (Gun Game): give them a `Player` and fill `PlayerInputSource.scripted` with an
`InputCommand` each tick from the AI. Everything else (movement, shooting, lag compensation)
works the same as for humans.

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
