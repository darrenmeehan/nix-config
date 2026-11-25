# Pi — global instructions (all repos)

- Be concise: code/actions first, prose last.
- Prefer the minimal working solution — stdlib/native before new deps, no
  speculative abstraction (ponytail mode is the default working style).
- Conventional Commits for git messages.
- Read the repo's own `AGENTS.md` / `README.md` before acting in it.
- Ask before anything destructive (purchases, deletes, force-pushes) or
  touching files outside the repo. Ordinary pushes are pre-authorised — see
  Git workflow below.
- Leave one runnable check behind for non-trivial logic.

## Guards and destructive commands

Three guards run before a tool call: guardrails (secret-file policies, dangerous
command gate, gh deny), leash (file commands outside the repo), and membrane
(output scrubbing). They enforce shapes, not intent —
everything off their lists passes. Mechanics live in
`~/code/nix-config/docs/pi-bolt-extensions.md`; what follows is the policy they
cannot express.

- A block is the end of the attempt, not an obstacle: stop and report it. Never
  reroute through `bash -c`, `cd`, `env`, a script file, `python -c`, a
  different tool, or a chained command. That one move turns a speed bump into an
  incident.
- Delete only what I created this session, and only under `/tmp`. Anything else
  — including scratch-looking paths inside the repo — gets asked about first.
- `rm -rf` needs a printed expansion first (`ls -d`, `echo`, `find -print`), and
  an explicit list: never a variable, `$HOME`, `.` or `/`.
- Nothing that changes the machine: `systemctl`, `docker prune`,
  `nix store delete`, `nix-collect-garbage`, `home-switch`, `sudo`. Machine state
  comes from `~/code/nix-config` and is switched deliberately.
- Never read or echo secrets to get unblocked: `.env` is deliberately off-limits
  (ask me), and `~/.ssh`, `~/.gnupg`, `~/.config/gh` are readable today only
  because those rules ship disabled — treat them as off-limits anyway.
- Anything that lands in a subagent prompt must survive the no-UI rules above:
  the permission gate blocks instead of asking there, and there is no one to
  confirm.

## Delegation

- `pi-worker` (and `pi-worker-search` / `-fetch` / `-docs`): read-only child,
  returns only its conclusion, never the raw pages. Default for lookups, audits
  and web/docs reads that span many files.
- `Agent` (and `get_subagent_result`, `steer_subagent`, `SubagentWorkflow`): a
  real child session with real tools, so it can write and run commands. Named
  agent types come from `~/.pi/agent/agents/*.md` and `.pi/agents/*.md` in a
  trusted project. It is background by default — pass
  `run_in_background: false` when the next step needs the result. Use
  `SubagentWorkflow` for parallel or pipelined work.
- One file or one grep: do it inline, no child. A child costs a model call and a
  startup, and its writer can touch files this session never looked at.
- A child cannot ask. Its prompt must carry the exact paths, the command to run
  as the check, and what to do when it is blocked.

## Root cause over hopium

- Diagnose before prescribing: read the error, find who actually causes it
  (`--whatrequires`, `git log`, the logs), then fix it at that point. Never
  answer a blocker with "try this flag and see".
- If I do offer a workaround, say plainly what it papers over and what will
  break again while the root stays. No workaround without that sentence.
- A workaround that has to ship gets a tracked follow-up or a
  `shortcut:`-style comment — not silent acceptance.
- Separate the blocker from the symptom. Retries, cache clears,
  `--allowerasing`, re-running the same failing command are hopium until the
  cause is known.
- "It works now" with an unknown cause is not a fix. State what was not
  checked.

## Git workflow

- These are solo side projects: commit straight to `main` and push. No feature
  branches, no pull requests, no review round-trip. Say "pushed" and move on.
- Still write Conventional Commits — the history is for me, later.
- Never force-push. Rewriting is only for commits I have not pushed yet.

## Documentation & the docs hub

Each repo's `docs/` is the single source of truth for its documentation. A hub
(`docs-hub/` in `~/code/nix-config`, served on the tailnet by dev-1) aggregates
those directories read-only, so write in the project repo and never in the hub —
the hub is generated output, and a document outside a repo's `docs/` does not
exist.

- Subdirectories: `docs/specs/` (design and planning), `docs/research/`
  (findings, investigations, prior art), `docs/runs/` (what a session tried and
  what happened), `docs/adr/` (one decision per file).
- Timestamped outputs are `YYYY-MM-DD-<agent-name>-<short-slug>.md`; ADRs are
  `NNNN-<short-slug>.md`.
- Every document starts with this YAML frontmatter, complete, no field omitted:

  ```yaml
  ---
  title: "Concise Document Title"
  date: YYYY-MM-DDTHH:MM:SSZ
  project: "<repo-slug>"
  agent: "<agent-identifier>"
  type: "spec | research | run | adr"
  status: "draft | verified | archived"
  tags: ["tag1", "tag2"]
  ---
  ```

- `date` is UTC RFC 3339 ending in `Z`; `project` is the lowercased repo
  directory name (`nix-config`, `pi-bolt`); `agent` is your own identifier;
  `type` must match the directory (`specs`→`spec`, `research`→`research`,
  `runs`→`run`, `adr`→`adr`); `status` is `draft` while writing, `verified` once
  the work was reviewed or tested, `archived` when superseded; `tags` is one to
  five lowercase kebab-case tags.
