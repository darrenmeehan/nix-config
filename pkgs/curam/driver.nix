# The pi driver's source tree (repo root, so callers use /drivers/pi) at the rev
# in pins.nix. A store path, not the ~/code checkout: that is what lets pi-bolt
# compile the driver into the executable.
{ }:
let
  pins = import ./pins.nix;
in
builtins.fetchGit pins.curam-membrane
