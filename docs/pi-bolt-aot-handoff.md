# Handoff: Pi-Bolt AOT compile (nixpkgs + nix-config)

**Superseded (2026-11-13).** Extensions are compiled into the executable by
the Nix build now; `pi-bolt compile`, `~/.cache/pi-bolt-aot` and the wrapper
that made it work from a store path are gone. Current picture:
[pi-bolt-extensions.md](pi-bolt-extensions.md).

**Status:** ready for implementation.
**Last updated:** 2026-11-11.
**Context:** curam-membrane's pi driver (`~/code/curam-membrane/drivers/pi`)
is installed and verified on the current nix Pi-Bolt. AOT compile is the
remaining startup win: measured **3.51 s → 0.40 s** for `pi-bolt doctor`
(file-loaded vs compiled-in).

Read first: [pi-bolt-extension-set.md](pi-bolt-extension-set.md) (startup
cost model) and [pi-bolt-jiti-cache-fix.md](pi-bolt-jiti-cache-fix.md)
(the jiti cache wrapper this must not break).

## TL;DR

1. **nixpkgs needs no code change.** The fork branch already builds 1.2.1;
   the machine is pinned to 1.2.0. Bump the lock only:
   `nix flake update pi-bolt-nixpkgs`.
2. **nix-config needs a wrapper change** to prefer an AOT build when its
   version matches the nix package, and a documented rebuild step (or a
   cheap activation hook) that runs `pi-bolt compile --out` after upgrades.
3. Verify with the curam driver: planted-secret E2E under the AOT binary.

## Facts (verified)