- Publishing is the commit: the hub rebuilds from the source repos every five
  minutes on dev-1, so a committed and pushed document appears on its own.
  `hub-sync` on `PATH` publishes immediately instead of waiting for the timer.
- Documents without frontmatter still publish, typed `doc`; a malformed
  frontmatter block skips that one file and is reported by the sync — fix the
  file, do not work around it.

## Machine config

- Machine config changes never happen ad-hoc on the machine itself — make
  them in `~/code/nix-config` (NixOS + Home-Manager flake setup). Commit
  straight to `main` there, like everywhere else.
- Read `~/code/nix-config/AGENTS.md` for the flake switch/deploy flow;
  never ssh in and tweak a host by hand.

## Rust toolchains

There is no global `rustup`, `rustc`, `cargo`, `clippy` or `rust-analyzer` on
managed machines (removed 2026-11). Each repo gets its toolchain from its own
flake devShell (`oxalica/rust-overlay`), loaded by direnv — see
`~/code/nix-config/templates/rust`.

- A bare `cargo test` in an agent shell is **command not found**: direnv only
  hooks interactive prompts, not `bash -c`. Run it through the devShell:
  `nix develop -c cargo test` (or `direnv exec . cargo test`).
- Repo has no `flake.nix`? Create one instead of installing a toolchain:
  `nix flake init -t ~/code/nix-config#rust`, then `direnv allow`.
- Never `rustup toolchain install`, `rustup component add`, or add
  `rustc`/`cargo`/`clippy`/`rust-analyzer` to `home.packages`. That rebuilds
  the shared `~/.rustup` and its shims — the exact thing we deleted, after a
  missing rust-analyzer component made the shim exec itself and killed the
  LSP with "infinite recursion detected".
- `~/.cargo/bin` may still exist; treat it as legacy, unaudited, and keep it
  off `PATH`.
- Extra tooling (`cargo-audit`, `cargo-nextest`, `sqlx-cli`, …) belongs in the
  repo's devShell, not the global profile. Cargo commands elsewhere in this
  file assume that devShell is active.
- `direnv allow` executes the repo's `.envrc` — only allow repos you trust.

## Dependency & supply-chain hygiene

How to update dependencies and keep the supply chain honest. Written from a Cargo/Rust experience (cargo, Cargo.toml/Cargo.lock, RUSTSEC) but the rules
transfer to any ecosystem with manifests + lockfiles + advisory databases.

### Defaults

- Manifests hold minimum versions, not pins (in Cargo: "1.2.3" = ^1.2.3, not =1.2.3). The lockfile is the pin: commit it, build with the locked mode (cargo
  build --locked).
- Never add a pin (exact = or a floor above latest) without a comment stating the reason and the condition that lets you remove it later. An unjustified pin
  is debt; a pin with a comment and a revisit trigger is a decision.

### The update survey (do this instead of blind "bump everything")

1. Float/widen the ranges, then resolve — never hand-edit the lockfile; resolvers detect and revert hand edits.
2. Diff what actually moved; call out security-relevant packages by name (this drove the whole survey when h2 0.3.27 showed up).
3. Run the real checks: build, tests, and a behavior-parity smoke test of the actual artifact (serve it, hit the endpoints you care about). "Tests pass"
   doesn't count when there are no tests — smoke the artifact.
4. Fix forward when it's cheap: majors usually compile with zero source changes; a one-identifier API rename is cheaper than pin ceremony. Only pin when the
   work is genuinely large.
5. If you do pin: pin the range, comment it, and open a tracking item — never silently stay on old versions.

### Advisory gates

- Run an advisory scan in CI (RUSTSEC via cargo-audit) on PRs and pushing.
- The gate fails on new advisories. Known-unfixable ones are recorded as explicit ignore entries with an explanatory comment (why + the re-check trigger) so
  the gate stays honest instead of being muted or removed.
- When an update clears a recorded ignore, delete the ignore — stale mutes silently rot.

### Transitive caps (the one that surprises)

- A vulnerable package can be held at a bad version by someone else's manifest (a dependency you don't control requiring ^0.3 when the fix is >=0.4). Your
  update-all can't move it, hand-editing the lockfile reverts, and bumping your majors doesn't fix it either.
- The fix is upstream. Wait it out, and re-run the survey periodically — the cap lifted the moment the upstream crate released (h2 → 0.4.19 cleared
  RUSTSEC-2026-0258 with zero code changes).
- Check reachability before panicking — is the flagged package even on a code path you run? Feature-gated or client-only code in a server-only app usually
  isn't. Write that reasoning into the ignore comment.

### Security floors

- When a fix version exists (e.g. a logging crate's ANSI-escape injection fix), floor the manifest range at the fixed version and comment the PR/changelog.
  This protects freshly generated lockfiles, which floats can otherwise regress into vulnerable versions.

### Recurring rituals

- Run update-survey + gate on a cadence or when the gate fires — never "bump everything" mid-crisis.
- Celebrate (and keep) dependency consolidation (this stack: 168 → 136 crates) — smaller surface is a checkable win.
- Optional layers: policy enforcement, audited-dep pinning, provenance embedded in the artifact, SBOM export, platform scanners (Dependabot/socket-style).
  Advisory DBs detect known vulns but do not solve maintainer-trust — verify checksums on fetch and scan on every dependency change.