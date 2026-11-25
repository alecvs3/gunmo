# Latency plan: making 160 ms feel fair

A plan for a fresh Claude session (or a developer) to follow, step by step. It explains the
problem, what the best open-source games do about it, and seven steps that fix it. Every step
says which files it touches, how Waves and Gun Game differ, how to test it, and when it's done.

**Read first:** root `CLAUDE.md`, `docs/NETCODE.md`, `shared/network/CLAUDE.md`,
`weapons/CLAUDE.md`, `modes/CLAUDE.md`. This plan assumes you know the words used there
(render tick, timeline, fair dodging, PREDICTED/REMOTE bullets).

---

## 1. The problem

Yusuf plays at about 160 ms round trip (RTT). He reported three things. Each one has a cause
we found in the code:

| What he feels | Cause in our code | Size at 160 ms |
|---|---|---|
| **Sounds are late.** Shooting an enemy, the hit sound comes long after the bullet visibly lands. | The enemy-hit sound and damage number play only when the enemy's health drops in a host snapshot: `HitFeedback._process` (`shared/feedback/hit_feedback.gd`) → `EventBus.damage_seen` → `FeedbackSystem._show_number`. Our PREDICTED bullet already stops on the enemy at once (`Bullet._hit`, PREDICTED mode) but plays nothing. | RTT + smoothing buffer ≈ 200 ms. People notice late audio from about 125 ms (ITU-R BT.1359) to 190 ms. |
| **Hit after dodging pellets.** | An enemy bullet's `EVENT_FIRED` arrives about one-way latency (80 ms) after it was fired. A REMOTE bullet near us then "catches up" from the render timeline to the present over a fixed 0.2 s (`Bullet.CATCH_UP_SECONDS`, `Bullet.display_tick`). Fair dodging (`weapons/timeline_hits.gd`) tests the bullet against our present-time timeline. So for close shots the bullet he sees is behind the bullet that is tested. | A 420 px/s bolt is drawn up to about 50 px behind its real place in the first 0.2 s. |
| **Melee hits from a distance.** | `ChaserEnemy._touching_hitboxes()` (`enemies/chaser.gd`) is a plain `Area2D` overlap at host time. No rewind, no timeline. His screen draws enemies at the render tick (about one-way + buffer behind the host) while his own player is in the present, about one-way ahead of the host's copy. | About 200 ms × enemy speed: a Runner (230 px/s) looks 45 px away, a Swarmer (270 px/s) 55 px away, when it hits. |

Melee hits on the local player also don't send `EVENT_HURT` today (only bullets do, in
`ProjectileSystem._tell_victim`), so melee gives no hit-direction marker and no
`player_hurt` sound.

### What can and can't be hidden (the realistic limit)

- **Your own actions** (moving, shooting, the hit sound of your own shot): fully hideable by
  prediction. We do movement and shots already; hit effects are step 3.
- **Hits on you from enemies and bots:** fully fair if the host judges them on *your* timeline,
  against where *you* saw the attacker. We do this for bullets; melee is step 5. The verdict
  (damage) still arrives one RTT after the moment on your screen. Only the *sound* of it can be
  predicted (step 4).
- **Enemies reacting to you** (turning toward you, choosing to attack): always show up
  80–160 ms late. Prediction could hide it but would then have to visibly correct itself.
  Section 4 explains why we don't do this.
- **Close-range player vs player (Gun Game):** some contradiction of up to one RTT is
  unavoidable. When two people act on shared state, one of them must see something that
  didn't happen on their screen. We stay shooter-favoured (lag compensation) as now.
- **Rewind cap:** past `max_rewind` (0.25 s) of render delay, fairness falls back to the host's
  view. At 160 ms RTT the render delay is about 120 ms, so we are inside it. Step 7 measures
  where it breaks.

**Target after this plan:** at 160 ms, Waves feels close to local play. Every hit on you is
one you saw land, and every sound you cause plays at once. Gun Game keeps today's
shooter-favoured rules plus instant hit sounds.

---

## 2. What the best examples do (verified in their source)

These were read from the actual repositories on 2026-11-25. Quote them in PRs when you copy an idea.

### DDNet (`github.com/ddnet/ddnet`): the most thorough 2D example
- `src/engine/shared/config_variables.h`:
  - `cl_predict_events` (0/1, "Predict events (sounds, particles)")
  - `cl_antiping` (0/1, "more aggressive prediction")
  - `cl_antiping_players` (0–3: 1 = always, 2 = "interaction only")
  - `cl_antiping_grenade`, `cl_antiping_weapons`, `cl_antiping_gunfire`
  - `cl_antiping_smooth`
  - `cl_antiping_percent` (100), `cl_antiping_limit` (0–500 ms)
  - `cl_antiping_preinput`
  - `cl_prediction_margin` (10 ms)
- **Predicted events and their dedup** (`src/game/client/gameclient.cpp`,
  `CGameClient::ProcessEvents`). The client plays sounds and effects from its own prediction.
  When the server's version of the same event arrives, it is played only if no matching
  predicted event was already handled:
  ```cpp
  if(!m_PredictedWorld.CheckPredictedEventHandled(CGameWorld::CPredictedEvent(
      Item.m_Type, DamageIndPos, -1, Client()->GameTick(g_Config.m_ClDummy), pEvent->m_Angle)))
  ```
  The key is (event type, position, tick, extra value). Predicted entries older than 3 s are
  dropped. **We copy this idea in step 3, keyed by our shot key instead of position.**
