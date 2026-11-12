{ pkgs, ... }:
let
  inherit (pkgs) coreutils;

  # pi-bolt's package wrapper disables jiti's filesystem cache to avoid stale
  # cache segfaults, but that re-transpiles every extension on every start
  # (~40s with this extension set). Keep a persistent cache keyed by the
  # pi-bolt version and the extension lock instead; a stale entry gets a new
  # directory rather than a crash.
  pi-bolt = pkgs.writeShellScriptBin "pi-bolt" ''
    store=${pkgs.pi-bolt}
    version=${pkgs.pi-bolt.version}

    lock="$HOME/.pi/agent/npm/package-lock.json"
    key="$version-none"
    if [ -f "$lock" ]; then
      key="$version-$(${coreutils}/bin/sha256sum "$lock" | ${coreutils}/bin/cut -c1-16)"
    fi
    export TMPDIR="''${XDG_CACHE_HOME:-$HOME/.cache}/pi-bolt/$key"
    ${coreutils}/bin/mkdir -p "$TMPDIR"
    export JITI_FS_CACHE=true

    # `pi-bolt compile` builds in place only when the executable sits in
    # <dir>/pi-bolt-<os>-<arch>/pi (a pure directory-name test in
    # piBoltInstallDir()). A store path can never match, and /nix/store is
    # read-only anyway, so default it to `--out` in a writable cache dir.
    # Override the location with PI_BOLT_AOT_DIR.
    aot="''${PI_BOLT_AOT_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/pi-bolt-aot}"
    if [ "''${1-}" = compile ]; then
      shift
      # `--status` reports the installation's pi-bolt.txt; the AOT build's is
      # in the out dir, so answer from there when that is all that was asked.
      if [ "$#" = 1 ] && [ "$1" = --status ]; then
        if [ -f "$aot/pi-bolt.txt" ]; then
          ${coreutils}/bin/grep -m1 '^Extensions compiled in' "$aot/pi-bolt.txt" ||
            echo "No extensions are compiled into $aot."
        else
          echo "No AOT build at $aot (run: pi-bolt compile)."
        fi
        exit 0
      fi
      # Anything the caller decided for itself is left alone.
      for arg in "$@"; do
        case "$arg" in
          --out | --out=* | --status | --list | --help | -h) exec "$store/bin/pi-bolt" compile "$@" ;;
        esac
      done
      exec "$store/bin/pi-bolt" compile --out "$aot" "$@"
    fi

    # Prefer the compiled build when it was built from this exact pi-bolt
    # version. A stale one would run an old engine against the current
    # settings, so the stamp in its pi-bolt.txt decides, not its presence.
    # Rebuild after a version bump or an extension change with
    # `make pi-bolt-aot`.
    if [ -x "$aot/pi" ] && ${coreutils}/bin/grep -q "^Pi-Bolt $version " "$aot/pi-bolt.txt"; then
      exec "$aot/pi" "$@"
    fi

    exec "$store/bin/pi-bolt" "$@"
  '';
in
{
  home.packages = [ pi-bolt ];
}
