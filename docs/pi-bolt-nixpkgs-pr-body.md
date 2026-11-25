Adds `pi-bolt` 1.3.1, OpenSec's ahead-of-time compiled build of the [pi coding agent](https://github.com/earendil-works/pi). This builds Pi-Bolt from source and compiles it with the released Pi-Bolt AOT engine (Pi 1.6.0).

The engine (`pi-bolt-runtime-*.tar.gz`: patched Bun + WebKit) is released as a signed binary. Building it from source builds WebKit and Bun with LTO, which is not practical in nixpkgs, so `sourceProvenance` lists both `fromSource` and `binaryNativeCode`.

## Things done

- [x] Fits [CONTRIBUTING.md], [pkgs/README.md], [maintainers/README.md] and other READMEs.
- [x] Follows the [automation/AI policy].
- Built on platform:
  - [x] x86_64-linux
  - [ ] aarch64-linux
  - [ ] aarch64-darwin
- Tested, as applicable:
  - [x] Basic functionality of all binary files, usually in `./result/bin/`.
  - [x] Ran `nixpkgs-review` on this PR. See [nixpkgs-review usage].
  - [x] [Package tests] at `passthru.tests`.
  - [ ] [NixOS tests] in [nixos/tests].
  - [ ] Tests in [lib/tests] or [pkgs/test] for functions and "core" functionality.
- [Nixpkgs Release Notes]
  - [ ] Package update: when the change is major or breaking.
- [NixOS Release Notes]
  - [ ] Module addition: when adding a new NixOS module.
  - [ ] Module update: when the change is significant.

What was actually run locally (x86_64-linux, `sandbox = true`):

- `nix-build -A pi-bolt.passthru.tests` — builds, `versionCheckHook` passes, and `passthru.tests.aot` confirms the static heap image is registered rather than falling back to the Bun CLI.
- `./result/bin/pi-bolt --version` → `1.6.0 (Pi-Bolt 1.3.1, linux-x64-baseline, JIT off)`.
- `pi-bolt.withExtensions [ … ]` with four extensions (`@aliou/pi-guardrails`, `@melihmucuk/leash`, `@heyhuynhgiabuu/pi-diff`, `@mjasnikovs/pi-task`) — builds, and `pi-bolt doctor` lists them as built-in extensions (`builtin:aliou-pi-guardrails-index…`, `builtin:melihmucuk-leash`, `builtin:heyhuynhgiabuu-pi-diff`, `builtin:mjasnikovs-pi-task`).
- The same with `.override { jitSupport = true; cpu = "native"; }` — builds, `--version` → `1.6.0 (Pi-Bolt 1.3.1, linux-x64-jit, JIT on)`. This variant is what I run as a daily driver, so the default build and the two overridable axes are both exercised.
- The version bump is `./update.sh` only: source and the three runtime hashes. `RUNTIME_STAMP` and `npmDepsHash` are unchanged, so this is a patch release with no engine or dependency-tree change. No derivation logic changed.
- `nixpkgs-review rev HEAD --no-shell` on the full local clone: **1 package built: `pi-bolt`**, 0 failed (evaluated with import-from-derivation disabled, merge base at the current `master`).
- `nix-build ci -A nixpkgs-vet` against that merge base: `Validated successfully`, zero findings; `nixfmt` clean; `nix-instantiate --parse` clean.
- Evaluation with `--option allow-import-from-derivation false` for x86_64-linux (the mode nixpkgs CI uses).
- Manual smoke test: a model call succeeded with and without the local extension set.

## Automation disclosure

Per [automation/AI policy]: the `pi-bolt` commits, this description, and the version bump were produced with LLM-based tooling — Pi-Bolt (pi coding agent), primary model `deepseek-v4.1-flash-1017`. Both commits carry an `Assisted-by:` trailer.

