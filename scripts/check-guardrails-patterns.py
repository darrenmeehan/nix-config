#!/usr/bin/env python3
"""Assert the /tmp-delete allow-pattern in guardrails.json stays narrow.

The pattern is checked against the whole raw bash command (guardrails runs it
before its built-in dangerous-command matchers), so a too-loose regex silently
unlocks every `rm -rf` the built-ins were there to catch. This reads the live
file — the one the extension loads — and fails when a case flips.

Usage: ./scripts/check-guardrails-patterns.py [PATH]
       (default: ~/.pi/agent/extensions/guardrails.json)
"""

import json
import os
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.pi/agent/extensions/guardrails.json"
)
with open(path) as f:
    config = json.load(f)

patterns = [
    re.compile(p["pattern"])
    for p in config.get("permissionGate", {}).get("allowedPatterns", [])
]

# (command, allowed-without-a-prompt)
CASES = [
    ("rm -rf /tmp/build-123", True),
    ("rm -rf /tmp/build-123/", True),
    ("rm /tmp/a /tmp/b", True),
    ("rm -rf /tmp/*", True),
    ("rmdir /tmp/scratch", True),
    ("rm -rf /var/tmp/cache", True),
    ("rm -rf /tmp", False),
    ("rm -rf /", False),
    ("rm -rf ~/code/nix-config", False),
    ("rm -rf /tmp/x /home/darrenmeehan/code", False),
    ("rm -rf /tmp/../home/darrenmeehan/x", False),
    ("rm -rf /tmp/a/../b", False),
    ("rm -rf /tmp/x; rm -rf ~/code", False),
    ("rm -rf /tmp/x && rm -rf /tmp/y", False),
    ("rm -rf /tmp/$(whoami)", False),
    ("rm -rf /tmp/`id`", False),
]

failed = False
for command, want in CASES:
    got = any(p.search(command) for p in patterns)
    if got != want:
        failed = True
        print(f"FAIL {command!r}: want allowed={want}, got {got}")

print(f"{len(CASES)} cases, {'FAILED' if failed else 'ok'}")
sys.exit(1 if failed else 0)