- **"Interaction only":** `cl_antiping_players 2` predicts only characters that are
  interacting with you (`pChar->IsInterfering()`); everything else stays interpolated.
- **Pre-inputs:** the server forwards each player's input to the others before the tick it
  applies to (`NETMSGTYPE_SV_PREINPUT` → `m_aPreInputs[m_IntendedTick % 200]`).
- **Smoothing mispredictions** (`OnPredict`/`GetSmoothPos`; this part was read only as a summary):
  - Errors between 0.05 and 5 units are blended per axis.
  - The blend length scales with prediction time and is capped at 700 ms.
  - The blend follows `1 - (1 - t/len)^1.2`.

### OpenSoldat (`github.com/opensoldat/opensoldat`): 2D shooter
- `shared/network/NetworkClientBullet.pas`, `ClientHandleBulletSnapshot`. A remote bullet is
  **fast-forwarded instantly**, not eased in:
  ```pascal
  Bullet[i].OwnerPingTick := Sprite[BulletSnap.Owner].Player.PingTicks + PingTicksAdd;
  pa := Sprite[MySprite].Player.PingTicks + Bullet[i].OwnerPingTick;
  ...
  for c := 1 to pa do begin
    BulletParts.DoEulerTimeStepFor(i);
    Bullet[i].Update;
    if not Bullet[i].Active then Break;
  end;
  ```
  Shotgun pellets get the same loop. **We copy this idea in step 4**, but only for bullets that
  would reach us before a smooth catch-up could finish.
- The client plays blood, sparks and hit sounds from its own hit test, while the server
  decides damage. That is the same idea as step 3.

### Victim-side judging in co-op PvE
- **Risk of Rain 2 mod PizzaClientLagFix** (`github.com/Goorakh/PizzaClientLagFix`): the
  victim's client decides whether a boss's sweeping attack hit it. This is exactly our melee
  complaint. We get the same result while keeping the host in charge (rule 1): the host judges
  on the victim's timeline. That is step 5.
- **Hunt: Showdown** "trusts the client of the Hunter being shot at". Bungie's Destiny gives
  each player authority over their own movement. **Darktide** is server-authoritative for
  dodging and players complain about exactly Yusuf's symptoms.
- **Halo Reach** (Aldridge, GDC 2011) hides about one RTT inside wind-up animations. Bungie
  found players don't notice a 150–200 ms gap there. That is the basis of step 6.
- **Overwatch** (Ford, GDC 2017) predicts by default ("predicting rockets is rad": an
  occasional wrong effect is worth the responsiveness). It reportedly stops favouring the
  shooter above about 220 ms RTT (secondary source, not verified).
- **Unity Netcode for Entities "prediction switching"** and **netfox**
  (`foxssake/netfox`, `examples/rollback-npc`): switch selected nearby entities from
  interpolated to predicted, and blend the jump.

---

## 3. Waves and Gun Game stay separate

The two modes need different rules. Waves is co-op PvE: favour the defender, and trust the
victim's view (cheating barely matters). Gun Game is PvP: stay shooter-favoured for humans,
and keep fair dodging only against bots.

**How, without breaking rule 7** (shared systems never ask which mode is running):

- A new Resource `LatencyPolicy` (`shared/network/latency_policy.gd`) lists every switch and
  number this plan adds. Shared code reads the *policy*, never the mode.
- Each mode scene exports its own policy file:
  - `modes/wave_mode.tscn` → `modes/data/waves_latency.tres`
  - `modes/gun_game/gun_game_mode.tscn` → `modes/data/gun_game_latency.tres`
  - The mode node is spawned from the same scene on every peer, so host and clients always
    have the same policy, with nothing to send.
- `GameMode._ready()` (every peer) hands it to `NetworkManager.latency_policy`. When the mode
  leaves the tree, it puts back `shared/network/default_latency_policy.tres`, where everything
  is off, which is today's behaviour. This uses the existing autoload (rule 8: no new autoload).
  `autoloads/` and the mode base class are "both review" areas, so step 2 says so in its PR.

| Policy field (added in step) | Waves | Gun Game | Why they differ |
|---|---|---|---|
| `predict_hit_effects` (3) | on | on | Your own hit sound should never wait, in either mode. |
| `predict_damage_numbers` (3) | off at first | off | Numbers are information, not feel. They wait for the host's real value. Turn on later only if playtests ask. |
| `predicted_hit_seconds` (3) | 0.5 | 0.5 | How long a predicted hit waits to be matched with the host's (DDNet uses 3 s; we know our RTT is lower). |
| `snap_close_threats` (4) | on | on | Bullets that would reach you before catching up are drawn at the present at once (Soldat). In Gun Game this applies to bots' bullets: human bullets are lag-compensated, so the victim can't predict them anyway. |
| `predict_own_hurt` (4) | on | on (bot bullets only) | Fair-dodging bullets are judged on your own timeline, so your PC can tell when one hits you. Human shooters' hits can't be predicted by the victim. |
| `fair_contact` (5) | on | off | Contact attacks exist only in Waves. Gun Game has none, and off keeps it exactly as today. |
| `victim_rewind` (5) | 0.30 s | 0.25 s | PvE can afford a slightly longer rewind than `max_rewind`. Gun Game keeps the existing cap. |
| `schedule_windup_shots` (6) | on | off | Bosses only exist in Waves. |
| `aim_lock_seconds` (6) | 0.25 | — | Must be at least one-way latency plus buffer, so the client gets the shot before it is fired. |

