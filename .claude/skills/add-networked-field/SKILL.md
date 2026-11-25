---
name: add-networked-field
description: Replicate a new piece of continuous state (on a player, an enemy or the match) from the host to clients. Use when a value the host changes must be visible on clients or rewound by prediction.
---

# Add a networked field

Area: **shared** (`shared/network/`): both developers review. Continuous state goes through
snapshots. One-off things (a sound, a hit) are a reliable `NetChannel` event instead, and
spawn-time constants are a `SpawnSync` property.

1. **Add the field to the state class** in `shared/network/states/`: `PlayerNetState`,
   `EnemyNetState` or `MatchNetState`.
   - Write it in `encode()` and read it in the same order in `decode()`. Use the smallest type
     that fits, and clamp it (`put_u8(clampi(x, 0, 255))`).
   - Update `SIZE` (what `byte_size()` returns) and the byte list in its comment.
   - Copy it in `copy()` and compare it in `equals()`, where the class has them.
   - Blend it in `interpolated()` if it moves smoothly (positions, angles). Otherwise the
     nearer state wins.
2. **Public or private?** (`PlayerNetState` only.) Others get the short public form.
   - Others need it → write it in `encode_public()`/`decode_public()` too and update `PUBLIC_SIZE`.
   - Only the owner needs it → add it to `NOT_PUBLIC` in `tests/shared/network/test_net_state_fields.gd`.
3. **Capture and apply it.**
   - Player: `player/player_net_sync.gd`. `capture()` on the host. `show_state()` if others
     see it. `restore()` if prediction must rewind to it (anything `simulate()` reads or writes).
   - Enemy: `capture_net_state()` / `apply_net_state()` in its script.
   - Match: the mode sets it on `state` before `publish_state()`.
4. **Bump `PROTOCOL`** in `shared/network/handshake.gd`, so older builds are refused instead of
   misreading snapshots.
5. **Tests:**
   - `tests/shared/network/test_net_state_fields.gd` round-trips every field by reflection and
     fails if you missed encode/decode/copy.
   - Add a value check to `tests/shared/network/test_net_states.gd` if it's clamped or blended.
6. **Size:** snapshots go out 60 times a second to every client. Check bytes per second with
   `.\tools\check.ps1 -Changed` (scenario F prints `client_download_avg_bytes`; budget 60 KB/s), and update `docs/PROGRESS.md`.
