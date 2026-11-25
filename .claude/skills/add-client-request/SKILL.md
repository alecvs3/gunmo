---
name: add-client-request
description: Let a client ask the host for something (buy, vote, pick, ready, use an item). Use when a player action outside movement and shooting must change host state.
---

# Add a client request

Clients never change gameplay state themselves (rule 1). They ask, and the host checks the
rules. Movement, aiming, firing and reloading are **not** requests: they're `InputCommand` buttons.

1. **Pick a topic number** that's unused. Existing ones: `GameMode.REQUEST_READY` = 1
   (`modes/game_mode.gd`), `WaveMode.REQUEST_BUY` = 2 (`modes/wave_mode.gd`). Add a
   `REQUEST_<NAME>` constant where it's handled.
2. **Client side:** the UI emits an EventBus signal (UI never calls into a mode; see
   `shop_purchase_requested`). The mode (or system) that owns it turns that into
   `NetworkManager.channel.send_request(topic, data)`, with data as a small `PackedByteArray`.
   On the host, call the handler directly instead (see `GameMode.set_local_ready`).
3. **Host side:**
   - In a mode: handle it in `_on_request(peer_id, topic, data)`. `GameMode` already drops
     requests from peers without a player.
   - Elsewhere: connect to `NetworkManager.channel.request_received`.
4. **Check everything before acting:**
   - exact `data.size()`
   - every index against its catalog
   - the phase (`can_ready_up()`, shop open...)
   - the player's state (alive, credits)
   - Refuse silently and log with `NetLog.write`. See `WaveMode._buy` / `_purchase_problem`.
   There's no per-client rate limit yet (#47), so a handler must be cheap and safe to call often.
5. **Put the rule in a pure function** and unit-test it (like `upgrades/shop_rules.gd` and
   `tests/upgrades/test_shop_rules.gd`).
6. **The result reaches clients through state they already get** (a snapshot or match state),
   not a reply.
7. A new topic or payload is a network format change: bump `Handshake.PROTOCOL`
   (`shared/network/handshake.gd`). Add a smoke check if it matters to play (see
   `tests/net/shop_smoke.gd`, which also sends purchases the host must refuse). Run
   `.\tools\check.ps1 -Changed` and update `docs/PROGRESS.md`.
