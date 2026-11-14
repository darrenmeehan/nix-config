{ stdenv
, fetchNpmDeps
, nodejs
, npmHooks
,
}:

# The Pi extensions `pi install` would put in ~/.pi/agent/npm, assembled in one
# node_modules tree: they share a resolution root there, so an extension's
# imports of its own dependencies resolve. home/configs/pi-bolt.nix picks the
# extensions out of it and compiles them into pi-bolt.
stdenv.mkDerivation {
  name = "pi-extensions";
  src = ./npm;

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
  ];

  npmDeps = fetchNpmDeps {
    src = ./npm;
    hash = "sha256-3U6W2Co2hPZTRKzzZsMxT/t59aI+zf9YgGmiC3uWuGg=";
  };

  # Nothing here runs at build time: the extensions are compiled by pi-bolt.
  npmRebuildFlags = [ "--ignore-scripts" ];

  # Pi supplies its own packages at run time (they are peer dependencies), and
  # it is not published for npm to install into this tree.
  npmFlags = [ "--legacy-peer-deps" ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r node_modules $out/
    runHook postInstall
  '';

  dontFixup = true;
}
