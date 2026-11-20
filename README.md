# gunmo

A 2D top-down multiplayer shooter in Godot 4.7.2, made by **Alex** (Dev A) and **Yusuf** (Dev B).
Two modes are planned: co-op **Waves** and free-for-all **Gun Game**.

- What is built and what's next: [docs/PROGRESS.md](docs/PROGRESS.md)
- Project rules (also read by Claude): [CLAUDE.md](CLAUDE.md)
- Day-to-day work: the GitHub Projects board

## Getting started

1. Install **Godot 4.7.2** (standard build, not .NET). Exactly this version, so scene files don't flip back and forth.
2. Install **Git LFS** once: `git lfs install`
3. Clone and open `project.godot` in Godot.
4. For lint and format checks, install Python 3 and then: `pip install "gdtoolkit==4.*"`

## Checks before opening a PR

| What | How |
|---|---|
| Tests | In the editor: bottom panel **GUT** → Run All. Or headless: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` |
| Lint | `gdlint .` |
| Format | `gdformat --check .` (fix with `gdformat .`) |
| Multiplayer | Debug → Customize Run Instances → 2 instances, press Play, Host in one window, Join in the other |

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

**Both of you must run the same commit.** Pull the branch you're testing before every session.
A mismatch usually shows up as nodes failing to spawn or "node not found" errors.

## How we work

- One GitHub issue → one branch (`m2/wave-budget`, ...) → one PR with `Closes #N`.
- The other person reviews the PR and tests it with the author (see above) before merging to `main`.
- Ownership: Alex — player, weapons, upgrades, gun game ladder. Yusuf — enemies, waves, bot AI,
  HUD and menus. Both — `autoloads/`, `shared/`, `modes/` base, `main.tscn`, `project.godot`.
- Avoid editing the same `.tscn` at the same time; say so on the issue first. Scene files merge badly.
