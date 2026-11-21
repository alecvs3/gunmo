"""Claude Code PostToolUse hook: formats a GDScript file right after it is edited.

Reads the hook payload (JSON) from stdin, and if the edited file is a .gd file, runs
gdformat on it. Does nothing for other files, and stays silent when gdtoolkit isn't
installed, so it never blocks an edit.
"""

import json
import os
import subprocess
import sys


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    tool_input = payload.get("tool_input") or {}
    path = tool_input.get("file_path") or ""
    if not path.endswith(".gd") or not os.path.isfile(path):
        return 0
    subprocess.run(
        [sys.executable, "-m", "gdtoolkit.formatter", path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
