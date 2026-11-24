# shared/network: the netcode

Read `docs/NETCODE.md` for the full design. This page is the short version for working here.

## The model
- **The host decides.** Clients send only inputs (`InputCommand`, every tick, unreliable) and
  requests (`NetChannel.send_request`, reliable, the host checks them).
- **The owner predicts** its own player (`player/player_prediction.gd`) and reconciles with
  the host's state for it.
- **Everyone else is interpolated** from snapshots at `NetClock.render_tick()`, which is one-way
  latency plus a smoothing buffer that adapts to jitter.

## Key pieces
| File | Job |
|---|---|
| `net_clock.gd` | Ticks (60 Hz), host tick estimate, render tick, adaptive smoothing delay |
| `net_channel.gd` | All gameplay traffic: commands, snapshots, events, requests. Reads at tick start, sends at tick end. Goes through `net_simulator.gd` (fake lag) |
| `replicator.gd` | Host: captures every `NetEntity` after the tick and sends snapshots. Client: unpacks them |
| `net_entity.gd` | Makes its parent replicated. The parent implements `capture_net_state()` / `apply_net_state()` |
| `net_state.gd`, `states/` | Fixed binary layout per entity kind (`PlayerNetState`, `EnemyNetState`, `MatchNetState`) |
| `net_kinds.gd` | Entity kind → `NetState` class |
| `snapshot_codec.gd` | Packs states into packets under the MTU (4-byte header per entity) |
| `rate_limiter.gd` | Host: per-client limits on command packets and requests (NetChannel drops the extra; numbers in `NetworkConfig`) |
| `command_queue.gd` | Host: one player's inputs waiting to run, with a small playout buffer only when they stall |
| `lag_compensator.gd`, `position_history.gd` | Shots hit what the shooter saw (rewind up to `max_rewind`) |
| `handshake.gd`, `join_gate.gd`, `build_info.gd` | Who may join: same `PROTOCOL` and build, lobby not full |
| `ping_tracker.gd`, `net_stats.gd`, `jitter_meter.gd`, `net_log.gd` | Measurements for F3, the logs and the latency checks |
| `latency_budget.gd`, `latency_budget.tres` | The input-delay and smoothing goals, checked by smoke scenario G |
| `launch_args.gd` | `--host`, `--join`, `--dedicated`, `--net-sim`, `--match` |

Tuning lives in `default_network_config.tres` (`NetworkConfig`), never in code.

## Rules that aren't obvious
- **Changing a network format means bumping `Handshake.PROTOCOL`** in `handshake.gd`, so older
  builds are refused instead of misreading packets. Formats include any `NetState` layout,
  `InputCommand`, the snapshot header, and event or request payloads.
- **Never use a continuous `MultiplayerSynchronizer`.** Spawn-time properties (`SpawnSync`) are fine.
- **Clients' data is untrusted.** Clamp and check everything decoded from a client: sizes,
  indices, ticks (see how `player_timeline.gd` clamps `client_tick`). A new decoder of client
  data gets a case in `tests/shared/network/test_garbage_input.gd` (random bytes, seeded).
- **Snapshots go to each client separately.** A client gets its own player in full and everyone
  else in the public form. A private field (credits, ammo, upgrades) must stay out of
  `encode_public`.
- **Packed arrays are copied when read out of a Dictionary.** Store them back after changing them.
- The host draws remote things 2 ticks back (`DisplayDelay`, `host_view_delay_ticks`), so its
  own shots are checked against what it sees.

## Recipes
`add-networked-field`, `add-client-request` (in `.claude/skills/`).

## Tests
- Unit tests: `tests/shared/network/`. The field round trip test is
  `tests/shared/network/test_net_state_fields.gd`; it has a `NOT_PUBLIC` list of private fields.
- Run `.\tools\check.ps1 -Smoke` for **any** change here (a big change: `-Changed` picks every scenario too). It runs the multiplayer scenarios in
  `tests/net/` (lag, dedicated server, waves, shop, gun game, stress, latency, fairness).
- Soak: `.\tools\check.ps1 -Smoke -Scenarios S` runs the stress scene for 10 minutes and fails
  if memory, objects or nodes keep growing. Opt-in; run it after big changes.
