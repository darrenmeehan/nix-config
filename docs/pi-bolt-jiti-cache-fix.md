# Plan: fix the stale jiti cache crash in Pi-Bolt

**Status:** investigation and plan. Short-term workaround: disable jiti's cache
or use a versioned cache.
**Last updated:** 2026-11-09.

## Problem

Pi-Bolt loads extensions through jiti. jiti's filesystem transpile cache
(`JITI_FS_CACHE`, default on, stored under `$TMPDIR/jiti`) makes warm starts
fast, but a cache written by an earlier Pi-Bolt/extension state can make the
Bun AOT runtime segfault. Clearing the cache fixes it.

Current workarounds:

- nixpkgs package: `JITI_FS_CACHE=false` — safe, but every start re-transpiles
  all extensions (~25–40 s with ten extensions).
- Home Manager wrapper: `JITI_FS_CACHE=true` with
  `TMPDIR=~/.cache/pi-bolt/<pi-bolt-version>-<extension-lock-hash>` — fast and
  avoids reusing a stale cache, at the cost of a slow first start per key.

## What we know

- jiti 2.7.0; cache lives under `$TMPDIR/jiti`.
- Warm `--help` with ten extensions: ~1.5 s; with the cache disabled: ~25 s.
- Removing the cache after a Pi-Bolt/extension change stops the crash.
- The crash is in the Bun/AOT runtime path, not in a missing extension `.node`
  module (see `docs/pi-messenger-bridge-crash.md` for a separate extension bug).
- The core AOT-compiled Pi code is unaffected; this is extension loading only.

## Goals

- No segfault from a cache written by an older Pi-Bolt or extension set.
- Warm start under ~2 s with ten extensions.
- Cache invalidation on Pi-Bolt/engine/extension changes without user action.
- No unbounded cache growth and no manual `rm -rf` required.
- Keep `JITI_FS_CACHE=false` as a safe fallback.

## Investigation

1. Capture a controlled stale-cache reproduction:
   - populate the cache with Pi-Bolt 1.0.8;
   - switch to 1.1.7 with the cache enabled;
   - record the crash link, the cache files, and `BUN_STATIC_HEAP_VERBOSE=1`
     output.
2. Determine the cache owner: jiti's filesystem cache versus Bun's in-process
   `transpiler_cache`. Run the same experiment with `JITI_FS_CACHE=false` and
   with a separate `TMPDIR` to isolate which cache is read.
- Inspect jiti 2.7.0's cache key and format: does it include file content,
  mtime, transpiler version, or loader version?
- Build a minimal repro with one extension module, then change the Pi-Bolt
  version or the extension content and restart with the same cache.
- Test on Pi-Bolt 1.0.8 and 1.1.7, source and official prebuilt, and compare
  Node `pi`.

## Fix options

### A. Pi-Bolt (preferred)

- Namespace the extension cache by Pi-Bolt version, engine/runtime stamp, and
  extension lock before loading extensions.
- Use a new cache directory when any of those change; prune old namespaces.
- If loading a cache entry fails, delete that entry and retranspile instead of
  crashing.

### B. jiti

- Include the loader/runtime version in the filesystem cache key.
- Validate cached entries and treat unreadable/incompatible entries as a cache
  miss.
- Expose a cache namespace/directory option so embedders such as Pi-Bolt can
  separate incompatible runtimes.

### C. Packaging (short term)

- Keep `JITI_FS_CACHE=false` for safety, or keep the versioned-cache wrapper.
- Remove the workaround once A or B ships; document the reason and the
  clearing command until then.

## Test plan

- Cache populated with 1.0.8, then start 1.1.7: no crash, cache miss and
  retranspile.
- Extension update (`pi update --extensions`) with cache enabled: no crash.
- Warm `pi-bolt --help`/TUI start <2 s with ten extensions.
- `--no-extensions` remains fast (cache not involved).
- Repeated starts reuse the cache; no unbounded growth.
- Node `pi` unaffected.

## Upstream coordination

- Open a Pi-Bolt issue with the reproduction, crash link, cache directory, and
  versions; propose namespacing the cache in the extension loader.
- If the cache key/validation is jiti's responsibility, open a jiti issue/PR
  as well.
- Add the regression test before removing the nixpkgs workaround.

## Risks / open questions

- Invalidating on every extension change may make the first start slow; that
  is acceptable if it is predictable.
- `settings.json` changes that enable/disable already-installed extensions do
  not necessarily change `package-lock.json`; decide whether the namespace
  should include the settings hash.
- Old cache directories need a cleanup policy.
- The AOT runtime/Bun version, not just Pi-Bolt's app version, may matter; use
  the engine stamp if available.

## Acceptance criteria

- Starting with a cache from an older Pi-Bolt/extension state never segfaults.
- Warm start with ten extensions is under ~2 s.
- Cache changes are automatic; no manual deletion.
- The nixpkgs package no longer needs `JITI_FS_CACHE=false` (or the workaround
  is documented as temporary with a tracking issue).
