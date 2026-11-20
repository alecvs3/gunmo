# Onboarding: set up a new machine with Claude Code

Paste the prompt below into Claude Code, started in the folder where the project should go
(for example `Documents`). It installs the tools, clones the repo, runs the checks and explains the
project. It asks before every install and never pushes, merges or changes GitHub settings.

Before you start:
- You must be a collaborator on the repo, and `gh` (or Claude Code) is signed in to your GitHub account.
- To play together, the host shares their machine with you in the Tailscale admin console
  (Machines → the host's PC → Share), or invites you to their tailnet.
- If PR #3 is already merged, the prompt's branch step uses `main` instead of `m1-core`.

## The prompt

````text
I'm a developer on a 2-person Godot game project (Alex = Dev A, Yusuf = Dev B). Please get me fully set up and caught up. Ask me before each install, and stop and tell me if something fails instead of working around it. Do NOT push, merge, or change any GitHub settings.

Repo: https://github.com/alecvs3/gunmo (I'm already a collaborator).
Active branch: m1-core (Milestone 1, PR #3). If PR #3 is already merged, use main instead.

1. Check my OS and what's already installed: git, git-lfs, gh, python 3, Godot, Tailscale.
2. Install what's missing. On Windows use winget; on macOS use Homebrew.
   - Git (on Windows, Git for Windows already includes Git LFS)
   - GitHub CLI (gh)
   - Python 3, then: python -m pip install "gdtoolkit==4.*"
   - Godot **4.7.2 exactly**, standard build, not .NET. Don't use winget for Godot, because it may install a different version. Download the official build from https://github.com/godotengine/godot/releases/tag/4.7.2-stable (on Windows: Godot_v4.7.2-stable_win64.exe.zip). Unzip it to a permanent folder such as C:\Tools\Godot and tell me where it is. Also note the path of the _console.exe, so you can run headless commands.
   - Tailscale (Windows: winget install Tailscale.Tailscale; macOS: the App Store or brew install --cask tailscale). Don't sign in for me: start it and tell me to log in myself.
3. Run `git lfs install`. It must happen before cloning, or the image files come down broken.
4. Check `gh auth status`, and confirm I have push access with:
   gh api repos/alecvs3/gunmo --jq .permissions
5. Clone the repo and check out the active branch. Make sure LFS files are real files, not pointers: `git lfs ls-files` should list them, and the .png files should be more than a few hundred bytes.
6. Import the project headless with the Godot console executable: `--headless --path . --import`. Then run the checks from CLAUDE.md and report the results honestly:
   - Tests: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit (all should pass)
   - gdlint .
   - gdformat --check .
7. Read CLAUDE.md, README.md and docs/PROGRESS.md, and run `gh pr list --state all`. Then explain to me in plain words:
   - what's built and how the networking works (who decides what)
   - which parts I own (see Ownership in CLAUDE.md) and should review closely
   - the known limitations
8. Finish with a short checklist:
   - testing with 2 local instances (Debug → Customize Run Instances)
   - how to join the other developer over Tailscale: they click Host, I enter their 100.x.y.z Tailscale IP on port 7777 and click Join
   - our workflow: pull main, one branch per issue, open a PR, the other person reviews it and we test together, then merge
````