A GUT test (`tests/shared/network/test_latency_policy.gd`) checks three things:
- Both mode scenes have a policy.
- The default policy is all off.
- `aim_lock_seconds` is at least the one-way latency we support (`victim_rewind / 2`).

---

## 4. What we deliberately don't do (and why)

Write these into the PR descriptions so nobody re-proposes them without the reasoning:

1. **Predicting nearby enemies forward to the present** (DDNet "interaction only", Unity
   prediction switching).
   - It conflicts with step 5. Fair contact judges a hit against where you *saw* the enemy, at
     your render tick. If we drew near enemies at an extrapolated "present", what you see would
     be a guess the host can't rewind to, and fairness would break.
   - With step 5, an enemy that touches you on your screen hits you, and one that doesn't,
     doesn't. That is the complaint.
   - Cost: enemies look about 120 ms "behind" to a 160 ms player, which makes Waves very
     slightly easier for laggy players. That is acceptable in co-op.
   - Revisit only if playtests say enemies feel "floaty".
2. **Pre-input forwarding** (DDNet) and extrapolating other players in Gun Game. Same
   conflict: shooter-favoured lag compensation rewinds to the shooter's render tick
   (`InputCommand.view_tick`), so drawing players ahead would make hits miss what you aimed at.
3. **Full rollback** (GGPO, ggrs, snopek's godot-rollback-netcode, netfox). It needs a
   deterministic re-simulation of every enemy about 10 ticks back on every correction. That
   is too expensive for 40+ GDScript enemies at 60 Hz, and a rewrite of the netcode.
4. **Letting the victim's client decide damage** (PizzaClientLagFix, Hunt). It breaks rule 1.
   Judging on the victim's timeline on the host gives the same fairness.
5. **Predicting kills or death bursts.** A wrong "enemy died" is much worse than a late one.
   Death bursts stay host-driven (`FeedbackSystem.EVENT_DEATH`).

---

## 5. How the work is organised

**The user's rule: every step is finished and tested locally before anything is pushed.**
That works alongside "one issue, one branch, one PR" like this:

1. Start from fresh `origin/main` (`git fetch`, then `git switch -c latency/1-lag-lab origin/main`).
   Never carry unrelated local changes. A modified `project.godot` must not come along: check
   `git status` first.
2. Each step gets its own branch, **stacked** on the previous one:
   - `latency/1-lag-lab`
   - `latency/2-policy`
   - `latency/3-predicted-hits`
   - `latency/4-incoming-bullets`
   - `latency/5-fair-contact`
   - `latency/6-scheduled-shots`
   - `latency/7-sweep-docs`
   Commit each step on its branch once its own checks pass.
3. **Nothing is pushed** until step 7 is done and the final verification (section 7) passes on
   the top branch.
4. Then, after the user OKs it:
   - Create one GitHub issue per step.
   - Push all the branches.
   - Open the PRs in order, each based on the previous branch, with `Closes #N`, before/after
     metrics and the `full-checks` label where section 7 says so.
   - Merge them bottom-up. Retarget each next PR to `main` after its base merges.
5. If a later step changes an earlier step's code, fix it **on the earlier branch** and rebase
   the stack (`git rebase --update-refs`), so each PR stays self-contained.

Before starting, mention to Alex/Yusuf that steps 2 and 5 touch `autoloads/` and the mode base
class (CLAUDE.md: "say what you're about to change").

---

## 6. The steps

Each step lists: why, design, files, Waves vs Gun Game, network format, tests, agentic
checks, done when. Keep functions under about 40 lines, static types everywhere, numbers in
`.tres`.

### Step 1: Lag lab (measure before changing anything)

**Why:** every later step must show before/after numbers that target exactly what Yusuf
feels. Build the measuring tool first, as the roadmap did with the wave report.

**Adds:**
- **Smoke scenario I, "Waves at 160 ms"** (`tests/net/waves_fairness.gd`, modelled on
  `tests/net/fairness.gd`). The host runs a quick Waves match (a new
  `tests/net/data/fair_waves_match.tres`, no schedule spawning, as H does with Gun Game). A
  client joins with simulated latency. The client strafes (0.5 s walk, 0.5 s stand, as H does)
  and fires at the nearest enemy all the time.
  - The host spawns 3 melee runners (`enemies/data/runner.tres`), one `test_spitter.tres`,
    and one new test volley enemy `tests/net/data/test_volley.tres` (windup 0.4 s, 5 pellets,
    40°).
  - Enemies get very high health (`max_health` near 60000 in the test data), not
    `invulnerable`, so hits still drop health and play feedback.
  - The client player must not die but must take damage. `HealthComponent.take_damage`
    ignores damage while `invulnerable`, so the host script refills the client's health every
    frame with `set_health(max)` instead.
  - The host player and bots are removed from `living_players`, as in H, so enemies hunt only
    the client.
- **The client latency becomes an argument.** H calls `configure_simulator(80, 0, 0.0)` hard
  coded. Read it from `_args[2]` (the role's `Sim` string, `"80,10,0"` = latency, jitter,
  loss), defaulting to 80/0/0. Do this for both H and I, so the step-7 sweep can reuse them.

**Metrics** (printed as `FAIRNESS METRIC name value`; I uses the label `WAVEFAIR`):

| Metric | How it's measured | Today (expected) | Budget after the plan |
|---|---|---|---|
| `hit_feedback_ms` p50/p95 | Client: time from our PREDICTED bullet finishing with a hit on an enemy (connect to `Bullet.finished` via `Projectiles` `child_entered_tree`) to the first enemy-hit sound or effect for it (`EventBus.damage_seen` today, `hit_predicted` after step 3). | about 200 / 260 | ≤ 20 / 35 (one frame) |
| `predicted_confirm_share` | Share of predicted hits the host confirmed (`ProjectileSystem.hit_confirmed` for the same shot key) | n/a | ≥ 0.90 |
| `bullet_visible_share` | For every enemy bullet that hit us: where *we drew* that bullet at our own tick `end_tick` vs where our player was then. Record the REMOTE bullet positions every physics frame, by shot key and `round(server_tick_now())`. Visible = within `ON_PLAYER_DISTANCE` (33 px). | low for close shots | ≥ 0.85 |
| `melee_fair_share` | For every melee hit on us: did the enemy we *drew* touch our player at the judged tick? Needs the host to say which tick and which enemy. See the note below this table. | low (expect < 0.5) | ≥ 0.85 |
| `melee_gap_px` p50/p95 | Distance between the drawn enemy's edge and our hitbox at those hits | about 45 / 60 | ≤ 5 / 12 |
| `hurt_feedback_ms` p50 | Time from the moment a hit was visible on our screen to our hurt sound | about RTT | ≤ 20 for bullets (step 4) |

**How the host reports melee hits in the test, before step 5 exists:**
- The host script connects to the client player's `HealthComponent.damaged`.
- On damage with no bullet that tick, it records the enemy that was touching. For each enemy,
  check whether the client hitbox is in its `ContactArea.get_overlapping_areas()`.
- It also records `player.timeline.newest_tick()`, the client's own tick at that moment.
- It sends `(tick, enemy net_id)` to the client with a test-only NetChannel event on a topic
  no game code uses (for example 200). Note in the script that the topic is test-only.
- The client compares that with its own records (own hitbox centre by its own tick, and every
  drawn enemy's position by its own tick).
- After step 5, the host sends the judged tick from the real contact hit instead.

**Files:**
- `tests/net/waves_fairness.gd`, `tests/net/data/fair_waves_match.tres`, `tests/net/data/test_volley.tres`
- `tests/net/run_smoke.ps1`: add scenario I. Use `Alone = $true` (it measures timing),
  `Metrics = "WAVEFAIR"`, roles `waveshost` and `wavesclient "80,0,0" -Late`. Add a header line.
- `tests/net/fairness.gd`: read `Sim` from the arguments, and add `hit_feedback_ms` for the
  client's shots at bots. Bots get very high health the same way.
- `tools/check_scope.json`:
  - add `"I"` to `scenarios`
  - add `"I"` to `enemies/`, `weapons/`, `shared/feedback/` (and `"H"` there too),
    `modes/wave_mode` and `modes/data/`
  - add `"tests/net/waves_fairness.gd": ["I"]`
- `CLAUDE.md` (Commands section) and the `run_smoke.ps1` header: mention I.

**Budgets:** in step 1 the scenario only *prints* the new metrics; it doesn't fail on them. Each
later step switches on the check for its own metric (set the constant `MIN_...`), so the
budget hardens step by step and a regression fails the smoke.

**Agentic check (Claude does this):**
- Run `.\tools\check.ps1 -Smoke -Scenarios H,I` three times.
- Save the metric lines to the scratchpad as the **baseline**. Every later PR pastes the
  baseline next to its own numbers.
- If a metric is noisy by more than 10% between runs, lengthen `PLAY_SECONDS` before going on.
  A metric that can't tell good from bad is useless.

**Done when:** H and I pass (as smoke runs) on unchanged game code, and the baseline table
exists.

### Step 2: Latency policy per mode (no behaviour change)

**Adds:**
- `shared/network/latency_policy.gd` (`class_name LatencyPolicy extends Resource`), with every
  field from section 3 and `@export` doc comments.
- `shared/network/default_latency_policy.tres` (everything off).
- `modes/data/waves_latency.tres` and `modes/data/gun_game_latency.tres` (values from
  section 3; any switch whose step isn't built yet stays off).
- `GameMode` gets `@export var latency_policy: LatencyPolicy`. `_ready()` (every peer, before
  the client early-return) calls `NetworkManager.use_latency_policy(latency_policy)`.
  `_exit_tree()` calls `NetworkManager.use_latency_policy(null)`, and null means the default.
- `autoloads/network_manager.gd`: `var latency_policy: LatencyPolicy` (the default at start)
  and `use_latency_policy()`.
- Both mode scenes (`modes/wave_mode.tscn`, `modes/gun_game/gun_game_mode.tscn`) set the
  export. **Minimal `.tscn` diff:** one `ext_resource` and one property line each. Explain it
  in the PR.

**Tests:** `tests/shared/network/test_latency_policy.gd` (see section 3), plus a test that
the policy is set after a mode enters the tree and back to the default after it leaves.

**Checks:** autoloads changed, so this is a **big change**. Run `.\tools\check.ps1 -Smoke`
(all scenarios) once. H and I numbers must equal the baseline (no behaviour change).

**Done when:** both modes carry their policy and nothing plays differently.

### Step 3: Predicted hit feedback (fixes "sounds are late")

**From the examples:** DDNet `cl_predict_events` plus the `CheckPredictedEventHandled` dedup;
Soldat's client-side hit sounds; Overwatch "predict by default".

**Design:**
1. **Bullet:** in `Bullet._hit` with mode PREDICTED, emit a new signal
   `hit_predicted(bullet, at, hitbox)` before stopping. Only the shooter's own PC has
   PREDICTED bullets, so only the shooter is affected.
2. **ProjectileSystem** (client): on that signal, if
   `NetworkManager.latency_policy.predict_hit_effects` is on, emit
   `EventBus.hit_predicted(shot_ref, at, target)`, where `target` is the hitbox's owner node.
3. **A pure dedup class** `shared/feedback/predicted_hits.gd`
   (`class_name PredictedHits extends RefCounted`), our version of DDNet's predicted-event list:
   - `add(shot_key: String, target_id: int, now: float)`
   - `confirm(shot_key: String) -> bool`: the host's `hit_confirmed` for this shot.
   - `consume(target_id: int, now: float) -> bool`: true if an unexpired predicted hit on this
     target is waiting. It removes the oldest. The host's health-drop feedback then skips its
     sound.
   - `expire(now: float) -> Array[String]`: removes entries older than
     `predicted_hit_seconds` and returns their keys, which count as mispredictions for the
     metric.
   - Target ids: an enemy's `NetEntity.net_id`, or a player's `peer_id`. Take care that the
     two can't collide (enemy net ids and peer ids come from different spaces). Use a tagged
     id, or keep two dictionaries.
4. **FeedbackSystem:**
   - On `hit_predicted`: play `enemy_hit` (enemies) or a player-hit cue at the hit point at
     once. Ask the target's `HitFeedback` to flash now (add a public `flash()`).
   - When a host-driven `damage_seen` comes for that target and `PredictedHits.consume()` says
     a prediction covered it, show the damage number but **don't play the sound again**.
   - `damage_seen` needs the target to do this. Extend it to
     `damage_seen(target: Node2D, at: Vector2, amount: int, big: bool)`. Update every emitter
     and listener (`grep -rn damage_seen`), and the EventBus docs.
   - `HitFeedback` must also not flash a second time within the flash length.
5. **Mispredictions:** nothing to undo (the sound already played; Overwatch accepts this).
   Count them for the metric. If the confirm share falls below 0.9 in a mode, that mode turns
   `predict_hit_effects` off in its `.tres` until it is fixed.

**Waves vs Gun Game:** both turn it on. Targets are enemies in Waves and players and bots in
Gun Game. `predict_damage_numbers` stays off in both, so numbers keep the host's real value.

**Network format:** none. It uses the existing `EVENT_HIT` and the shot key. No
`Handshake.PROTOCOL` bump.

**Tests:**
- GUT `tests/shared/feedback/test_predicted_hits.gd`:
  - add/confirm/consume/expire
  - two pellets of one trigger pull on the same target are consumed one at a time
  - an expired entry isn't consumed
  - player and enemy ids don't collide
- GUT `tests/weapons/test_bullet.gd`: a PREDICTED bullet that hits emits `hit_predicted`
  once; an AUTHORITATIVE or REMOTE one never does.
- Smoke: turn on the budgets for `hit_feedback_ms` (I and H) and `predicted_confirm_share`.

**Checks:** `.\tools\check.ps1 -Changed` (it picks A, B, C, D, E, H, I from `weapons/` and
`shared/feedback/`).

**Done when:** `hit_feedback_ms` p50 ≤ 20 ms and the confirm share is ≥ 0.9 in H and I,
compared against the baseline.

### Step 4: Incoming bullets drawn honestly, and instant hurt sounds

**From the examples:** Soldat's instant fast-forward (`for c := 1 to pa`); DDNet's predicted
damage indicators.

**Design:**
1. **Catch-up that finishes before arrival.** Today `Bullet.display_tick()` blends from the
   render tick to the present over a fixed 0.2 s. Instead, compute how many ticks the bullet
   needs to reach the point on its path closest to our player:
   `reach_ticks = shot.origin.distance_to(closest) / speed_per_tick`. Then:
   - Catch up over `min(CATCH_UP_SECONDS × tick_rate, reach_ticks × 0.5)` ticks.
   - When `snap_close_threats` is on and that is under 2 ticks, draw it at
     `server_tick_now()` straight away (Soldat). It pops in a few pixels out from the muzzle,
     which is the honest place.
   - Keep `display_tick` pure and give it the extra argument, so the GUT test covers it.
2. **Predicted own hurt** (`predict_own_hurt`). This is only for shots with a negative shooter
   id (bots and enemies, which fair dodging judges on our own timeline):
   - When a REMOTE bullet drawn at the present overlaps our own hitbox, emit
     `EventBus.local_player_hurt(from_direction)` at once. That gives the hurt sound and
     direction marker. Remember the shot key.
   - When the host's `EVENT_HURT` comes for that key, don't emit again. If it never comes
     within `predicted_hit_seconds`, count a misprediction.
   - **`EVENT_HURT` must name the shot** for this: add shooter id (i32) and shot id (u32) to
     its payload in `ProjectileSystem._tell_victim` and `_on_event_received`.
     **Bump `Handshake.PROTOCOL`.** Update `tests/net/fairness.gd`, which parses `EVENT_HURT`,
     and the garbage-input test for the decoder.
   - Health still changes only from the host's snapshot.

**Waves vs Gun Game:** both turn both switches on. In Gun Game only bots' bullets are
affected: human bullets have shooter ids ≥ 0, are lag-compensated, and keep the 0.2 s smooth
catch-up and the host-only hurt.

**Tests:**
- GUT `tests/weapons/test_tier1_latency.gd`:
  - a close bullet's catch-up ends before it reaches the player
  - a far bullet still gets the full 0.2 s
  - the snap happens under 2 ticks
- GUT: `EVENT_HURT` encode/decode round trip with the shot key; a garbage case in
  `tests/shared/network/test_garbage_input.gd`.
- Smoke: turn on `bullet_visible_share` ≥ 0.85 (I and H) and `hurt_feedback_ms` p50 ≤ 20 for
  bullets. The existing H `fair_share` and `enemy_fair_share` must not drop.

**Checks:** `.\tools\check.ps1 -Changed`.

**Done when:** in I at 160 ms, at least 85% of the enemy bullets that hit the client were
visibly on it in the client's own drawing, and the hurt sound comes on the same frame.

### Step 5: Fair contact (fixes "melee hits from a distance")

**From the examples:** our own fair dodging (`TimelineHits`) applied to melee; the
victim-side judging of PizzaClientLagFix, Hunt and Destiny, but decided on the host; the
Darktide complaints as the counter-example.

**What the host already has:**
- `InputCommand.view_tick`, the server tick the client was *drawing* when it made that input:
  its render tick.
- `InputCommand.client_tick`, its view of the present (the timeline stamp).
- `LagCompensator` records every hitbox's centre every tick, **enemies included**: each
  `HitboxComponent` registers itself.

So no new client data is needed.

**Design:**
1. `PlayerTimeline.record()` also stores the command's `view_tick` for each stamp. Clamp it to
   `[stamp - victim_rewind_ticks, stamp]`, since it comes from the client.
   - Add `view_at(tick: int) -> float`.
   - `Player` passes `command.view_tick` along with `client_tick` where it calls `record`.
   - Size the history from `victim_rewind` (the larger of it and `max_rewind`).
2. `LagCompensator`: add `position_at(hitbox, tick) -> PositionHistory.Place`, a public
   wrapper around `_place_at`. The history capacity must cover `victim_rewind`.
3. A pure class `enemies/contact_judge.gd` (`class_name ContactJudge`):
   `touches(enemy_center, contact_radius, player_center, player_radius) -> bool`. Read
   `contact_radius` from the `ContactArea` shape, scaled by `body_scale` like
   `_scale_body()`. Check the shape is a `CircleShape2D`; if it isn't, this needs a different
   test.
4. `ChaserEnemy._touching_hitboxes()` when `NetworkManager.latency_policy.fair_contact` is on:
   - For every player hitbox in `Groups.LIVING_PLAYERS` whose player has a `timeline` (remote
     humans):
     - `t = timeline.newest_tick()`, `v = timeline.view_at(t)`
     - the enemy's centre at `v` from `LagCompensator.position_at(own hitbox, v)`
     - the player's centre at `t` from `timeline.history`
     - touching = `ContactJudge.touches(...)`
   - The host's own player and bots keep the `Area2D` overlap. The host's own player is drawn
     with `DisplayDelay`, so test it against the enemy `host_view_delay_ticks` back for
     consistency.
   - Off → exactly today's code.
5. `MeleeAttack.perform`: compute the push from the same judged positions (pass them in, or
   pass a small `Contact` object instead of a bare hitbox list).
   - `EnemyAttack.perform()`'s signature is shared by every attack. If it changes, update every
     subclass and `tests/enemies/test_enemy_behaviours.gd`.
6. **Tell the victim** (this also fixes "melee gives no hurt marker or sound"):
   - On a contact hit, the host emits `EventBus.contact_hit(victim_peer_id, from_direction, judged_tick)`.
   - `ProjectileSystem` (which already sends `EVENT_HURT`) listens and sends `EVENT_HURT`
     with a source kind byte (bullet/contact) and the judged tick.
     **Bump `Handshake.PROTOCOL`.**
   - Smoke I switches from its test-only topic to this real event.
7. **Verdict delay:** the host can judge tick `t` only once the input for it arrives, about
   one-way plus queue after it happened on the client's screen. The hit lands about one RTT
   after the visible contact. Damage being late is fine. An instant hurt sound would need the
   client to know the enemy's attack cooldown, which isn't replicated. That is a possible
   follow-up (5b below), only if the metric or the playtest says the hurt sound is too late.

**Waves vs Gun Game:** Waves on. Gun Game off: it has no contact attacks today, and if it
gets some it must opt in through its policy.

**Cheating note:** a client could send old `view_tick`s to be judged against older enemy
positions. It is clamped to `victim_rewind` (0.3 s), and in co-op nobody gains from it. Write
this in `docs/NETCODE.md`.

**Tests:**
- GUT `tests/enemies/test_contact_judge.gd`: touching, just apart, scaled boss radius.
- GUT `tests/player/test_player_timeline.gd` (or the existing timeline test file):
  - `view_at` is clamped to `victim_rewind`
  - a future `view_tick` is clamped to the stamp
- GUT: `_touching_hitboxes` with the policy on picks the player when the rewound enemy
  touches them and skips them when only the present enemy does. Build a tiny tree with a
  `LagCompensator` and a timeline; `tests/weapons/test_tier1_latency.gd` shows how to make
  hitboxes in tests.
- Smoke: turn on `melee_fair_share` ≥ 0.85 and `melee_gap_px` p95 ≤ 12 in I.
- **Stress F must stay within budget.** This adds a history sample per enemy per remote player
  per tick. Only enemies whose attack is off cooldown need the test: check
  `_attack_cooldown_left` first, so the cost stays small.

**Checks:** `.\tools\check.ps1 -Changed` (C, F, H, I from `enemies/`; all from `player/`).
`player/` is in the list, so this is a big change: run `-Smoke` once at the end of the step.

**Done when:** melee hits on a 160 ms client happen only when the enemy visibly touched it on
its own screen, at least 85% of the time, with F in budget.

**5b (optional, only if needed):**
- Replicate one "ready to strike" bit per enemy. `EnemyNetState`'s status uses 2 bits and the
  telegraph 6, so this needs a layout change, a `PROTOCOL` bump and an `EnemyNetState.SIZE`
  change.
- The client then predicts the hurt sound on first visible contact with a ready enemy.
- Measure the confirm share; below 0.9, drop it.

### Step 6: Scheduled wind-up shots (fixes boss pellets "from nowhere")

**From the examples:** Halo Reach hides about one RTT inside the wind-up (Armor Lock's delay
shortened by the RTT; the grenade throw animation plays while the host creates the grenade).

**Today:**
- Bosses (`enemies/data/bosses/*.tres`) have windups of 0.5–1.5 s before `VolleyAttack`
  fans and rings.
- `ChaserEnemy._attack()` picks the aim only when the windup ends, in `perform`. Clients learn
  about the bullets only when `EVENT_FIRED` arrives, one-way later, already in flight.
- Normal ranged enemies (Shooter, test spitter) have no windup. Step 4 covers those.

**Design:**
1. With `schedule_windup_shots` on, an attack with `windup ≥ aim_lock_seconds` **locks its
   aim** `aim_lock_seconds` before it fires:
   - At that moment the host builds the volley's shots exactly as `perform` would (same
     directions, origins and shot ids), with `fire_tick` in the future.
   - It sends them to every client as `EVENT_SCHEDULED` (a new kind in `ProjectileSystem`'s
     topic 1, payload = the shots' existing `Shot.encode`).
   - At `fire_tick` the host fires those same shots. They are kept on the enemy between the
     lock and the fire.
   - If the enemy dies before firing, the host sends `EVENT_ENDED` for each, so no bullet is
     left hanging on a client.
2. A client spawns REMOTE bullets from `EVENT_SCHEDULED` that **stay hidden until
   `server_tick_now() ≥ fire_tick`**, then are drawn at the present, with no catch-up. It
   ignores the later `EVENT_FIRED` for the same keys; the host doesn't need to send them.
3. While locked, the enemy **stands still**. Otherwise the shots leave from where it was, not
   where it's drawn. It also **shows the aim** (a line per direction, drawn by
   `EnemyTelegraph`, looks only).
   - This is a small gameplay change: bosses aim 0.25 s earlier and plant their feet.
   - Ask Alex/Yusuf before merging, and note it in `docs/PROGRESS.md`.
   - Difficulty scores don't use aim, so the wave report doesn't change. Paste it anyway to
     show that.
4. `aim_lock_seconds` (0.25) must be ≥ one-way latency plus the smoothing buffer for the
   bullets to arrive in time. At 160 ms RTT that is about 80 + 40 ms. Above that, the client
   falls back to the step-4 behaviour automatically: the bullet arrives late and is drawn
   caught up.

**Waves vs Gun Game:** Waves only; Gun Game has no wind-up attacks.

**Network format:** new event kind. **Bump `Handshake.PROTOCOL`.** Add a garbage-input case
for the decoder.

**Tests:**
- GUT: lock time from windup and aim lock (pure function on `EnemyAttack`, for example
  `lock_left(windup_left) -> float`); the locked shots equal the fired shots (same seed, ids,
  directions).
- GUT `tests/weapons/test_bullet.gd`: a scheduled REMOTE bullet is hidden before `fire_tick`
  and on the present timeline after.
- Smoke I: give the test volley enemy windup 0.4 and check `bullet_visible_share` for volley
  hits separately (`volley_visible_share` ≥ 0.95). Its bullets should be perfectly visible.
- Smoke C (wave loop) must still pass. It uses bosses in `combo_*` data where they appear.

**Checks:** `.\tools\check.ps1 -Changed`.

**Done when:** at 160 ms, every boss pellet that hits the client was drawn on it, and the
pellets leave the boss's drawn muzzle.

### Step 7: Lag sweep, docs, and the people test

**Agentic lag sweep (Claude runs this, it doesn't go in CI):**
- Run scenarios H and I with client latency 0, 40, 80, 125 and 160 ms each way (RTT 0–320),
  with 10 ms jitter.
  - `run_smoke.ps1` takes the role `Sim` from the scenario table, so add a
    `-ClientSim "125,10,0"` parameter that overrides the client role's `Sim` for H and I.
    Parameter only, no new scenario.
- Make a table: every metric × every latency. It shows where fairness breaks. Expect it near
  render delay ≈ `victim_rewind`, about 250–300 ms RTT.
- Put the table in `docs/NETCODE.md` under "Known limits", with the date, so the limit is
  written down instead of guessed.

**Docs** (same PR):
- `docs/NETCODE.md`:
  - "Shooting": predicted hit effects, close-threat snapping, scheduled shots
  - a new "Contact attacks" paragraph
  - the policy table from section 3
  - "Known limits": the sweep table, and the cheating note from step 5
- `weapons/CLAUDE.md`, `shared/network/CLAUDE.md`, `modes/CLAUDE.md` (the policy per mode),
  and the `add-enemy` recipe. A melee enemy now gets fair contact for free; a new attack type
  must use `ContactJudge` for contact.
- `docs/PROGRESS.md`: the feature and the limits.
- `tests/test_guides.gd` checks every path these name.

**People test (needs Alex + Yusuf, Claude can't do it).** Over the real internet, Yusuf
joining Alex's host. Fill this in and paste it into the step-7 PR:
- [ ] F3 shows his ping and the render delay. Note both.
- [ ] Shooting an enemy: the hit sound comes the moment the bullet lands.
- [ ] Standing still next to a Runner, then stepping away: no hit once it is visibly apart.
- [ ] Dodging a Shooter's bolt at the last moment: no damage when it visibly missed.
- [ ] A boss fan at wave 10: the aim lines show, and pellets that miss on screen don't hurt.
- [ ] Gun Game vs bots: hit sounds instant, bot bullets honest, nothing feels worse than before.
- [ ] Anything that now feels *wrong* (a sound for a hit that didn't happen, enemies feeling
  "floaty"): write it down. That decides 5b and whether section 4, item 1 is ever revisited.

**Optional agentic visual check** (computer use, if allowed):
- Claude starts two windowed instances: `-- --host`, and `-- --join 127.0.0.1 --net-sim 80,10,0`.
- It takes screenshots of the client with F3 open during a wave, to confirm there are no
  errors and the overlay numbers match the sweep.
- It can't judge feel. Don't count it as the people test.

---

## 7. Final verification on the top branch (before anything is pushed)

Run in this order. Stop at the first failure and fix it on the branch where the bug lives.

1. **No smoke test may already be running** (another session or a game window). Two at once
   give false failures, and a stray Godot process skews F/G/H/I. Close the editor too.
2. `.\tools\check.ps1`: import, GUT, lint, format.
3. `.\tools\check.ps1 -Smoke`: every scenario A–I. Autoloads, player and netcode changed, so
   the full set is required.
4. `.\tools\check.ps1 -Smoke -Scenarios H,I` twice more. The new budgets must hold every time.
   Timing scenarios (F, G, H, I) can fail by a little with other programs open. If one does,
   say so and let CI decide; never loosen a budget for it.
5. Soak: `.\tools\check.ps1 -Smoke -Scenarios S` (10 min). The `PredictedHits` and scheduled
   shot lists must not grow without limit.
6. `.\tools\wave_report.ps1` before and after: identical (no balance change), pasted into
   the step-6 PR.
7. The baseline vs after metric table for H and I, and the lag-sweep table.
8. The people test checklist (step 7), filled in by Alex + Yusuf.

Then ask the user before pushing: list the branches, the issue titles and the PR order. On a
yes, follow section 5, item 4. PRs that touch `autoloads/`, `player/`, `shared/network/` or the
mode base class (steps 2, 4, 5, 6) get the `full-checks` label.

## 8. Testing cost, so it stays efficient

| Step | GUT (seconds) | Smoke while working | Smoke before commit |
|---|---|---|---|
| 1 Lag lab | guides test | `-Scenarios H,I` | `-Changed` |
| 2 Policy | policy test | none needed | `-Smoke` (autoload: all, once) |
| 3 Predicted hits | dedup, bullet | `-Scenarios I` then `H` | `-Changed` |
| 4 Incoming bullets | display tick, hurt payload, garbage | `-Scenarios I,H` | `-Changed` |
| 5 Fair contact | judge, timeline, touching | `-Scenarios I`, then `F` | `-Smoke` (player: all) |
| 6 Scheduled shots | lock, hidden bullet, garbage | `-Scenarios I,C` | `-Changed` |
| 7 Sweep and docs | guides test | sweep (about 10 runs × 40 s) | full section 7 |

Rules that keep it fast and on target:
- Put logic in pure classes (`PredictedHits`, `ContactJudge`, `display_tick`, lock timing)
  and test it with GUT in milliseconds. Use smoke tests only for what needs two real peers
  and latency.
- H and I are the only scenarios that *measure* what Yusuf feels. While working on a step, run
  just them, never the whole set.
- Each metric's budget is switched on in the step that fixes it. Every step therefore proves
  its own fix and guards the earlier ones.
- If a smoke metric is noisy, lengthen its play time rather than loosening the budget.
