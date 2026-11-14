# Pi-Bolt extensions: what loads, what it costs, and the three guards

**Last updated:** 2026-11-13.

How this machine's Pi-Bolt is built, which extensions are compiled into it and
which load from their files, why six cannot be compiled in, and what the three
guard layers each do.

Built by `pkgs/pi-bolt` (a copy of the nixpkgs PR branch) loaded from
`home/configs/pi-bolt.nix` with `extensions`, `jitSupport = true` and
`cpu = "native"`; `~/.pi/agent/settings.json` is managed there too.

```sh
make check-pi-bolt    # start it on a pty: fails if any extension does not load, prints time to the prompt
make bench-pi-bolt    # ten starts: min / median / max time to the prompt
```

## What is installed, and how each one loads

| extension | version | loads as | cost |
|---|---|---|---|
| `@aliou/pi-guardrails` | 0.23.0 | **compiled in** — 4 built-ins: path-access, guardrails, permission-gate, herdr | 0 ms |
| `@heyhuynhgiabuu/pi-diff` | 0.9.3 | **compiled in** | 0 ms |
| `@melihmucuk/leash` | 1.0.11 | **compiled in** | 0 ms |
| `@mjasnikovs/pi-task` | 0.42.66 | **compiled in** | 0 ms |
| `bigpowers` | 2.96.1 | run time, JIT | 7 ms |
| `@dietrichgebert/ponytail` | 5.3.3 | run time, JIT | 2 ms |
| `@plannotator/pi-extension` | 0.28.62 in the Nix tree (0.28.64 installed) | run time, JIT | 36–60 ms |
| `pi-agent-browser-native` | 0.9.24 in the Nix tree (0.9.30 installed) | run time, JIT | 53 ms |
| `opensec-pi-fff` | 0.11.2 | run time, JIT (`bun:ffi`, so the JIT build is required) | 4 ms |
| `opensec-pi-todo` | 2.13.1 | run time, JIT | 5 ms |
| curam-membrane driver | `~/code/curam-membrane/drivers/pi` (flake input) | **compiled in** | 0 ms |
| herdr's `herdr-agent-state.ts` | herdr 0.9.5 | **skipped** — Pi-Bolt has Herdr support of its own | 0 ms |

Installed in `~/.pi/agent/npm` but not enabled (absent from `settings.json`, so
nothing loads them): `gentle-pi` 1.2.0, `pi-messenger-bridge` 0.4.0,
`pi-simplify` 0.2.3, `@ollama/pi-web-search` 0.0.5.

`pi` and `pi-bolt` share `settings.json`: `packages` holds all nine package
entries, and `piBolt.packages` is an *overlay* on it — an exclusion
(`-npm:x`, or `-<store path>` for a local extension) takes out what is compiled
in, an addition brings in what only pi-bolt has. `pi-bolt list` therefore shows
six packages, `pi list` nine.

## Why six are not compiled in

Compiled-in extensions load whether or not they are enabled, so one that cannot
work from inside the executable fails the start of every session. Each of the
six has a concrete blocker:

| extension | blocker |
|---|---|
| `bigpowers` | reads a directory listing at load: `readdirSync(<package>/skills)`; in the executable that is `/$bunfs/skills` |
| `opensec-pi-fff`, `opensec-pi-todo` | thin entries that `createRequire` → `./core.cjs` beside themselves on every factory call, by design, so `/reload` and package upgrades re-evaluate |
| `@dietrichgebert/ponytail` | imports `../hooks/ponytail-config.js` from its own folder at run time |
| `pi-agent-browser-native` | its entry module is 1.77 MB; the top-level bytecode (282 620 B) is over Pi-Bolt's AOT candidate limit of 262 144 B. `aotBytecodeLimit` raises the limit and it does build (1m35s) and start (0.21 s), but the extension finds its package root from `import.meta.url` to point the model at `README.md` and `docs/COMMAND_REFERENCE.md`, which inside the executable are `/$bunfs/…` paths — not enabled for that reason |
| `@plannotator/pi-extension` | (a) its diagram engine imports node-canvas; (b) with that stubbed it imports `Type` from `@earendil-works/pi-ai`, which Pi 1.5.2 no longer exports (`No matching export`) |

Anything above is a fix upstream could make: embed the files
(`import … with { type: "text" }`), skip discovery when `import.meta.url`
starts with `/$bunfs/`, or split the oversized module. All six compiled in
would put startup at about 0.10 s.

## The three guard layers

They sit at different points and answer different questions, which is why all
three are installed.

