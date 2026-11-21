# gunmo

A 2D top-down multiplayer shooter in Godot 4.7.2, made by **Alex** (Dev A) and **Yusuf** (Dev B).
Two modes: co-op **Waves** and free-for-all **Gun Game** (with bots).

- What is built and what's next: [docs/PROGRESS.md](docs/PROGRESS.md)
- Project rules (also read by Claude): [CLAUDE.md](CLAUDE.md)
- Day-to-day work: the GitHub Projects board

## Getting started

Using Claude Code? Paste the prompt in [docs/ONBOARDING.md](docs/ONBOARDING.md) and it does all of
this for you. Otherwise:

1. Install **Godot 4.7.2** (standard build, not .NET). Exactly this version, so scene files don't flip back and forth.
2. Install **Git LFS** once: `git lfs install`
3. Clone and open `project.godot` in Godot.
4. For lint and format checks, install Python 3 and then: `pip install "gdtoolkit==4.*"`

## Checks before opening a PR

**One command for everything:** `.\tools\check.ps1` (import, tests, lint, format; about 15 s) or
`.\tools\check.ps1 -Smoke` (also the multiplayer smoke test, a few more minutes). It prints only
what failed and why. `-Fix` formats first; `-Only tests|lint|format|smoke` runs one step.
It finds Godot from `-Godot`, the `GODOT` environment variable, PATH, or `%LOCALAPPDATA%\Programs\Godot`,
`C:\Tools\Godot`, `~\Godot`, `~\Downloads`.

The individual steps, if you need them:

| What | How |
|---|---|
| Tests | In the editor: bottom panel **GUT** → Run All. Or headless: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` |
| Lint | `gdlint .` |
| Format | `gdformat --check .` (fix with `gdformat .`) |
| Multiplayer | Debug → Customize Run Instances → 2 instances, press Play, Host in one window, Join in the other |
| Multiplayer smoke test | `.\tests\net\run_smoke.ps1 -Godot <path to Godot *console* exe>` (or set `GODOT` once). Runs six scenarios: A lag and a wrong build, B dedicated server, C the wave loop, D the shop, E Gun Game with bots, F stress test with a performance budget (its numbers are printed). Every role must print PASS |

**Skip the menu while testing:** in Debug → Customize Run Instances, enable 2 instances and set the
launch arguments of instance 1 to `-- --host` and instance 2 to `-- --join 127.0.0.1`.
Both also accept a port: `-- --host 7778`, `-- --join 100.x.y.z:7778`.
Add `--net-sim 100,20,5` to any instance to fake 100 ms lag, ±20 ms jitter and 5% loss, and
`-- --dedicated` runs a server with no player of its own. How the netcode works:
[docs/NETCODE.md](docs/NETCODE.md).

**Smoothness check:** `godot --path . -s res://tests/visual/frame_pacing.gd` opens a window for a
few seconds and reports whether the view moves evenly every frame.

**Waves:** press **F** to ready up (the lobby and breaks end early when everyone is ready).
Kills and cleared waves earn credits; the shop opens in the lobby and between waves (**B** hides it).
`-- --match res://tests/net/data/quick_match.tres` hosts a quick 2-wave match for testing.
**Gun Game:** pick it in the menu before hosting, with how many players to fill up to with bots.
Every kill counts toward your current gun; enough kills move you to the next one, and the first
to finish the last gun wins. Hold **Tab** for the scoreboard (both modes). Your name (menu) is
shown above your player and on the scoreboard. `-- --match res://tests/net/data/quick_gun_game.tres`
hosts a short ladder with 2 bots.
**CI:** every PR runs lint, format, GUT and the smoke test on GitHub Actions (`checks`).

**In game:** the ping is in the top right (green/yellow/red), **F3** shows details for every
player, **Esc** opens Resume / Leave match.

## Playing together over the internet

The game uses ENet over **UDP port 7777** (changeable in the menu). One of you hosts, the other joins.

**Recommended: Tailscale** (free, no router setup)
1. Both install [Tailscale](https://tailscale.com) and sign in; the host invites the other to their tailnet
   (or both join the same account/tailnet).
2. The host clicks **Host**. The first time, allow Godot through the Windows Firewall when asked
   (Private networks is enough for Tailscale).
3. The joiner types the host's Tailscale IP (`100.x.y.z`, shown in the Tailscale app) and clicks **Join**.

**Alternative: port forwarding.** The host forwards UDP 7777 on their router to their PC and shares
their public IP. More setup and exposes a port, so prefer Tailscale.

**Both of you must run the same code.** The host checks every joiner's build id (a hash of all
scripts and scenes, shown with F3) and refuses a mismatch with a message that shows both ids. So:
pull the same commit, and commit or discard local changes (including scenes the editor re-saved)
before playing. Restart the game after pulling. To turn the check off while experimenting, untick
`require_matching_build` in `shared/network/default_network_config.tres`.

If a join fails, the menu says why (no answer, refused, older build...). Network events are also
logged as `[net hh:mm:ss] ...` lines in the Output panel and in `user://logs/godot.log`.

## How we work

- One GitHub issue → one branch (`m2/wave-budget`, ...) → one PR with `Closes #N`.
- The other person reviews the PR and tests it with the author (see above) before merging to `main`.
- Ownership: Alex — player, weapons, upgrades, gun game ladder. Yusuf — enemies, waves, bot AI,
  HUD and menus. Both — `autoloads/`, `shared/`, `modes/` base, `main.tscn`, `project.godot`.
- Avoid editing the same `.tscn` at the same time; say so on the issue first. Scene files merge badly.
