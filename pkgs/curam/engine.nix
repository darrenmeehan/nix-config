# The mem/1 boundary engine (`curam-membrane`), built from curam-security at the
# rev in pins.nix. Discovery rule 2 in the pi driver is `curam-membrane` on PATH.
#
# `rustPlatform` comes from the nixpkgs-curam input, not from this repo's
# nixpkgs: the journal's rusqlite needs a toolchain that links its bundled
# sqlite3, and unstable's does not (see flake.nix).
{ rustPlatform }:
let
  src = builtins.fetchGit (import ./pins.nix).curam-security;
in
rustPlatform.buildRustPackage {
  pname = "curam-membrane";
  version = "0.1.0";
  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [ "-p" "curam-membrane" ];
  # The crate's own tests run in the dev shell; they want a writable journal
  # directory and prove nothing about this derivation.
  doCheck = false;
}
