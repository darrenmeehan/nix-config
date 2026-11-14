# Pi-Bolt extension set and startup cost

**Partly superseded (2026-11-13).** The wrapper this describes is gone, most
of the set is compiled into the executable, and startup is timed with
`make bench-pi-bolt`. The current set, costs and reasons:
[pi-bolt-extensions.md](pi-bolt-extensions.md).

**Last updated:** 2026-11-11.

What loads at startup, what it costs, what was removed and why, and how to
get it back when a task needs it. See
[pi-bolt-jiti-cache-fix.md](pi-bolt-jiti-cache-fix.md) for the jiti
transpile-cache workaround that the wrapper in
`home/configs/pi-bolt.nix` implements.

## Why startup is slow

Extension loading, and only extension loading. `PI_TIMING=1` attributes
almost all of startup to extension module import inside
`createAgentSessionRuntime`; with `-ne` (no extensions) the total is ~330 ms.

Three things stack up:

1. **The extensions are interpreted.** Pi-Bolt's default build has the JIT
   off, so run-time extensions run as bytecode (~24x slower than the
   AOT code Pi itself runs as). Nothing local changes that; only
   `pi-bolt compile` does.
2. **jiti transpiles each module graph once per cache namespace.** The
   wrapper keys that namespace on the pi-bolt version *and* the hash of
   `~/.pi/agent/npm/package-lock.json`, so any `pi install`, `pi remove` or
   `pi update --extensions` starts a cold namespace.
3. **Size of the graph.** `pi-lens` was 26 MB on disk, `pi-web-access`
   15 MB with 31 dependencies; the interpreter has to evaluate all of it.

Cold and warm are different orders of magnitude:

| state | startup |
|---|---|
| warm cache, no extensions (`-ne`) | ~0.33 s |
| warm cache, current set | ~2.2 s |
| cold cache, current set | ~16 s |
| cold cache, with `pi-lens` + `pi-web-access` | ~2 min |

The per-extension numbers are therefore only meaningful within one cache
state. An earlier draft of this table blamed `pi-lens` for 2.4 s; that was a
cold-transpile number, not its warm cost.

**Never do a `pi install` / `pi remove` / `pi update --extensions` right
before you want to type a prompt**, and never start Pi-Bolt for the first
time after a version bump in a hurry: that start pays the whole transpile.
Warm it deliberately instead:

```sh
pi-bolt -p ping          # pays the cost now, then discard
```

Attaching to a session that is already running (tmux, herdr) costs nothing
to start; a fresh start always waits for every extension factory, because Pi
does not lazy-load extensions and `expose`/`deferred` only defers *tools*.

## Current set

| package | version | why it stays |
|---|---|---|
| `@aliou/pi-guardrails` | 0.23.0 | file protection, path access, permission gate, herdr prompts |
| `@melihmucuk/leash` | 1.0.11 | second security layer; overlaps guardrails, kept deliberately |
| `@dietrichgebert/ponytail` | 5.3.3 | working style |
| `bigpowers` | 2.96.1 | skills + lifecycle method (12 MB) |
| `@mjasnikovs/pi-task` | 0.42.66 | `/task` pipelines |
| `@plannotator/pi-extension` | 0.28.61 | plan review (50 MB on disk) |
| `pi-agent-browser-native` | 0.9.18 | browser automation |
| `@heyhuynhgiabuu/pi-diff` | 0.9.3 | diff rendering — **broken**: its factory throws `Cannot find package '@earendil-works/pi-coding-agent'` on every start. Remove it or fix it upstream. |
| `~/code/curam-membrane/drivers/pi` | 0.1.0 | local, in development |
| `opensec-pi-todo`, `opensec-pi-fff` | via `piBolt.packages` | todo panel, fuzzy find/grep |

Built-ins (`builtin:mcp`, `llama.cpp`, `codemode`, `tool-search`, `usage`)
cost ~0 ms and are left alone.

## Removed 2026-11-11

Both were removed for startup cost, not for being unused. They are **real
capability gaps**, listed below.

### `pi-lens` 4.4.12 (26 MB)

LSP, linters, formatters, type-checking, structural analysis, proactive
diagnostics.