Output was verified rather than trusted: the package was built and its binaries executed, the `passthru.tests.aot` test was run, the extension and native-CPU variants were built, evaluation was repeated with import-from-derivation disabled, and the maintainer reviewed the resulting diff and is accountable for it.

## Notes for reviewers

- **Prebuilt runtime.** Upstream ships the AOT engine as signed binaries; the application is compiled from source. `sourceProvenance = [ fromSource binaryNativeCode ]`. The in-tree precedent for a third-party-built Bun-family runtime is `pkgs/by-name/bu/bun`.
- The runtime interpreter is patched **before** the compile; patching the compiled executable afterwards damages its AOT image. Hence `dontStrip`/`dontPatchELF`/`dontAutoPatchelf`, with `autoPatchelf` only on `lib/pi-bolt/native` (the X11 keyboard `.node`, linked to libxcb).
- The build runs a biome-based generated-schema check (`build:unbundled`). The npm deps are installed without lifecycle scripts, so biome's platform binary is unusable; the check is skipped in `postPatch`. The generated files are committed and `tsc` still compiles them.
- `npmDeps = fetchNpmDeps` pins the npm tree by `npmDepsHash` (no import-from-derivation, which nixpkgs CI disallows); `npmRebuildFlags = [ "--ignore-scripts" ]`.
- **jiti cache.** Pi caches transformed extensions in `~/.pi/agent/cache/jiti` and reuses a cached transform whenever the extension's own source is unchanged, whatever produced it, so two Pi/Pi-Bolt builds sharing that directory can hand each other incompatible output and crash Bun. `postPatch` salts the cache path with `${version}`; `JITI_FS_CACHE` is deliberately *not* set, because setting it (to anything) moves pi onto jiti's system-wide temporary directory, which is the shared-directory case that crashes.
- **Compiled-in extensions.** `passthru.withExtensions` writes a `build-pi.sh --plugins` manifest, so an extension can be part of the static heap image instead of being loaded from files at run time (where the JIT-off build interprets it). Each extension is staged with its package root and dependency tree because the manifest build maps Pi's packages with a `tsconfig` next to the staged folder. This is how I use the package, so it is exercised; `jitSupport`, `cpu` and `aotBytecodeLimit` are the other `build-pi.sh` knobs, all defaulting to upstream behaviour. Happy to drop any of them that a reviewer considers speculative.
- `--version` prints `1.6.0 (Pi-Bolt 1.3.1, …)`; `versionCheckHook` matches `1.3.1` against `meta.mainProgram`.
- License: Pi-Bolt/Bun MIT; bundled WebKit LGPL-2.0-or-later and BSD-2-Clause.
- Platforms: upstream publishes assets for all three, but only x86_64-linux has been built, so `meta.platforms` is x86_64-linux only. The aarch64/darwin runtime hashes stay in `runtimeAssets` because `update.sh` maintains them and they are what a platform widening would use.
- Update script: `passthru.updateScript = ./update.sh`; this is the hook `nixpkgs-update`/r-ryantm uses. No extra registration is needed.

## Maintainer

- [x] I am the maintainer (`darrenmeehan`).

[nixpkgs-review usage]: https://github.com/Mic92/nixpkgs-review#usage
[Package tests]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-tests
[NixOS tests]: https://nixos.org/manual/nixos/unstable/index.html#sec-nixos-tests
[CONTRIBUTING.md]: https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md
[automation/AI policy]: https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy
[lib/tests]: https://github.com/NixOS/nixpkgs/blob/master/lib/tests
[maintainers/README.md]: https://github.com/NixOS/nixpkgs/blob/master/maintainers/README.md
[nixos/tests]: https://github.com/NixOS/nixpkgs/blob/master/nixos/tests
[pkgs/README.md]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md
[pkgs/test]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/test
[Nixpkgs Release Notes]: https://github.com/NixOS/nixpkgs/blob/master/doc/release-notes
[NixOS Release Notes]: https://github.com/NixOS/nixpkgs/blob/master/nixos/doc/manual/release-notes