| Item | Value |
| --- | --- |
| Installed on machine | `pi-bolt` 1.2.0 (Pi 1.5.0) |
| nixpkgs fork branch `pi-bolt-nixpkgs` head | `520a19b3` — package **1.2.1** (pushed 2026-11-11) |
| `flake.lock` pin | `6b9f2a4793463fce029dd6c852ece2b65e2dca9e` — package **1.2.0** |
| Fork package path | `pkgs/by-name/pi/pi-bolt/package.nix` |
| Wrapper | `home/configs/pi-bolt.nix` (sets `TMPDIR`, `JITI_FS_CACHE=true`) |
| Flake input | `flake.nix` → `github:darrenmeehan/nixpkgs/pi-bolt-nixpkgs` (PR #586143) |
| Test AOT build | `~/.cache/pi-bolt-aot-121/pi` (1.2.1, includes `curam-membrane-pi`) |
| Driver source | `~/code/curam-membrane/drivers/pi` (branch `feat/pi-driver`) |
| Driver docs | `~/code/curam-membrane/drivers/pi/README.md` → "Compiled (AOT) mode" |

## Issues

### I1 — nix store build cannot compile in place (by design)

```
error: this Pi-Bolt is not in an installation (/nix/store/...): use --out DIR, or install it with the installer
```

The store path is immutable and is not an "installation". AOT requires
either the official installer (`curl -fsSL https://pi-bolt.opensec.in/install.sh | sh`,
then in-place `pi-bolt compile`) or an out-of-tree build with `--out`.
**Decision needed:** installer (simple, leaves Nix) vs `--out` + wrapper
(keeps Nix). Both work; the recommendation below is `--out`.

### I2 — `--out` is broken on 1.2.0 (fixed in 1.2.1)

On 1.2.0, `pi-bolt compile --out DIR` unpacks the runtime/kit with
read-only modes and then fails to clean or write:

```
error: pi-bolt compile failed: EACCES: permission denied, rm '<cache>/.compile-XXXX'
error: pi-bolt compile failed: EACCES: permission denied, open '<cache>/.compile-XXXX/pi-bolt/pi-bolt.txt'
```

No output folder is produced. Root cause: the release runtime keeps
`dr-xr-xr-x`/`0444` modes; the cleanup and the `pi-bolt.txt` rewrite need
write permission. **1.2.1 succeeds**; verified build:

```
Built Pi-Bolt 1.2.1 with herdr-agent-state, bigpowers, ...,
curam-membrane-pi compiled in, in 157 s: ~/.cache/pi-bolt-aot-121
```

Chmod hacks are **not** a fix and raced into a different failure
(`generated.stderr.trim` undefined). Do not carry them into nix-config.

### I3 — `pi-sdk-peer` symlink is missing (pi-diff fails every start)

```
[pi-diff] failed to load Pi SDK dependencies:
Cannot find package '@earendil-works/pi-coding-agent'
imported from ~/.pi/agent/npm/node_modules/@heyhuynhgiabuu/pi-diff/dist/index.js
```

`home/configs/pi-sdk-peer.nix` should provide
`~/.pi/agent/npm/node_modules/@earendil-works/pi-coding-agent`, but the
symlink is absent right now (an extension install/update can drop it; the
nix file comment already warns about this). A `home-switch` recreates it.
Tasks: switch once, verify, and consider making the failure loud/checked
(a `home.activation` assertion or wrapper check) instead of relying on the
comment. Also decide whether to keep `pi-diff` at all — it is in the
extension set doc as deliberately broken.

### I4 — `pi-bolt update` and `nix flake update` invalidate the AOT build

`pi-bolt update` installs the release build (no extensions compiled in;
`compile.json` is kept). In the Nix flow, a version bump changes the store
path, so the AOT folder must be rebuilt. The wrapper must not silently run
a stale AOT binary built against a different version.

### I5 — two packages can never be compiled in

`npm:opensec-pi-todo` and `npm:opensec-pi-fff` are passed over by
`pi-bolt compile` ("a Bun build that loads core.cjs at run time, which
needs vendoring per package"). They stay file-loaded (~96 ms and ~90 ms
warm, measured under AOT). Not a nix-config fix; note it so the expected
startup floor is understood (~0.4 s, not 0 s).

### I6 — engine discovery is a hardcoded workspace fallback

The driver resolves `$MEMBRANE_ENGINE` → `PATH` → 
`~/code/curam-security/target/{debug,release}/curam-membrane`. Options:
package the engine (cargo build of `~/code/curam-security`) or set
`MEMBRANE_ENGINE` in `home.sessionVariables`; otherwise every new engine
build requires nothing but the fallback keeps working. Optional for this
handoff, but it is the remaining non-nix piece of the daily-driver setup.

## Tasks

### A. nixpkgs (fork `darrenmeehan/nixpkgs`, branch `pi-bolt-nixpkgs`)

- [ ] **No package edit expected.** Confirm `pkgs/by-name/pi/pi-bolt/package.nix`
      at branch head is `version = "1.2.1"` with matching `npmDepsHash`,
      `src.hash`, and `runtimeAssets` hashes (all present at `520a19b3`).
- [ ] Build it: `nix build github:darrenmeehan/nixpkgs/pi-bolt-nixpkgs#pi-bolt`
      and run `result/bin/pi-bolt --version` (expect `1.5.2 (Pi-Bolt 1.2.1…)`).
- [ ] If the build fails, fix only what the 1.2.1 bump broke; do not fork
      the package logic.
- [ ] Leave the PR branch rebased on the current upstream PR (#586143).

### B. nix-config (branch off `main`, Conventional Commits, `nix fmt`)

- [ ] `nix flake update pi-bolt-nixpkgs`, then `home-switch`; confirm
      `pi-bolt --version` reports 1.2.1.
- [ ] Recreate the pi SDK peer link (I3) and verify:
      `readlink -f ~/.pi/agent/npm/node_modules/@earendil-works/pi-coding-agent`
      resolves, and `pi-bolt doctor` no longer reports the pi-diff failure.
- [ ] Rework `home/configs/pi-bolt.nix`:
      - Prefer an AOT build when one exists **and** its
        `pi-bolt.txt` version matches `pkgs.pi-bolt.version`
        (grep the file; it contains `Pi-Bolt <version>`).
      - Fall back to the store binary otherwise (current behaviour).
      - Keep `TMPDIR` and `JITI_FS_CACHE` for the file-loaded packages
        (`opensec-pi-todo`, `opensec-pi-fff`) — do not drop the jiti cache.
- [ ] Add a rebuild entry point, e.g. `make pi-bolt-aot`:
      `pi-bolt compile --out "$HOME/.cache/pi-bolt-aot"` using the bumped
      store build, then `~/.cache/pi-bolt-aot/pi doctor` to verify the
      `compiled in` lines.
      - Do **not** run it from `home.activation` unconditionally: it needs
        network on first run and ~160 s, so activation would block every
        switch.
      - If you want automation, gate it on a stamp file:
        `<aot>/pi-bolt.txt` version != `pkgs.pi-bolt.version` or the
        `~/.pi/agent/npm/package-lock.json` hash changed. Run it
        asynchronously or via a timer, not synchronously in activation.
- [ ] Update `docs/pi-bolt-extension-set.md` (its "compile fails on Nix"
      note is now stale) and link this file.
- [ ] Optional (I6): package `curam-membrane` or set `MEMBRANE_ENGINE` in
      `home.sessionVariables`.

### C. Verification

```bash
# version + AOT contents
~/.cache/pi-bolt-aot/pi --version
~/.cache/pi-bolt-aot/pi doctor | sed -n '/^Extensions/,$p'   # curam-membrane-pi: compiled in

# startup cost (warm, run twice)
time pi-bolt doctor            # expect ~0.4 s with AOT, ~3.5 s file-loaded

# driver still masks under AOT (planted secret gate)
cd ~/code/curam-membrane
PI_BIN=~/.cache/pi-bolt-aot/pi E2E_COMPILED_DRIVER=1 \
  bash drivers/pi/tests/e2e_spy.sh
# expect: PASS, journal 1 pii_scrubbed row, no raw secret

# engine + journal
printf '%s\n' '{"id":1,"v":"mem/1","op":"status"}' | \
  ~/code/curam-security/target/debug/curam-membrane
ls -l ~/.local/state/curam/journal.db    # expect -rw-------
```

## Constraints

- All machine changes through this flake on a branch off `main`; no ad-hoc
  installs, no editing store paths, no chmod workarounds.
- Never run the official installer **and** the nix package as the same
  `pi-bolt` name on `PATH` without deciding which wins.
- The AOT folder must stay intact (assets live beside the `pi` binary).
- `pi-bolt update` is not part of the Nix flow; do not use it to "fix"
  versions here.

## Open decisions

1. **Installer vs `--out`.** Recommendation: `--out` + wrapper, because it
   keeps one version source (the flake) and rollback is `nix`-native.
2. **Where the AOT build lives.** `~/.cache/pi-bolt-aot` is disposable and
   cache-like; a `~/.local/state` path survives cache cleaners. Pick one
   and use it in both the wrapper and the rebuild target.
3. **Automation vs manual.** A `make` target is predictable; an async
   timer is more magic. Recommendation: `make` target + wrapper fallback
   first; automate only if it actually gets forgotten.
4. **`pi-diff`.** Fix the peer link (done by switch) or remove the package.
   It is currently listed as deliberately broken.

## Appendix — evidence

- `pi-bolt doctor` on 1.2.0: extensions interpreted, `bigpowers` loaded in
  ~572 ms; total doctor ~3.5 s.
- `pi-bolt compile --out` on 1.2.0: two distinct `EACCES` failures (I2).
- `pi-bolt compile --out` on 1.2.1 release binary: exit 0, 157 s,
  13 extensions compiled in including `curam-membrane-pi`.
- AOT doctor: `npm:bigpowers: by pi-bolt compile`, driver
  `~/code/curam-membrane/drivers/pi: by pi-bolt compile`; doctor ~0.40 s.
- Live session under AOT, planted `ghp_…` in a file read by the agent:
  exit 0, answer noted the value was redacted, journal had one
  `pii_scrubbed` row with a fingerprint and no raw value.
