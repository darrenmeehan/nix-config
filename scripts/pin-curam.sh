#!/usr/bin/env bash
# Point pkgs/curam/pins.nix at the two curam checkouts' current HEADs. The engine
# and the pi driver are built from committed revs (a derivation, not a flake
# input — see pkgs/curam/pins.nix), so this is what "pick up my curam changes"
# means. A dirty checkout is warned about, not refused: the pin is a commit, so
# anything uncommitted is simply not in the build.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
pins="$repo_root/pkgs/curam/pins.nix"

rev_of() {
  local checkout="$1"
  # A dirty checkout is not an error, it is a silent omission: the pin is a
  # commit, so uncommitted work is not in the build. Say what is left out.
  if [ -n "$(git -C "$checkout" status --porcelain)" ]; then
    echo "pin-curam: $checkout is dirty; these are NOT in the pinned build:" >&2
    git -C "$checkout" status --short | sed 's/^/  /' >&2
  fi
  git -C "$checkout" rev-parse HEAD
}

security_rev="$(rev_of "$HOME/code/curam-security")"
membrane_rev="$(rev_of "$HOME/code/pi-curam-security")"

python3 - "$pins" "$security_rev" "$membrane_rev" <<'PY'
import re
import sys

path, security, membrane = sys.argv[1:4]
text = open(path).read()
for name, rev in (("curam-security", security), ("pi-curam-security", membrane)):
    text, count = re.subn(
        rf'(^  {re.escape(name)} = \{{[^}}]*rev = ")[0-9a-f]{{40}}(")',
        rf"\g<1>{rev}\g<2>",
        text,
        flags=re.MULTILINE,
    )
    if count != 1:
        sys.exit(f"pin-curam: expected one rev line for {name}, found {count}")
open(path, "w").write(text)
PY

echo "pin-curam: engine $security_rev, driver $membrane_rev" >&2