**Gap:** no in-session diagnostics. After an edit, nothing tells you the type
is wrong or the lint fails until you run the check yourself. Workaround per
project: `nix develop` (or the project's dev shell) and run `tsc --noEmit`,
`cargo check`, `ruff`, etc. through the shell tool. `lens_diagnostics`,
`read_symbol`, `module_report` and the other pi-lens tools are gone from the
tool list, so code navigation falls back to `grep`/`read`.

Replaceable-ish by a shell alias in code repos, but the feedback loop is
manual: you find out at the next check, not at the edit.

**Back on demand:**

```sh
pi-bolt -e npm:pi-lens@4.4.12
```

Exact pin means no registry check at startup (documented in
`docs/packages.md`); the package is cached under `~/.pi/agent/tmp/extensions`.

### `pi-web-access` 0.47.0 (15 MB, 31 dependencies)

`web_search`, URL fetch, GitHub repo cloning, PDF extraction, YouTube
understanding.

**Gap:** no `web_search` / `fetch_content` tools. `pi-worker-search` and
`pi-worker-fetch` (the worker tools) still exist but shell out to their own
path, and there is no built-in PDF or YouTube reader. Any task that needs
current documentation or a live page now needs the extension loaded.

**Back on demand:**

```sh
pi-bolt -e npm:pi-web-access@0.47.0
```

### Restoring either permanently

```sh
pi-bolt install npm:pi-lens@4.4.12
pi-bolt install npm:pi-web-access@0.47.0
```

Then budget one ~2 min cold start before the next session, or warm it with
`pi-bolt -p ping`.

## Why `pi-bolt compile` is blocked (2026-11-11)

`pi-bolt compile --out DIR` fails on every attempt, with any install method:

```
error: pi-bolt compile failed: EACCES: permission denied, open
  '<parent>/.compile-XXXXXX/pi-bolt/pi-bolt.txt'
```

`pi-bolt compile --out` writes an installation layout (docs, examples,
theme, `native`, `pi-bolt.txt`) out of assets embedded in its own executable,
sets those files read-only (`0555`/`0444`, as an installer would), and then
opens `pi-bolt/pi-bolt.txt` for writing to stamp the build, in the same run.
The write cannot succeed against a file it just made `0444`. The same
condition makes its own work-folder cleanup fail first:
`EACCES: permission denied, rm '<parent>/.compile-XXXXXX'`, since it cannot
unlink inside the `0555` directories it just created.

Four mitigations were tried and all failed:

1. `--runtime` and `--kit` pointing at locally unpacked, fully writable
   copies (this does eliminate the 44 MB + 7.7 MB re-download — keep
   `~/.cache/pi-bolt-compile`, 503 MB).
2. A background watchdog re-granting `u+w` on every directory in the work
   folder (25 fixes, still lost the race).
3. Same watchdog covering files and directories (245 fixes, still EACCES on
   `pi-bolt.txt`).
4. `--only <one extension>` to shrink the graph (same failure).

Each attempt costs ~4 minutes of CPU on this box, and produces nothing.

The failure is a same-run ordering bug, so it cannot be won from outside: only
a process that ignores mode bits (root, i.e. a container) or an upstream fix
that chmods before writing / writes before chmodding will get through.

Options, in order of preference:

1. **Upstream fix.** Report with the above; the fix is one of two line
   changes in the layout step.
2. **Compile inside a root container.** `podman run --rm` with the store
   binary, `~/.pi` and an output dir mounted, running `pi-bolt compile --out`
   as root, then point the wrapper at the result. Root ignores the `0444`, so
   the layout, stamp and cleanup all succeed. Needs podman, a 300 MB output
   per cache key, and a recompile on every pi-bolt version bump.
3. **Leave it.** With the extension set trimmed, a warm start is ~2-3 s;
   the compiled build would make it ~0.33 s. Not worth a root-in-container
   build machine unless the remaining seconds hurt.

## Notes

- `pi-bolt compile` would remove all of this (~55 ms for the same set). The
  nix store build cannot compile in place, and 1.2.0's `--out` fails with
  `EACCES` on its read-only `.compile-*` folder; **1.2.1 fixes `--out`**
  (verified: 13 extensions incl. `curam-membrane-pi`, ~157 s, then startup
  ~0.40 s). See [pi-bolt-aot-handoff.md](pi-bolt-aot-handoff.md) for the
  flake-lock bump and wrapper plan.
- Measured on a 4-core i7-10510U laptop (btrfs on LUKS). Some of the numbers
  above were taken while the machine sat at load average ~20 from an
  unrelated AOT compile, so treat the absolute values as indicative; the
  cold/warm split is the part that matters.
