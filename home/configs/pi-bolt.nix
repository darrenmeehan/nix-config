{ pkgs, ... }:
let
  inherit (pkgs) coreutils;

  # pi-bolt's package wrapper disables jiti's filesystem cache to avoid stale
  # cache segfaults, but that re-transpiles every extension on every start
  # (~40s with this extension set). Keep a persistent cache keyed by the
  # pi-bolt version and the extension lock instead; a stale entry gets a new
  # directory rather than a crash.
  pi-bolt = pkgs.writeShellScriptBin "pi-bolt" ''
    lock="$HOME/.pi/agent/npm/package-lock.json"
    key="${pkgs.pi-bolt.version}-none"
    if [ -f "$lock" ]; then
      key="${pkgs.pi-bolt.version}-$(${coreutils}/bin/sha256sum "$lock" | ${coreutils}/bin/cut -c1-16)"
    fi
    export TMPDIR="''${XDG_CACHE_HOME:-$HOME/.cache}/pi-bolt/$key"
    ${coreutils}/bin/mkdir -p "$TMPDIR"
    export JITI_FS_CACHE=true
    exec ${pkgs.pi-bolt}/bin/pi-bolt "$@"
  '';
in
{
  home.packages = [ pi-bolt ];
}
