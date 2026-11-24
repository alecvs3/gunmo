# Roadmap

What's left, in order. `docs/PROGRESS.md` records what is done; this file is what comes next.
Every step is one GitHub issue, one branch and one PR (`Closes #N`), merged before the next
starts. No new guns in any of these steps: guns are added one at a time, separately.

| Milestone | What | Status |
|---|---|---|
| Hardening | rate limits, garbage-input test, soak test (#47) | merged |
| **M7 Content** | the old M7 (waves to 25), M8 (Gun Game complete) and M9 (maps) together | in progress (steps 1–6 done) |
| M5 Server hosting | Linux builds (#48), dedicated match loop, systemd + `SERVER.md` | later |
| M6 Lobby | mode/map picker, ready-up, countdown, results → lobby, rejoin (#46), settings (#49) | later |
| M10 Feel | sounds (#2), hit marker, VFX, real art (#1, needs the art style decided) | later |
| M11 Release | performance (#43), onboarding, release builds and store (needs the platform decided) | later |

## M7 Content: the steps

Each step lists what it adds, how it is tested, and when it is done. The order matters:
measuring tools first, then the systems that combine, then the content built on them, then
balance at the end, when everything that affects balance exists.

### 1. Wave report (measuring tool) ✅ (#84)
- **Adds:** `tools/wave_report.ps1` + a headless script that prints, for waves 1–25: budget,
  enemies by type, total enemy health, modifiers, and peak enemies alive. Pure numbers, no window.
- **Test:** a GUT test that the report's numbers match `WaveBudget`/`WaveSpawner` for a small
  schedule, and that every wave of the default schedule can be spent (no wave with zero enemies).
- **Done when:** one command shows the whole difficulty curve. Every later step that changes
  balance pastes its before/after report into the PR.

### 2. Enemy behaviours as parts ✅ (#88)
- **Adds:** `EnemyData` gets a movement behaviour and an attack behaviour (Resources), so an
  enemy type is a combination instead of new code. Today's grunt, runner and brute become
  combinations of "chase" + "melee". No behaviour change.
- **Test:** existing enemy tests pass unchanged; a GUT test per behaviour (pure decision:
  given positions, what does it want to do).
- **Done when:** adding an enemy type is a `.tres` file plus at most one new behaviour.

### 3. Enemy projectiles ✅ (#90)
- **Adds:** a ranged attack behaviour that fires through `ProjectileSystem` on the enemy team.
  Fair dodging (`TimelineHits`) already covers bots' bullets; extend it to enemy bullets.
- **Test:** GUT for the attack timing and aim lead; extend smoke **H** (fairness) so a lagged
  client dodging an enemy shot is not hit; smoke **F** (stress) with ranged enemies must stay in
  budget. Bump `Handshake.PROTOCOL` if an event format changes.
- **Done when:** a ranged enemy shoots fairly for a 160 ms client.

### 4. Enemy roster, part 1: roles ✅ (#92)
- **Adds:** Shooter (keeps distance, fires), Tank (slow, armored, resists knockback), Swarmer
  (cheap, fast, comes in groups). Each is a `.tres` with a cost; added to the schedule's types.
- **Test:** data test that every `EnemyData` is valid (cost > 0, health > 0, has behaviours);
  wave report before/after; smoke **C** still wins and loses as before.
- **Done when:** waves 6+ mix frontline, ranged and swarm enemies.

### 5. Enemy roster, part 2: enemies that change other enemies ✅ (#94)
- **Adds:** Splitter (dies into two small ones) and Support (heals or shields enemies near it).
  These make the fight about which target to kill first.
- **Test:** GUT for split counts (and that splits don't count twice toward the wave being
  cleared) and for the heal/shield amounts and range; smoke **C** with a schedule that uses both.
- **Done when:** a wave with a Support is noticeably harder unless the Support is focused.

### 6. Modifiers that stack ✅ (#96)
- **Adds:** late waves get 2–3 modifiers at once (armored + regenerating + fast), with rules for
  which combine; the HUD shows the wave's modifiers when it starts.
- **Test:** GUT for stacking math (order doesn't matter, caps hold) and for which waves get how
  many modifiers; snapshot round trip if the HUD needs a new `MatchNetState` field
  (`add-networked-field` recipe).
- **Done when:** the wave report shows modifier combinations from wave 16 on.

### 7. The wave curve to 25
- **Adds:** composition rules per wave (shares of frontline / ranged / swarm / support), the
  budget curve, and a higher `max_alive` if the stress test allows it.
- **Test:** wave report (the curve must rise every wave, no spikes); smoke **F** raised to the
  new `max_alive` with the new enemy mix must stay within its budgets; soak **S** (10 min) once.
- **Done when:** the numbers look right on paper and stress/soak pass at the new peak.

### 8. Bosses at waves 10, 20 and 25
- **Adds:** a boss framework (phases by health, telegraphed attacks, boss health bar on the HUD)
  and three bosses. Wave 25's boss is the final fight; beating it wins.
- **Test:** GUT for phase changes and attack schedules (pure); a quick-schedule smoke in **C**
  that reaches a boss wave and wins; protocol bump if a state layout changes.
- **Done when:** each boss can be beaten by 2 players and has at least 2 phases.

### 9. Downed and revive (co-op)
- **Adds:** players at 0 health go down instead of dying; a teammate holds a key nearby to
  revive; a bleed-out timer; everyone down = defeat. Host decides everything.
- **Test:** GUT for the revive timer, range and interruption; a new smoke check in **C**: client
  goes down, host revives them, both sides agree.
- **Done when:** a downed player can be revived over the network with simulated lag.

### 10. Bots in co-op
- **Adds:** `BotBrain` decisions for Waves: target the most dangerous enemy, stay near the team,
  revive downed players, spend credits by simple rules between waves.
- **Test:** GUT for every new decision (pure `BotBrain`); a smoke scenario where 1 human + 3
  bots clear a quick schedule.
- **Done when:** bots are useful teammates, not just targets.

### 11. Smarter bots (both modes)
- **Adds:** dodging incoming bullets, moving toward a goal (cover, flanking, pickups) instead of
  roaming between spawns, aiming from the barrel instead of the body's center.
- **Test:** GUT for the dodge and goal choice; smoke **E** still produces a winner; compare bot
  hit rate before/after in the PR.
- **Done when:** a hard bot beats a medium bot most of the time in Gun Game.

### 12. Gun Game polish
- **Adds:** spawn protection (short, ends when you fire), a kill feed, a different character per
  player, and a results screen at the end.
- **Test:** GUT for spawn protection rules and character assignment; smoke **E** checks both
  sides see the same kill feed entries and results.
- **Done when:** a Gun Game match reads clearly from start to winner.

### 13. Maps: the framework
- **Adds:** maps as data (spawn points per mode, enemy spawn zones, bot points of interest) and
  a map choice in `MatchSettings` (the lobby picker comes in M6).
- **Test:** an automatic map check for every map: every spawn point is on the navigation mesh
  and every one can reach every other one; no spawn inside a wall.
- **Done when:** `test_arena` passes the check and a second map can be added without code.

### 14. Two new maps
- **Adds:** one co-op map with chokepoints and open areas, one compact free-for-all arena.
- **Test:** the map check; smoke **C** and **E** run on each new map.
- **Done when:** both maps are playable in both modes.

### 15. Balance and playtest pass
- **Adds:** tuning only (`.tres` files): enemy numbers, costs, modifiers, boss health, credits.
- **Test:** wave report, soak **S**, and two real playtests (Alex + Yusuf) of a full run to wave
  25, notes in the PR.
- **Done when:** a full run is winnable by 2 players who play well and loses for ones who don't.

## How testing stays fast and useful
- **Every PR:** `.\tools\check.ps1` (import, GUT, lint, format; about a minute).
- **Network changes:** add `-Smoke`. New checks go into the existing A–E scenarios where they
  fit (those run in parallel), so the smoke test stays around 2 minutes.
- **Pure logic is unit-tested:** budgets, composition, stacking, phases, timers and bot
  decisions live in pure functions so GUT tests them in milliseconds.
- **Performance:** smoke **F** (stress) for any step that adds enemies or projectiles; soak
  **S** (`-Scenarios S`, 10 min) at steps 7 and 15.
- **Feel needs people:** steps that change how the game plays end with a short 2-instance
  playtest, and the PR says what was and wasn't tried in a real window.
