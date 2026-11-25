# `hub-sync` — stage every source project's docs/ into a Zola site and build it.
#
# The hub's own files (config.toml, sources.toml, templates, static) come from
# docs-hub/ in this repository, baked in as DOCS_HUB_SRC so the script can run
# straight from the store. The writable side — staged content and the built
# site — goes to DOCS_HUB_ROOT (default: $XDG_DATA_HOME/docs-hub), which is
# never inside a git repository: the project repos stay the single source of
# truth.
{ python3, zola, git, writeShellApplication }:

writeShellApplication {
  name = "hub-sync";
  runtimeInputs = [
    (python3.withPackages (packages: [ packages.pyyaml ]))
    zola
    git
  ];
  text = ''
    export DOCS_HUB_SRC="''${DOCS_HUB_SRC:-${../docs-hub}}"
    exec python3 "$DOCS_HUB_SRC/hub-sync.py" "$@"
  '';
  meta = {
    description = "Aggregate project docs/ into the Zola docs hub and build it";
    mainProgram = "hub-sync";
  };
}
