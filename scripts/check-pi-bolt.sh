#!/usr/bin/env bash
# Start pi-bolt on a pty and fail if any extension does not load; stopwatch until
# the prompt box is ready.
#
# `pi-bolt doctor` lists the extensions compiled into the executable but never
# runs their factories, so a compiled-in extension that reads its own files
# (bigpowers' skills/, opensec-pi-fff's ./core.cjs) reports "Problems: none
# found" and then fails every session with "Failed to load extension". This
# starts a real one, the way the TUI does, with no model call.
#
# Usage: ./scripts/check-pi-bolt.sh [RUNS]     (RUNS defaults to 1; >1 prints
#                                               min/median/max time to prompt)
#        PI_BOLT=/nix/store/…-pi-bolt/bin/pi-bolt ./scripts/check-pi-bolt.sh
#        (default: the pi-bolt on PATH)

set -euo pipefail

pi_bolt="${PI_BOLT:-$(command -v pi-bolt)}"
runs="${1:-1}"

exec python3 - "$pi_bolt" "$runs" <<'PY'
import os
import pty
import re
import select
import statistics
import sys
import time

binary = sys.argv[1]
runs = int(sys.argv[2])
limit = 30.0
ansi = re.compile(rb"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[()][A-Z0-9]")
# The model and thinking level in the prompt box: drawn once the TUI is ready to take a prompt.
ready_marker = "\u2022 high".encode()


def once():
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.setdefault("TERM", "xterm-256color")
        # --no-approve: read no project-local settings, so no trust prompt gets in the way.
        os.execvp(binary, [binary, "--no-approve"])

    start = time.time()
    out = b""
    ready = None
    while time.time() - start < limit:
        readable, _, _ = select.select([fd], [], [], 0.02)
        if not readable:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
        if ready_marker in ansi.sub(b"", out):
            ready = time.time() - start
            break

    try:
        os.kill(pid, 9)
    except OSError:
        pass
    os.waitpid(pid, 0)
    return ready, ansi.sub(b"", out).decode("utf-8", "replace")


times = []
for attempt in range(runs):
    ready, text = once()
    failed = [
        line.strip()
        for line in text.splitlines()
        if "Failed to load extension" in line or "Cannot find module" in line
    ]
    if failed:
        for line in failed:
            print(line, file=sys.stderr)
        sys.exit(1)
    if ready is None:
        print(f"run {attempt + 1}: no prompt after {limit:.0f}s", file=sys.stderr)
        print(text[-800:], file=sys.stderr)
        sys.exit(1)
    times.append(ready)

if runs == 1:
    print(f"ok: prompt ready in {times[0]:.2f}s, every extension loaded")
else:
    print(
        f"ok: prompt ready min {min(times):.2f}s / median {statistics.median(times):.2f}s / "
        f"max {max(times):.2f}s over {runs} runs, every extension loaded"
    )
PY