| | `@aliou/pi-guardrails` | `@melihmucuk/leash` | curam-membrane driver |
|---|---|---|---|
| layer | `tool_call`, before it runs | `tool_call`, before it runs | `tool_result`, after it ran |
| question | may this tool touch *this path*? | may this *shell command* do that? | may this *text* reach the model? |
| mechanism | path policies: `noAccess` blocks `read/write/edit/bash/grep/find/ls`, `readOnly` blocks `write/edit/bash`, with allow-patterns; a dangerous-command detector that asks a delegate to approve and blocks when no UI can confirm; blocked and approval events go out as herdr pane prompts | command-pattern sandbox: `rm`/`mv`/`cp`/`chmod` outside the working directory, protected `.env`/`.git`, `git reset`/`restore`/`stash`, `push --force`, `clean -f`; resolves symlinks, parses `&&` `||` `;` `|` chains | spawns the `mem/1` engine once per session, masks each `text` block of tool output (secrets, PII), drops the stale `textSignature`, journals one `pii_scrubbed` event; `/membrane status\|audit\|rules` |
| on failure | blocks, or asks | blocks | **passes results through unscrubbed** and says `membrane: degraded`; the driver respawns the engine on the next tool result and the footer returns to `on` (measured: one result lost, recovery under 500 ms) |
| configuration | `guardrails.json`; `/guardrails` commands (settings, onboarding, examples) | built-in rules; its `leash` CLI and `--setup` are for other agents, in Pi only the extension runs | engine from `MEMBRANE_ENGINE`, then `PATH`, then the `~/code/curam-security` workspace builds; rules and storage live in the engine |
| today | compiled in, default policies (no `guardrails.json` yet) | compiled in | compiled in, `membrane: on · e01s02-v1`; engine is the pinned release build in `~/.nix-profile/bin`, journal at `~/.local/state/curam/journal.db` (0600, hash chain; `verify` reports `chain_ok`, `status` reports the seal) |

`make check-pi-bolt` fails unless that last cell reads `membrane: on`: the layer
fails open, so `off` (no engine) and `degraded` (dead or slow engine) both leak
tool results into the transcript without failing a turn. It also fails on
"built-in extension … was not loaded", which is what a run-time copy of a
compiled-in extension causes.

### How the engine gets there

`pkgs/curam/` holds three files and no flake input:

| file | what |
|---|---|
| `pins.nix` | the two checkouts by commit: `curam-security` (engine) and `curam-membrane` (driver source) |
| `engine.nix` | `buildRustPackage` of `curam-security`'s workspace, `-p curam-membrane`; `home.packages`, so the driver's rule 2 finds `curam-membrane` on PATH |
| `driver.nix` | `builtins.fetchGit` of `curam-membrane` at its pinned rev — a store path, so pi-bolt can compile the driver in; `piBolt.packages` excludes it as `-<store path>` so the interpreted copy does not replace the built-in |

`builtins.fetchGit` with an explicit rev is forced only when the engine or the
driver is actually built. That is the whole point of not using flake inputs here:
nix fetches every input of a flake for *every* output, so as inputs these two
made any evaluation of this repo — on media, app-node, mgmt — fail wherever the
checkouts do not exist. Verified: with a bogus rev in `pins.nix`, evaluating an
unrelated output still succeeds.

The cost of that laziness is that only **committed** work is built. `make
pin-curam` moves the pins to the checkouts' HEADs and prints what it is leaving
out; a dirty checkout is not an error, it is just not in the engine.

The engine is built with the `nixpkgs-curam` input's `rustPlatform`, not this
repo's nixpkgs. `rusqlite` with `bundled` needs a toolchain that links the sqlite
it compiles: under nixpkgs-unstable the link step asks for a dynamic `-lsqlite3`
and fails with `cannot find -lsqlite3`, while the pinned rev builds and runs it
(both observed on the same working tree and `Cargo.lock`, so it is the
nixpkgs/toolchain, not the crate set). `nixpkgs-curam` is pinned by commit to the
same nixpkgs `curam-security`'s own `flake.lock` uses, so the engine builds in the
environment its repo expects.

The point of the split: guardrails and leash protect the disk and the machine
and fail closed; membrane protects data going to the model and fails open,
because blocking a turn over a dead scrubbing engine is worse than leaking.
Its own README lists what v1 does not cover: user prompts, tool *call*
arguments (what `write`/`edit` sends), images, and injection scanning.

Guardrails and leash overlap on `bash` — guardrails checks it when a protected
path is involved, leash understands the command line itself — and the first one
to block wins the turn.

## Time to the prompt

Measured on this machine with `make bench-pi-bolt` (exec to the prompt box,
PTY, `--no-approve`, no model call):

| extension set | time to prompt |
|---|---|
| six run-time extensions, membrane compiled in (today) | 0.22–0.50 s, median 0.33 s (two runs of 10) |
| without `@plannotator/pi-extension` | 0.17 s |
| without plannotator and `pi-agent-browser-native` | 0.12 s |
| compiled-in extensions only | 0.08 s |

Not levers, checked: pruning Pi-Bolt's own built-ins (0.23 s before and after);
the jiti cache (already salted per version in `~/.pi/agent/cache/jiti`, only
cold starts pay); `--smol` (already in the build); training profiles
(`profiles/pi-1.5.2` ships and the build uses it). `cpu = "native"` does not
move startup either (0.23 s both ways) but makes Pi's own work a little faster:
`pi-bolt doctor` 0.39–0.48 s against 0.41–0.50 s on the baseline build.

## Related

[curam-membrane-guide.md](curam-membrane-guide.md) explains the membrane layer in
plain language, and [curam-membrane-testing.md](curam-membrane-testing.md) is the
checklist for proving it works.

[pi-bolt-extension-set.md](pi-bolt-extension-set.md),
[pi-bolt-jiti-cache-fix.md](pi-bolt-jiti-cache-fix.md) and
[pi-bolt-aot-handoff.md](pi-bolt-aot-handoff.md) describe the earlier runtime
setup (`pi-bolt compile`, a `TMPDIR`/`JITI_FS_CACHE` wrapper) that this replaced.
